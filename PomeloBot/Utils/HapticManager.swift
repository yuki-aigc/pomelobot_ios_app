import UIKit

/// 触觉反馈管理
@MainActor
enum HapticManager {
    
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    /// 消息发送
    static func messageSent() {
        impact(.medium)
    }
    
    /// 收到回复
    static func messageReceived() {
        notification(.success)
    }
    
    /// 连接成功
    static func connected() {
        notification(.success)
    }
    
    /// 错误
    static func error() {
        notification(.error)
    }
}
