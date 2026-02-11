import Foundation
import Combine

// MARK: - Connection State

enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case authenticating
    case authenticated
    case error(String)
    
    var displayText: String {
        switch self {
        case .disconnected: return "未连接"
        case .connecting: return "连接中..."
        case .connected: return "已连接"
        case .authenticating: return "认证中..."
        case .authenticated: return "已认证"
        case .error(let msg): return "错误: \(msg)"
        }
    }
    
    var isReady: Bool {
        self == .connected || self == .authenticated
    }
}

// MARK: - WebSocket Service

/// 负责与 Pomelobot 后端的 WebSocket 通信
/// 完整实现 pomelobot iOS 协议: hello/auth, message, ping/pong, proactive
@MainActor
final class WebSocketService: ObservableObject {
    
    // MARK: - Published State
    
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var connectionId: String?
    
    // MARK: - Event Streams
    
    /// 收到 AI 回复
    let onReply = PassthroughSubject<ServerEnvelope, Never>()
    /// 收到主动推送
    let onProactive = PassthroughSubject<ServerEnvelope, Never>()
    /// 消息派发确认
    let onDispatchAck = PassthroughSubject<ServerEnvelope, Never>()
    /// 连接错误
    let onError = PassthroughSubject<ServerEnvelope, Never>()
    
    // MARK: - Config
    
    private var serverURL: URL?
    private var authToken: String?
    private var userId: String?
    private var userName: String?
    private var conversationId: String?
    
    // MARK: - Internal
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 10
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var isManualDisconnect = false
    
    // MARK: - Lifecycle
    
    init() {
        encoder.outputFormatting = .sortedKeys
    }
    
    deinit {
        pingTimer?.invalidate()
        reconnectTimer?.invalidate()
    }
    
    // MARK: - Public API
    
    /// 连接到 pomelobot WebSocket 服务
    func connect(
        host: String,
        port: Int,
        path: String = "/ws/ios",
        useTLS: Bool = false,
        authToken: String? = nil,
        userId: String? = nil,
        userName: String? = nil,
        conversationId: String? = nil
    ) {
        disconnect()
        isManualDisconnect = false
        
        let scheme = useTLS ? "wss" : "ws"
        let normalizedPath = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: "\(scheme)://\(host):\(port)\(normalizedPath)") else {
            connectionState = .error("无效的服务器地址")
            return
        }
        
        self.serverURL = url
        self.authToken = authToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.userId = userId
        self.userName = userName
        self.conversationId = conversationId
        
        performConnect()
    }
    
    func disconnect() {
        isManualDisconnect = true
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        reconnectAttempts = 0
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        session?.invalidateAndCancel()
        session = nil
        
        connectionState = .disconnected
        connectionId = nil
    }
    
    /// 发送聊天消息
    func sendMessage(
        text: String,
        messageId: String? = nil,
        conversationId: String? = nil,
        senderId: String? = nil,
        senderName: String? = nil
    ) async throws {
        guard connectionState.isReady else {
            throw WebSocketError.notConnected
        }
        
        let payload = ClientMessagePayload(
            text: text,
            messageId: messageId,
            conversationId: conversationId ?? self.conversationId,
            isDirect: true,
            senderId: senderId ?? self.userId,
            senderName: senderName ?? self.userName
        )
        
        try await send(payload)
    }
    
    /// 发送 ping
    func sendPing() async throws {
        guard connectionState.isReady else { return }
        let payload = ClientPingPayload()
        try await send(payload)
    }
    
    // MARK: - Connection Management
    
    private func performConnect() {
        connectionState = .connecting
        
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.timeoutIntervalForRequest = 30
        
        session = URLSession(configuration: config)
        
        guard let url = serverURL else { return }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        
        webSocketTask = session?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        startReceiving()
    }
    
    // MARK: - Send
    
    private func send<T: Encodable>(_ payload: T) async throws {
        guard let task = webSocketTask else {
            throw WebSocketError.notConnected
        }
        
        let data = try encoder.encode(payload)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw WebSocketError.encodingFailed
        }
        
        try await task.send(.string(jsonString))
    }
    
    // MARK: - Receive Loop
    
    private func startReceiving() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                
                switch result {
                case .success(let message):
                    self.handleMessage(message)
                    self.startReceiving()
                    
                case .failure(let error):
                    if !self.isManualDisconnect {
                        self.connectionState = .error(error.localizedDescription)
                        self.scheduleReconnect()
                    }
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        
        switch message {
        case .string(let text):
            guard let d = text.data(using: .utf8) else { return }
            data = d
        case .data(let d):
            data = d
        @unknown default:
            return
        }
        
        guard let envelope = try? decoder.decode(ServerEnvelope.self, from: data) else {
            return
        }
        
        dispatchServerMessage(envelope)
    }
    
    private func dispatchServerMessage(_ envelope: ServerEnvelope) {
        switch envelope.type {
        case "hello_ack":
            handleHelloAck(envelope)
            
        case "hello_required":
            handleHelloRequired(envelope)
            
        case "dispatch_ack":
            onDispatchAck.send(envelope)
            
        case "reply":
            onReply.send(envelope)
            
        case "proactive":
            onProactive.send(envelope)
            
        case "pong":
            break // 心跳响应，无需处理
            
        case "error":
            onError.send(envelope)
            if envelope.code == "auth_failed" {
                connectionState = .error("认证失败")
            }
            
        default:
            break
        }
    }
    
    // MARK: - Hello / Auth
    
    private func handleHelloAck(_ envelope: ServerEnvelope) {
        connectionId = envelope.connectionId
        connectionState = (envelope.authenticated == true) ? .authenticated : .connected
        reconnectAttempts = 0
        startPingTimer()
    }
    
    private func handleHelloRequired(_ envelope: ServerEnvelope) {
        connectionId = envelope.connectionId
        connectionState = .authenticating
        
        // 自动发送 hello 进行认证
        Task {
            let hello = ClientHelloPayload(
                token: authToken,
                clientId: UIDevice.current.identifierForVendor?.uuidString,
                userId: userId,
                userName: userName,
                conversationId: conversationId,
                isDirect: true
            )
            try? await send(hello)
        }
    }
    
    // MARK: - Heartbeat
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.sendPing()
            }
        }
    }
    
    // MARK: - Reconnect
    
    private func scheduleReconnect() {
        guard !isManualDisconnect else { return }
        guard reconnectAttempts < maxReconnectAttempts else {
            connectionState = .error("重连失败，已达最大重试次数")
            return
        }
        
        reconnectAttempts += 1
        let delay = min(Double(reconnectAttempts) * 2.0, 30.0) // 指数退避，最大30秒
        
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performConnect()
            }
        }
    }
}

// MARK: - Errors

enum WebSocketError: LocalizedError {
    case notConnected
    case encodingFailed
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .notConnected: return "WebSocket 未连接"
        case .encodingFailed: return "消息编码失败"
        case .serverError(let msg): return "服务器错误: \(msg)"
        }
    }
}
