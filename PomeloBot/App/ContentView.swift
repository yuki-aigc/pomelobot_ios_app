import SwiftUI

/// 主内容视图 - iOS 26 Liquid Glass TabView
struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var selectedTab: AppTab = .chat
    
    enum AppTab: String, Hashable {
        case chat
        case settings
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 聊天 Tab
            Tab("对话", systemImage: "bubble.left.and.text.bubble.right", value: .chat) {
                NavigationStack {
                    ChatView(viewModel: chatViewModel)
                }
            }
            
            // 设置 Tab
            Tab("设置", systemImage: "gearshape", value: .settings) {
                SettingsView(
                    settings: settings,
                    wsService: chatViewModel.wsService
                )
            }
        }
        .tint(Color.accentColor)
    }
}
