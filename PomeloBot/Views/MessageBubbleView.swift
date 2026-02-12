import SwiftUI

/// 单条消息气泡
struct MessageBubbleView: View {
    let message: ChatMessage
    var showTimestamp: Bool = true
    var fontSize: Double = 16
    var skipAnimation: Bool = false
    var onAnimationDone: (() -> Void)?
    
    @State private var showCopyConfirm = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.isFromUser {
                Spacer(minLength: 50)
            } else {
                // Bot 头像
                BotAvatarView()
                    .padding(.top, 2)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: 4) {
                // 主动推送标签
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
                    .background(.orange.opacity(0.12), in: Capsule())
                }
                
                // 标题
                if let title = message.title, !title.isEmpty {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                // 消息内容
                messageContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground, in: BubbleShape(isFromUser: message.isFromUser))
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
                            .foregroundStyle(.tertiary)
                    }
                    statusIcon
                }
            }
            
            if !message.isFromUser {
                Spacer(minLength: 50)
            }
        }
        .overlay(alignment: message.isFromUser ? .trailing : .leading) {
            if showCopyConfirm {
                Text("已复制")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.7), in: Capsule())
                    .transition(.scale.combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { showCopyConfirm = false }
                        }
                    }
            }
        }
    }
    
    // MARK: - 消息内容（支持 Markdown）
    
    @ViewBuilder
    private var messageContent: some View {
        if !message.isFromUser {
            if skipAnimation {
                // 已播放过动画，直接显示完整 Markdown
                MarkdownContentView(text: message.text, fontSize: fontSize)
            } else {
                // 首次显示：逐字打字动画
                TypingTextView(
                    fullText: message.text,
                    fontSize: fontSize,
                    isMarkdown: true,
                    onFinished: { onAnimationDone?() }
                )
            }
        } else {
            Text(message.text)
                .font(.system(size: fontSize))
                .foregroundStyle(.white)
                .textSelection(.enabled)
        }
    }
    
    // MARK: - 气泡背景
    
    private var bubbleBackground: some ShapeStyle {
        if message.isFromUser {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        } else {
            return AnyShapeStyle(Color(.systemGray6))
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
                .foregroundStyle(.tertiary)
        case .delivered:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundStyle(Color.accentColor)
        case .waitingReply:
            Image(systemName: "ellipsis")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
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

// MARK: - Bot Avatar

struct BotAvatarView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.8), Color.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 32, height: 32)
            
            Text("P")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}

// MARK: - 气泡形状

struct BubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailRadius: CGFloat = 4
        
        let path = UIBezierPath()
        
        if isFromUser {
            // 用户消息：右下角小圆角
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - tailRadius))
            path.addArc(withCenter: CGPoint(x: rect.maxX - tailRadius, y: rect.maxY - tailRadius),
                        radius: tailRadius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                        radius: radius, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        } else {
            // Bot 消息：左下角小圆角
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                        radius: radius, startAngle: -.pi / 2, endAngle: 0, clockwise: true)
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addArc(withCenter: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                        radius: radius, startAngle: 0, endAngle: .pi / 2, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX + tailRadius, y: rect.maxY))
            path.addArc(withCenter: CGPoint(x: rect.minX + tailRadius, y: rect.maxY - tailRadius),
                        radius: tailRadius, startAngle: .pi / 2, endAngle: .pi, clockwise: true)
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addArc(withCenter: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                        radius: radius, startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        }
        
        path.close()
        return Path(path.cgPath)
    }
}
