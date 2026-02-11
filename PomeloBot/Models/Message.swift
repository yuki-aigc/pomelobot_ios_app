import Foundation

/// 聊天消息模型
struct ChatMessage: Identifiable, Equatable {
    let id: String
    let text: String
    let isFromUser: Bool
    let timestamp: Date
    var status: MessageStatus
    let isProactive: Bool
    let title: String?
    let useMarkdown: Bool
    
    init(
        id: String = UUID().uuidString,
        text: String,
        isFromUser: Bool,
        timestamp: Date = Date(),
        status: MessageStatus = .sent,
        isProactive: Bool = false,
        title: String? = nil,
        useMarkdown: Bool = false
    ) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
        self.timestamp = timestamp
        self.status = status
        self.isProactive = isProactive
        self.title = title
        self.useMarkdown = useMarkdown
    }
    
    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id && lhs.status == rhs.status
    }
}

enum MessageStatus: Equatable {
    case sending
    case sent
    case delivered
    case error(String)
    case waitingReply
}

/// 会话模型
struct Conversation: Identifiable, Codable {
    let id: String
    var title: String
    var lastMessage: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    
    init(
        id: String = UUID().uuidString,
        title: String = "新对话",
        lastMessage: String? = nil,
        lastMessageTime: Date? = nil,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
    }
}
