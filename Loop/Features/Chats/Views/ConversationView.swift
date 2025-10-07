import SwiftUI

struct ConversationView: View {
    let chat: Chat
    @State private var viewModel: ConversationViewModel
    @State private var showingProfile = false
    @State private var scrollViewHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    init(chat: Chat) {
        self.chat = chat
        _viewModel = State(wrappedValue: ConversationViewModel(chatId: chat.id.uuidString))
    }
    
    // Determine if we should anchor to bottom (when content fills screen)
    private var shouldAnchorToBottom: Bool {
        guard scrollViewHeight > 0 else { return false }
        // Only anchor to bottom if we have many messages or content exceeds 70% of screen
        return viewModel.messages.count > 8 || contentHeight > (scrollViewHeight * 0.7)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        // Spacer to push messages to bottom when content is small
                        if shouldAnchorToBottom {
                            Spacer(minLength: 0)
                        }
                        
                    LazyVStack(spacing: 8) {
                    if viewModel.messages.isEmpty && !viewModel.isLoading {
                        // Empty state
                        VStack(spacing: 20) {
                            Image(systemName: "message.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue.opacity(0.6))

                            Text("Start the conversation")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)

                            Text("Send a message to begin chatting with \(chat.displayTitle)")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else if viewModel.isLoading {
                        // Loading state
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading messages...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 0)
                .padding(.top, 20)
                .background(
                    GeometryReader { contentGeometry in
                        Color.clear.onAppear {
                            contentHeight = contentGeometry.size.height
                        }
                        .onChange(of: contentGeometry.size.height) { _, newHeight in
                            contentHeight = newHeight
                        }
                    }
                )
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(shouldAnchorToBottom ? .bottom : .top)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if shouldAnchorToBottom {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onAppear {
                    scrollViewHeight = geometry.size.height
                    if shouldAnchorToBottom {
                        scrollToBottom(proxy: proxy)
                    }
                }
                .onChange(of: geometry.size.height) { _, newHeight in
                    scrollViewHeight = newHeight
                }
                .contentMargins(.bottom, 8, for: .scrollContent)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MessageInputView(messageText: $viewModel.messageText) {
                viewModel.sendMessage()
            }
        }
        .navigationTitle(chat.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: {
                    if !chat.isGroupChat {
                        showingProfile = true
                    }
                }) {
                    Text(chat.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .disabled(chat.isGroupChat)
            }
        }
        .sheet(isPresented: $showingProfile) {
            if let otherUserId = chat.otherParticipantId {
                ProfileView(userId: otherUserId)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation(.easeInOut(duration: 0.3)) {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(chat: Chat(title: "Sample Chat", lastMessagePreview: "This is a sample message"))
    }
}
