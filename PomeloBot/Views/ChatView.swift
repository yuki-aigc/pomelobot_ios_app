import SwiftUI

/// 聊天主界面
struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showConversationList = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 连接状态栏
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
                                fontSize: viewModel.settings.fontSize,
                                skipAnimation: viewModel.animatedMessageIds.contains(message.id),
                                onAnimationDone: {
                                    viewModel.markAnimationDone(message.id)
                                }
                            )
                            .id(message.id)
                        }
                        
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
            
            // 输入栏
            InputBarView(
                text: $viewModel.inputText,
                isConnected: viewModel.wsService.connectionState.isReady,
                isLoading: viewModel.isLoading,
                isFocused: $isInputFocused,
                onSend: { viewModel.sendMessage() }
            )
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
        .onAppear {
            if viewModel.wsService.connectionState == .disconnected {
                viewModel.connect()
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

// MARK: - 输入栏

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
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 10) {
                // 文本输入
                TextField("输入消息...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 20))
                    .focused(isFocused)
                    .disabled(!isConnected)
                    .onSubmit {
                        if canSend { onSend() }
                    }
                
                // 发送按钮
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(
                            .white,
                            canSend ? Color.accentColor : Color(.systemGray4)
                        )
                }
                .disabled(!canSend)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

// MARK: - Typing 指示器

struct TypingIndicatorView: View {
    @State private var phase = 0.0
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                // Bot 头像占位
                BotAvatarView()
                    .padding(.trailing, 8)
                
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color(.systemGray3))
                            .frame(width: 8, height: 8)
                            .offset(y: phase == Double(index) ? -6 : 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 18))
            }
            
            Spacer()
        }
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
