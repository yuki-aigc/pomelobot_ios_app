import SwiftUI

/// 聊天主界面 - iOS 26 Liquid Glass
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showConversationList = false
    
    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                // 连接状态栏 (Liquid Glass)
                ConnectionStatusView(
                    state: viewModel.wsService.connectionState,
                    onConnect: { viewModel.connect() },
                    onDisconnect: { viewModel.disconnect() }
                )
                
                // 消息列表
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(viewModel.messages) { message in
                                MessageBubbleView(
                                    message: message,
                                    showTimestamp: viewModel.settings.showTimestamps,
                                    fontSize: viewModel.settings.fontSize
                                )
                                .id(message.id)
                            }
                            
                            // Loading 指示器
                            if viewModel.isLoading {
                                TypingIndicatorView()
                                    .id("typing-indicator")
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: viewModel.messages.count) { _, _ in
                        withAnimation(.easeOut(duration: 0.3)) {
                            if viewModel.isLoading {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            } else if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: viewModel.isLoading) { _, loading in
                        if loading {
                            withAnimation {
                                proxy.scrollTo("typing-indicator", anchor: .bottom)
                            }
                        }
                    }
                }
                .onTapGesture {
                    isInputFocused = false
                }
                
                // 输入栏 (Liquid Glass)
                InputBarView(
                    text: $viewModel.inputText,
                    isConnected: viewModel.wsService.connectionState.isReady,
                    isLoading: viewModel.isLoading,
                    isFocused: $isInputFocused,
                    onSend: { viewModel.sendMessage() }
                )
            }
        }
        .navigationTitle(viewModel.currentConversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showConversationList = true
                } label: {
                    Image(systemName: "list.bullet")
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        viewModel.createNewConversation()
                    } label: {
                        Label("新建对话", systemImage: "plus.message")
                    }
                    
                    Button(role: .destructive) {
                        viewModel.clearMessages()
                    } label: {
                        Label("清空消息", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showConversationList) {
            ConversationListSheet(
                conversations: viewModel.conversations,
                currentId: viewModel.currentConversation.id,
                onSelect: { conversation in
                    viewModel.switchConversation(conversation)
                    showConversationList = false
                },
                onNew: {
                    viewModel.createNewConversation()
                    showConversationList = false
                }
            )
        }
    }
}

// MARK: - 输入栏 (Liquid Glass)

struct InputBarView: View {
    @Binding var text: String
    let isConnected: Bool
    let isLoading: Bool
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    
    var canSend: Bool {
        isConnected && !isLoading && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            // 多行文本输入
            TextField("输入消息...", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .focused(isFocused)
                .disabled(!isConnected)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
            
            // 发送按钮 - Liquid Glass 圆形
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canSend ? .white : Color(.systemGray3))
                    .frame(width: 36, height: 36)
            }
            .glassEffect(.regular.interactive().tint(canSend ? .accentColor : .gray), in: .circle)
            .disabled(!canSend)
            .animation(.smooth(duration: 0.2), value: canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 0))
    }
}

// MARK: - Typing 指示器 (Liquid Glass)

struct TypingIndicatorView: View {
    @State private var phase = 0.0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 8, height: 8)
                        .offset(y: phase == Double(index) ? -6 : 0)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(in: .capsule)
            
            Spacer()
        }
        .padding(.leading, 44) // 对齐 bot 头像右侧
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) {
                phase = 2.0
            }
        }
    }
}

// MARK: - 会话列表 Sheet

struct ConversationListSheet: View {
    let conversations: [Conversation]
    let currentId: String
    let onSelect: (Conversation) -> Void
    let onNew: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(conversations) { conversation in
                    Button {
                        onSelect(conversation)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(conversation.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                if let lastMessage = conversation.lastMessage {
                                    Text(lastMessage)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            if conversation.id == currentId {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("对话列表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onNew()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
