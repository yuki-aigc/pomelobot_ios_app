import SwiftUI
import MarkdownUI

/// 完整 Markdown 渲染视图
/// 支持：标题、粗体、斜体、代码块、表格、分隔线、列表、链接、引用块等
struct MarkdownContentView: View {
    let text: String
    let fontSize: Double
    
    var body: some View {
        Markdown(text)
            .markdownTheme(botMessageTheme)
            .markdownCodeSyntaxHighlighter(.noHighlight)
            .textSelection(.enabled)
    }
    
    /// 自定义主题 - 适配聊天气泡
    private var botMessageTheme: Theme {
        Theme()
            // 正文
            .text {
                FontSize(fontSize)
                ForegroundColor(.primary)
            }
            // 标题
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize + 6)
                        FontWeight(.bold)
                    }
                    .padding(.bottom, 4)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize + 4)
                        FontWeight(.bold)
                    }
                    .padding(.bottom, 3)
            }
            .heading3 { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize + 2)
                        FontWeight(.semibold)
                    }
                    .padding(.bottom, 2)
            }
            // 代码块
            .codeBlock { configuration in
                ScrollView(.horizontal, showsIndicators: false) {
                    configuration.label
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(fontSize - 1)
                            ForegroundColor(Color(.label))
                        }
                }
                .padding(10)
                .background(Color(.systemGray5).opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.vertical, 4)
            }
            // 行内代码
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(fontSize - 1)
                ForegroundColor(.accentColor)
                BackgroundColor(Color(.systemGray5).opacity(0.4))
            }
            // 加粗
            .strong {
                FontWeight(.bold)
            }
            // 斜体
            .emphasis {
                FontStyle(.italic)
            }
            // 链接
            .link {
                ForegroundColor(.accentColor)
            }
            // 引用块
            .blockquote { configuration in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor.opacity(0.6))
                        .frame(width: 3)
                    
                    configuration.label
                        .markdownTextStyle {
                            FontSize(fontSize)
                            ForegroundColor(.secondary)
                        }
                        .padding(.leading, 10)
                }
                .padding(.vertical, 4)
            }
            // 分隔线
            .thematicBreak {
                Divider()
                    .padding(.vertical, 8)
            }
            // 表格
            .table { configuration in
                configuration.label
                    .markdownTableBorderStyle(
                        .init(color: Color(.separator), width: 0.5)
                    )
                    .markdownTableBackgroundStyle(
                        .alternatingRows(
                            Color.clear,
                            Color(.systemGray6).opacity(0.4)
                        )
                    )
                    .markdownTextStyle {
                        FontSize(fontSize - 1)
                    }
                    .padding(.vertical, 4)
            }
            // 列表项
            .listItem { configuration in
                configuration.label
                    .markdownTextStyle {
                        FontSize(fontSize)
                    }
            }
            // 图片
            .image { configuration in
                configuration.label
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
    }
}

/// 纯文本语法高亮占位（不做高亮）
struct NoHighlightSyntaxHighlighter: CodeSyntaxHighlighter {
    func highlightCode(_ code: String, language: String?) -> Text {
        Text(code)
    }
}

extension CodeSyntaxHighlighter where Self == NoHighlightSyntaxHighlighter {
    static var noHighlight: NoHighlightSyntaxHighlighter { NoHighlightSyntaxHighlighter() }
}
