import Foundation
import Combine
import SwiftUI

/// 聊天主 ViewModel，管理消息列表、WebSocket 交互、会话状态
@MainActor
final class ChatViewModel: ObservableObject {
    
    // MARK: - Published
    
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isLoading: Bool = false
    @Published var currentConversation: Conversation
    @Published var conversations: [Conversation] = []
    
    // MARK: - Dependencies
    
    let wsService: WebSocketService
    let settings: SettingsStore
    
    // MARK: - Internal
    
    private var cancellables = Set<AnyCancellable>()
    private var pendingMessageIds = Set<String>()
    
    // MARK: - Init
    
    init(wsService: WebSocketService = WebSocketService(), settings: SettingsStore = .shared) {
        self.wsService = wsService
        self.settings = settings
        self.currentConversation = Conversation(
            id: settings.defaultConversationId,
            title: "PomeloBot"
        )
        
        setupBindings()
        loadConversations()
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        // AI 回复
        wsService.onReply
            .receive(on: DispatchQueue.main)
            .sink { [weak self] envelope in
                self?.handleReply(envelope)
            }
            .store(in: &cancellables)
        
        // 主动推送
        wsService.onProactive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] envelope in
                self?.handleProactive(envelope)
            }
            .store(in: &cancellables)
        
        // 派发确认
        wsService.onDispatchAck
            .receive(on: DispatchQueue.main)
            .sink { [weak self] envelope in
                self?.handleDispatchAck(envelope)
            }
            .store(in: &cancellables)
        
        // 错误
        wsService.onError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] envelope in
                self?.handleError(envelope)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions
    
    /// 连接到服务器
    func connect() {
        wsService.connect(
            host: settings.serverHost,
            port: settings.serverPort,
            path: settings.serverPath,
            useTLS: settings.useTLS,
            authToken: settings.hasAuthToken ? settings.authToken : nil,
            userId: settings.resolvedUserId,
            userName: settings.resolvedUserName,
            conversationId: currentConversation.id
        )
    }
    
    /// 断开连接
    func disconnect() {
        wsService.disconnect()
    }
    
    /// 发送消息
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard wsService.connectionState.isReady else { return }
        
        let messageId = "ios-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))"
        
        // 立即添加用户消息到列表
        let userMessage = ChatMessage(
            id: messageId,
            text: text,
            isFromUser: true,
            status: .sending
        )
        messages.append(userMessage)
        pendingMessageIds.insert(messageId)
        inputText = ""
        isLoading = true
        
        // 发送到服务器
        Task {
            do {
                try await wsService.sendMessage(
                    text: text,
                    messageId: messageId,
                    conversationId: currentConversation.id,
                    senderId: settings.resolvedUserId,
                    senderName: settings.resolvedUserName
                )
            } catch {
                updateMessageStatus(messageId: messageId, status: .error(error.localizedDescription))
                isLoading = false
            }
        }
        
        // 更新会话
        updateConversation(lastMessage: text)
    }
    
    /// 切换会话
    func switchConversation(_ conversation: Conversation) {
        currentConversation = conversation
        messages = [] // 清空消息（实际可持久化）
        
        // 重新连接到新会话
        if wsService.connectionState.isReady {
            disconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.connect()
            }
        }
    }
    
    /// 创建新会话
    func createNewConversation(title: String = "新对话") {
        let conversation = Conversation(
            id: "ios-\(UUID().uuidString.prefix(8))",
            title: title
        )
        conversations.insert(conversation, at: 0)
        switchConversation(conversation)
        saveConversations()
    }
    
    /// 清空当前会话消息
    func clearMessages() {
        messages = []
    }
    
    // MARK: - Message Handlers
    
    private func handleReply(_ envelope: ServerEnvelope) {
        guard let text = envelope.text, !text.isEmpty else { return }
        
        let replyMessage = ChatMessage(
            id: envelope.messageId ?? UUID().uuidString,
            text: text,
            isFromUser: false,
            title: envelope.title,
            useMarkdown: envelope.useMarkdown ?? false
        )
        
        messages.append(replyMessage)
        isLoading = false
        
        // 更新对应消息状态
        if let msgId = envelope.messageId {
            updateMessageStatus(messageId: msgId, status: .delivered)
            pendingMessageIds.remove(msgId)
        }
        
        updateConversation(lastMessage: text)
    }
    
    private func handleProactive(_ envelope: ServerEnvelope) {
        guard let text = envelope.text, !text.isEmpty else { return }
        
        let proactiveMessage = ChatMessage(
            id: UUID().uuidString,
            text: text,
            isFromUser: false,
            isProactive: true,
            title: envelope.title,
            useMarkdown: envelope.useMarkdown ?? false
        )
        
        messages.append(proactiveMessage)
        updateConversation(lastMessage: "[推送] \(text)")
    }
    
    private func handleDispatchAck(_ envelope: ServerEnvelope) {
        guard let msgId = envelope.messageId else { return }
        
        if envelope.status == "ok" || envelope.status == "dispatched" {
            updateMessageStatus(messageId: msgId, status: .waitingReply)
        } else {
            updateMessageStatus(messageId: msgId, status: .error(envelope.reason ?? "派发失败"))
            isLoading = false
        }
    }
    
    private func handleError(_ envelope: ServerEnvelope) {
        let errorText = envelope.message ?? envelope.code ?? "未知错误"
        
        let errorMessage = ChatMessage(
            id: UUID().uuidString,
            text: "⚠ \(errorText)",
            isFromUser: false,
            status: .error(errorText)
        )
        messages.append(errorMessage)
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private func updateMessageStatus(messageId: String, status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = status
        }
    }
    
    private func updateConversation(lastMessage: String) {
        currentConversation.lastMessage = String(lastMessage.prefix(100))
        currentConversation.lastMessageTime = Date()
        
        if let index = conversations.firstIndex(where: { $0.id == currentConversation.id }) {
            conversations[index] = currentConversation
        }
        saveConversations()
    }
    
    // MARK: - Persistence (Simple UserDefaults)
    
    private func loadConversations() {
        if let data = UserDefaults.standard.data(forKey: "conversations"),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
        }
        
        if conversations.isEmpty {
            conversations = [currentConversation]
        }
    }
    
    private func saveConversations() {
        if let data = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(data, forKey: "conversations")
        }
    }
}
