import SwiftUI
import MarkdownUI

/// 逐字打字动画效果 - 模拟流式输出
struct TypingTextView: View {
    let fullText: String
    let fontSize: Double
    let isMarkdown: Bool
    var typingSpeed: Double = 0.02
    var onFinished: (() -> Void)?
    
    @State private var displayedCount: Int = 0
    @State private var timer: Timer?
    @State private var isFinished = false
    
    var body: some View {
        Group {
            if isFinished {
                // 打字完成后显示完整 Markdown
                MarkdownContentView(text: fullText, fontSize: fontSize)
            } else {
                // 打字过程中显示部分文本 + 光标
                HStack(alignment: .lastTextBaseline, spacing: 0) {
                    Text(currentText)
                        .font(.system(size: fontSize))
                        .foregroundStyle(.primary)
                    
                    // 闪烁光标
                    CursorView()
                }
            }
        }
        .onAppear {
            startTyping()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: fullText) { _, _ in
            // 文本变化时重新开始
            resetAndStart()
        }
    }
    
    private var currentText: String {
        if displayedCount >= fullText.count {
            return fullText
        }
        let index = fullText.index(fullText.startIndex, offsetBy: displayedCount)
        return String(fullText[fullText.startIndex..<index])
    }
    
    private func startTyping() {
        guard !fullText.isEmpty else {
            isFinished = true
            return
        }
        
        displayedCount = 0
        isFinished = false
        
        // 根据文本长度调整速度
        let adjustedSpeed: Double
        if fullText.count > 500 {
            adjustedSpeed = typingSpeed * 0.3  // 长文本加速
        } else if fullText.count > 200 {
            adjustedSpeed = typingSpeed * 0.5
        } else {
            adjustedSpeed = typingSpeed
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: adjustedSpeed, repeats: true) { _ in
            Task { @MainActor in
                if displayedCount < fullText.count {
                    let step = fullText.count > 300 ? 3 : (fullText.count > 100 ? 2 : 1)
                    displayedCount = min(displayedCount + step, fullText.count)
                } else {
                    timer?.invalidate()
                    timer = nil
                    withAnimation(.easeOut(duration: 0.2)) {
                        isFinished = true
                    }
                    onFinished?()
                }
            }
        }
    }
    
    private func resetAndStart() {
        timer?.invalidate()
        displayedCount = 0
        isFinished = false
        startTyping()
    }
    
}

/// 闪烁光标
struct CursorView: View {
    @State private var visible = true
    
    var body: some View {
        Rectangle()
            .fill(Color.accentColor)
            .frame(width: 2, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    visible = false
                }
            }
    }
}
