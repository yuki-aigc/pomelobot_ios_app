import Foundation
import SwiftUI

/// 用户设置持久化存储
final class SettingsStore: ObservableObject {
    
    static let shared = SettingsStore()
    
    // MARK: - Server Config
    
    @AppStorage("server_host") var serverHost: String = "192.168.1.100"
    @AppStorage("server_port") var serverPort: Int = 18080
    @AppStorage("server_path") var serverPath: String = "/ws/ios"
    @AppStorage("server_use_tls") var useTLS: Bool = false
    @AppStorage("server_auth_token") var authToken: String = ""
    
    // MARK: - User Info
    
    @AppStorage("user_id") var userId: String = ""
    @AppStorage("user_name") var userName: String = "iOS 用户"
    
    // MARK: - Chat Config
    
    @AppStorage("default_conversation_id") var defaultConversationId: String = "ios-default"
    @AppStorage("auto_reconnect") var autoReconnect: Bool = true
    @AppStorage("show_timestamps") var showTimestamps: Bool = true
    @AppStorage("font_size") var fontSize: Double = 16
    
    // MARK: - Appearance
    
    @AppStorage("color_scheme_override") var colorSchemeOverride: String = "system" // system, light, dark
    
    // MARK: - Computed
    
    var serverDisplayURL: String {
        let scheme = useTLS ? "wss" : "ws"
        return "\(scheme)://\(serverHost):\(serverPort)\(serverPath)"
    }
    
    var hasAuthToken: Bool {
        !authToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var resolvedUserId: String {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString : trimmed
    }
    
    var resolvedUserName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "iOS 用户" : trimmed
    }
    
    private init() {
        if userId.isEmpty {
            userId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        }
    }
}
