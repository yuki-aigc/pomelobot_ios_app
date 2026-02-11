import SwiftUI

/// 单条消息气泡 - iOS 26 Liquid Glass
struct MessageBubbleView: View {
    let message: ChatMessage
    var showTimestamp: Bool = true
    var fontSize: Double = 16
    
    @State private var showCopyConfirm = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 60)
            } else {
                // Bot 头像 - Liquid Glass
                BotAvatarView()
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // 标题 (proactive / title)
                if let title = message.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                // 主动推送标签 - Liquid Glass 胶囊
                if message.isProactive {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 10))
                        Text("主动推送")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.tint(.orange), in: .capsule)
                }
                
                // 消息内容 - Liquid Glass 气泡
                Text(message.text)
                    .font(.system(size: fontSize))
                    .foregroundStyle(message.isFromUser ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(userBubbleBackground)
                    .glassEffect(
                        message.isFromUser
                            ? .regular.interactive().tint(.accentColor)
                            : .regular,
                        in: .rect(cornerRadius: 18)
                    )
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.text
                            showCopyConfirm = true
                        } label: {
                            Label("复制", systemImage: "doc.on.doc")
                        }
                    }
                
                // 状态 + 时间
                HStack(spacing: 6) {
                    if showTimestamp {
                        Text(formatTime(message.timestamp))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    
                    statusIcon
                }
            }
            
            if !message.isFromUser {
                Spacer(minLength: 60)
            }
        }
        .overlay(alignment: message.isFromUser ? .trailing : .leading) {
            if showCopyConfirm {
                Text("已复制")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.tint(.black), in: .capsule)
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { showCopyConfirm = false }
                        }
                    }
            }
        }
    }
    
    // MARK: - Sub Views
    
    /// 用户消息底色（Glass tint 会叠加在此之上）
    @ViewBuilder
    private var userBubbleBackground: some View {
        if message.isFromUser {
            Color.accentColor.opacity(0.3)
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case .sending:
            ProgressView()
                .scaleEffect(0.6)
        case .sent:
            Image(systemName: "checkmark")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        case .delivered:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.accentColor)
        case .waitingReply:
            Image(systemName: "ellipsis")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        case .error(let msg):
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.red)
                .help(msg)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
        }
        return formatter.string(from: date)
    }
}

// MARK: - Bot Avatar (Liquid Glass)

struct BotAvatarView: View {
    var body: some View {
        Text("P")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(Color.accentColor.opacity(0.5))
            .glassEffect(.regular.interactive().tint(.accentColor), in: .circle)
    }
}
