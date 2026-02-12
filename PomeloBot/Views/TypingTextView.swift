import SwiftUI
import MarkdownUI

/// 按段落分块的打字动画
/// - 已完成段落：立即用 MarkdownContentView 渲染（标题、粗体、表格等格式化）
/// - 当前段落：逐字打字效果 + 闪烁光标
/// - 未到的段落：不显示
struct TypingTextView: View {
    let fullText: String
    let fontSize: Double
    let isMarkdown: Bool
    var typingSpeed: Double = 0.015
    var onFinished: (() -> Void)?
    
    @State private var paragraphs: [String] = []
    @State private var currentParaIndex: Int = 0
    @State private var displayedCount: Int = 0
    @State private var timer: Timer?
    @State private var isAllFinished = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isAllFinished {
                // 全部完成 → 完整 Markdown 一次性渲染
                MarkdownContentView(text: fullText, fontSize: fontSize)
            } else {
                // 已完成的段落 → Markdown 渲染
                ForEach(0..<currentParaIndex, id: \.self) { i in
                    let renderedText = paragraphs[0...i].joined(separator: "\n\n")
                    if i == currentParaIndex - 1 {
                        MarkdownContentView(text: renderedText, fontSize: fontSize)
                    }
                }
                
                // 当前段落 → 逐字打字
                if currentParaIndex < paragraphs.count {
                    let prefix = currentParaIndex > 0
                        ? paragraphs[0..<currentParaIndex].joined(separator: "\n\n") + "\n\n"
                        : ""
                    let currentPara = paragraphs[currentParaIndex]
                    let visiblePart = safePrefix(currentPara, count: displayedCount)
                    
                    if currentParaIndex > 0 {
                        // 前面段落已渲染，当前段落单独显示
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text(visiblePart)
                                .font(.system(size: fontSize))
                                .foregroundStyle(.primary)
                            CursorView()
                        }
                        .padding(.top, 6)
                    } else {
                        // 第一个段落
                        HStack(alignment: .lastTextBaseline, spacing: 0) {
                            Text(visiblePart)
                                .font(.system(size: fontSize))
                                .foregroundStyle(.primary)
                            CursorView()
                        }
                    }
                }
            }
        }
        .onAppear { startTyping() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: fullText) { _, _ in resetAndStart() }
    }
    
    // MARK: - 打字逻辑
    
    private func startTyping() {
        // 按空行分割段落
        paragraphs = splitParagraphs(fullText)
        
        guard !paragraphs.isEmpty else {
            isAllFinished = true
            onFinished?()
            return
        }
        
        currentParaIndex = 0
        displayedCount = 0
        isAllFinished = false
        
        startParagraphTimer()
    }
    
    private func startParagraphTimer() {
        timer?.invalidate()
        
        guard currentParaIndex < paragraphs.count else {
            finishAll()
            return
        }
        
        let paraLength = paragraphs[currentParaIndex].count
        displayedCount = 0
        
        // 根据段落长度调整速度
        let speed: Double
        if paraLength > 300 {
            speed = typingSpeed * 0.25
        } else if paraLength > 150 {
            speed = typingSpeed * 0.4
        } else {
            speed = typingSpeed
        }
        
        // 步进大小
        let step = paraLength > 200 ? 3 : (paraLength > 80 ? 2 : 1)
        
        timer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { _ in
            Task { @MainActor in
                if displayedCount < paraLength {
                    displayedCount = min(displayedCount + step, paraLength)
                } else {
                    // 当前段落打字完成 → 推进到下一段
                    timer?.invalidate()
                    timer = nil
                    
                    withAnimation(.easeOut(duration: 0.15)) {
                        currentParaIndex += 1
                    }
                    
                    if currentParaIndex < paragraphs.count {
                        // 段落间短暂停顿
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            startParagraphTimer()
                        }
                    } else {
                        finishAll()
                    }
                }
            }
        }
    }
    
    private func finishAll() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.2)) {
            isAllFinished = true
        }
        onFinished?()
    }
    
    private func resetAndStart() {
        timer?.invalidate()
        currentParaIndex = 0
        displayedCount = 0
        isAllFinished = false
        startTyping()
    }
    
    // MARK: - Helpers
    
    /// 按空行分割段落，保留表格等连续行
    private func splitParagraphs(_ text: String) -> [String] {
        let raw = text.components(separatedBy: "\n\n")
        return raw.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                  .filter { !$0.isEmpty }
    }
    
    /// 安全截取前 count 个字符
    private func safePrefix(_ str: String, count: Int) -> String {
        if count >= str.count { return str }
        let idx = str.index(str.startIndex, offsetBy: count)
        return String(str[str.startIndex..<idx])
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
