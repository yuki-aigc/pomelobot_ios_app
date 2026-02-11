import SwiftUI

/// 设置页面 - iOS 26 Liquid Glass
struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    @ObservedObject var wsService: WebSocketService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 服务器配置
                Section {
                    HStack {
                        Label("主机", systemImage: "server.rack")
                        Spacer()
                        TextField("192.168.1.100", text: $settings.serverHost)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                    }
                    
                    HStack {
                        Label("端口", systemImage: "number")
                        Spacer()
                        TextField("18080", value: $settings.serverPort, format: .number)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    
                    HStack {
                        Label("路径", systemImage: "link")
                        Spacer()
                        TextField("/ws/ios", text: $settings.serverPath)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    Toggle(isOn: $settings.useTLS) {
                        Label("使用 TLS (wss://)", systemImage: "lock.shield")
                    }
                } header: {
                    Text("服务器")
                } footer: {
                    Text(settings.serverDisplayURL)
                        .font(.caption)
                        .foregroundStyle(Color.accentColor)
                }
                
                // MARK: - 认证
                Section {
                    HStack {
                        Label("Auth Token", systemImage: "key")
                        Spacer()
                        SecureField("留空则不认证", text: $settings.authToken)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                } header: {
                    Text("认证")
                } footer: {
                    Text("对应 pomelobot config.ios.authToken，留空表示服务端未启用认证。")
                }
                
                // MARK: - 用户信息
                Section {
                    HStack {
                        Label("用户 ID", systemImage: "person.badge.key")
                        Spacer()
                        TextField("自动生成", text: $settings.userId)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    
                    HStack {
                        Label("用户名", systemImage: "person")
                        Spacer()
                        TextField("iOS 用户", text: $settings.userName)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Label("会话 ID", systemImage: "bubble.left.and.bubble.right")
                        Spacer()
                        TextField("ios-default", text: $settings.defaultConversationId)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("用户")
                }
                
                // MARK: - 外观
                Section {
                    Toggle(isOn: $settings.showTimestamps) {
                        Label("显示时间戳", systemImage: "clock")
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("字体大小", systemImage: "textformat.size")
                            Spacer()
                            Text("\(Int(settings.fontSize))pt")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.fontSize, in: 12...24, step: 1)
                    }
                    
                    Picker(selection: $settings.colorSchemeOverride) {
                        Text("跟随系统").tag("system")
                        Text("浅色").tag("light")
                        Text("深色").tag("dark")
                    } label: {
                        Label("外观模式", systemImage: "circle.lefthalf.filled")
                    }
                } header: {
                    Text("外观")
                }
                
                // MARK: - 连接状态 (Liquid Glass Card)
                Section {
                    HStack {
                        Text("连接状态")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(wsService.connectionState.isReady ? Color.green : Color.gray)
                                .frame(width: 8, height: 8)
                            Text(wsService.connectionState.displayText)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let connectionId = wsService.connectionId {
                        HStack {
                            Text("连接 ID")
                            Spacer()
                            Text(connectionId.prefix(8) + "...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("状态")
                }
                
                // MARK: - 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("协议")
                        Spacer()
                        Text("PomeloBot WebSocket v1")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("设计")
                        Spacer()
                        Text("iOS 26 Liquid Glass")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("关于")
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}
