import SwiftUI

/// 连接状态指示栏
struct ConnectionStatusView: View {
    let state: ConnectionState
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    
    @State private var pulseOpacity: Double = 0.3
    
    var body: some View {
        HStack(spacing: 10) {
            // 状态指示灯
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay {
                    if state == .connecting || state == .authenticating {
                        Circle()
                            .stroke(statusColor.opacity(0.4), lineWidth: 2)
                            .scaleEffect(1.8)
                            .opacity(pulseOpacity)
                            .animation(
                                .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
                                value: pulseOpacity
                            )
                            .onAppear { pulseOpacity = 1.0 }
                    }
                }
            
            // 状态文本
            Text(state.displayText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // 操作按钮
            Button {
                if state.isReady {
                    onDisconnect()
                } else {
                    onConnect()
                }
            } label: {
                Text(state.isReady ? "断开" : "连接")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(state.isReady ? .red : Color.accentColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        (state.isReady ? Color.red : Color.accentColor).opacity(0.12),
                        in: Capsule()
                    )
            }
            .disabled(state == .connecting || state == .authenticating)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
    
    private var statusColor: Color {
        switch state {
        case .disconnected: return .gray
        case .connecting, .authenticating: return .orange
        case .connected: return .blue
        case .authenticated: return .green
        case .error: return .red
        }
    }
}
