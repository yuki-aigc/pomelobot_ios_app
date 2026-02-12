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
    /// 记录 outbound messageId → 用户消息的本地 ID 映射
    private var outboundMessageMap: [String: String] = [:]
    /// 已完成打字动画的消息 ID 集合
    @Published var animatedMessageIds: Set<String> = []
    
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
        // 转发 wsService 状态变化，让 View 能感知连接状态更新
        wsService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
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
    
    func disconnect() {
        wsService.disconnect()
    }
    
    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard wsService.connectionState.isReady else { return }
        
        // 网络消息 ID（发给服务端的）
        let outboundId = "ios-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))"
        // 本地显示 ID（保证唯一，不和回复冲突）
        let localId = "user-\(outboundId)"
        
        // 记录映射: outboundId -> localId
        outboundMessageMap[outboundId] = localId
        
        let userMessage = ChatMessage(
            id: localId,
            text: text,
            isFromUser: true,
            status: .sending
        )
        messages.append(userMessage)
        inputText = ""
        isLoading = true
        
        Task {
            do {
                try await wsService.sendMessage(
                    text: text,
                    messageId: outboundId,
                    conversationId: currentConversation.id,
                    senderId: settings.resolvedUserId,
                    senderName: settings.resolvedUserName
                )
                // 发送成功，更新为 sent
                updateMessageStatus(localId: localId, status: .sent)
            } catch {
                updateMessageStatus(localId: localId, status: .error(error.localizedDescription))
                isLoading = false
            }
        }
        
        updateConversation(lastMessage: text)
    }
    
    func switchConversation(_ conversation: Conversation) {
        currentConversation = conversation
        messages = []
        outboundMessageMap = [:]
        
        if wsService.connectionState.isReady {
            disconnect()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.connect()
            }
        }
    }
    
    func createNewConversation(title: String = "新对话") {
        let conversation = Conversation(
            id: "ios-\(UUID().uuidString.prefix(8))",
            title: title
        )
        conversations.insert(conversation, at: 0)
        switchConversation(conversation)
        saveConversations()
    }
    
    func clearMessages() {
        messages = []
        outboundMessageMap = [:]
        animatedMessageIds = []
    }
    
    /// 标记消息动画已完成
    func markAnimationDone(_ messageId: String) {
        animatedMessageIds.insert(messageId)
    }
    
    // MARK: - Message Handlers
    
    private func handleReply(_ envelope: ServerEnvelope) {
        guard let text = envelope.text, !text.isEmpty else { return }
        
        // 回复消息用独立 ID，不和用户消息冲突
        let replyId = "reply-\(envelope.messageId ?? UUID().uuidString)"
        
        let replyMessage = ChatMessage(
            id: replyId,
            text: text,
            isFromUser: false,
            title: envelope.title,
            useMarkdown: envelope.useMarkdown ?? false
        )
        
        messages.append(replyMessage)
        isLoading = false
        
        // 更新对应用户消息状态为已回复
        if let outboundId = envelope.messageId,
           let localId = outboundMessageMap[outboundId] {
            updateMessageStatus(localId: localId, status: .delivered)
            outboundMessageMap.removeValue(forKey: outboundId)
        }
        
        updateConversation(lastMessage: text)
    }
    
    private func handleProactive(_ envelope: ServerEnvelope) {
        guard let text = envelope.text, !text.isEmpty else { return }
        
        let proactiveMessage = ChatMessage(
            id: "proactive-\(UUID().uuidString)",
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
        guard let outboundId = envelope.messageId,
              let localId = outboundMessageMap[outboundId] else { return }
        
        // 只要 status 不是明确的 error/failed，就认为派发成功
        let status = envelope.status?.lowercased() ?? ""
        if status == "error" || status == "failed" || status == "rejected" {
            updateMessageStatus(localId: localId, status: .error(envelope.reason ?? "派发失败"))
            isLoading = false
        } else {
            // ok / dispatched / accepted / 任何非错误状态
            updateMessageStatus(localId: localId, status: .waitingReply)
        }
    }
    
    private func handleError(_ envelope: ServerEnvelope) {
        let errorText = envelope.message ?? envelope.code ?? "未知错误"
        
        let errorMessage = ChatMessage(
            id: "error-\(UUID().uuidString)",
            text: "⚠ \(errorText)",
            isFromUser: false,
            status: .error(errorText)
        )
        messages.append(errorMessage)
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private func updateMessageStatus(localId: String, status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == localId }) {
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
    
    // MARK: - Persistence
    
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
