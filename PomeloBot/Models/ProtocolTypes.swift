import Foundation

// MARK: - Client → Server Envelopes

/// 客户端发送的 hello 握手消息
struct ClientHelloPayload: Codable {
    private(set) var type: String = "hello"
    var token: String?
    var clientId: String?
    var userId: String?
    var userName: String?
    var conversationId: String?
    var conversationTitle: String?
    var isDirect: Bool?
    var metadata: [String: AnyCodable]?
    
    init(
        token: String? = nil,
        clientId: String? = nil,
        userId: String? = nil,
        userName: String? = nil,
        conversationId: String? = nil,
        conversationTitle: String? = nil,
        isDirect: Bool? = true,
        metadata: [String: AnyCodable]? = nil
    ) {
        self.token = token
        self.clientId = clientId
        self.userId = userId
        self.userName = userName
        self.conversationId = conversationId
        self.conversationTitle = conversationTitle
        self.isDirect = isDirect
        self.metadata = metadata
    }
}

/// 客户端发送的聊天消息
struct ClientMessagePayload: Codable {
    private(set) var type: String = "message"
    var messageId: String?
    var idempotencyKey: String?
    var timestamp: Int?
    var conversationId: String?
    var conversationTitle: String?
    var isDirect: Bool?
    var senderId: String?
    var senderName: String?
    var text: String?
    var metadata: [String: AnyCodable]?
    
    init(
        text: String,
        messageId: String? = nil,
        conversationId: String? = nil,
        conversationTitle: String? = nil,
        isDirect: Bool? = true,
        senderId: String? = nil,
        senderName: String? = nil
    ) {
        self.text = text
        self.messageId = messageId ?? "ios-\(Int(Date().timeIntervalSince1970 * 1000))-\(UUID().uuidString.prefix(8))"
        self.idempotencyKey = self.messageId
        self.timestamp = Int(Date().timeIntervalSince1970 * 1000)
        self.conversationId = conversationId
        self.conversationTitle = conversationTitle
        self.isDirect = isDirect
        self.senderId = senderId
        self.senderName = senderName
    }
}

/// 客户端发送的心跳 ping
struct ClientPingPayload: Codable {
    private(set) var type: String = "ping"
    var timestamp: Int?
    
    init() {
        self.timestamp = Int(Date().timeIntervalSince1970 * 1000)
    }
}

// MARK: - Server → Client Envelopes

/// 服务端消息的通用类型标识
enum ServerMessageType: String, Codable {
    case helloAck = "hello_ack"
    case helloRequired = "hello_required"
    case dispatchAck = "dispatch_ack"
    case reply = "reply"
    case proactive = "proactive"
    case pong = "pong"
    case error = "error"
}

/// 服务端通用信封 - 先解析 type 再分发
struct ServerEnvelope: Codable {
    let type: String
    
    // hello_ack / hello_required
    var connectionId: String?
    var serverTime: Int?
    var authenticated: Bool?
    
    // dispatch_ack
    var messageId: String?
    var status: String?
    var reason: String?
    
    // reply / proactive
    var conversationId: String?
    var text: String?
    var title: String?
    var useMarkdown: Bool?
    var target: String?
    var metadata: [String: AnyCodable]?
    var timestamp: Int?
    
    // error
    var code: String?
    var message: String?
}

// MARK: - AnyCodable 辅助类型

/// 用于处理 metadata 中的任意 JSON 值
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}
