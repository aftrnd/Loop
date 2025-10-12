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
            messageScrollView(geometry: geometry)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MessageInputView(
                messageText: $viewModel.messageText,
                onSend: {
                    viewModel.sendMessage()
                },
                onTextChanged: {
                    viewModel.onTextChanged()
                }
            )
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
    
    // MARK: - View Components
    
    @ViewBuilder
    private func messageScrollView(geometry: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                messageContent
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
            .task {
                // Mark chat as read when conversation opens
                try? await FirebaseService.shared.markChatAsRead(chatId: chat.id.uuidString)
            }
        }
    }
    
    private var messageContent: some View {
        VStack(spacing: 0) {
            // Spacer to push messages to bottom when content is small
            if shouldAnchorToBottom {
                Spacer(minLength: 0)
            }
            
            messageList
        }
    }
    
    private var messageList: some View {
        LazyVStack(spacing: 8) {
            if viewModel.messages.isEmpty && !viewModel.isLoading {
                emptyState
            } else if viewModel.isLoading {
                loadingState
            } else {
                messagesWithTypingIndicator
            }
        }
        .padding(.horizontal, 0)
        .padding(.top, 20)
        .background(contentSizeReader)
    }
    
    private var emptyState: some View {
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
    }
    
    private var loadingState: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading messages...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    @ViewBuilder
    private var messagesWithTypingIndicator: some View {
        ForEach(viewModel.messages) { message in
            MessageBubble(message: message)
                .id(message.id)
        }
        
        // Typing indicator
        if viewModel.isOtherUserTyping {
            typingIndicatorBubble
        }
    }
    
    private var contentSizeReader: some View {
        GeometryReader { contentGeometry in
            Color.clear
                .onAppear {
                    contentHeight = contentGeometry.size.height
                }
                .onChange(of: contentGeometry.size.height) { _, newHeight in
                    contentHeight = newHeight
                }
        }
    }
    
    // Computed property for typing indicator to reduce expression complexity
    private var typingIndicatorBubble: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                TypingIndicatorView()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray5))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            
            Spacer(minLength: 60)
        }
        .padding(.horizontal, 20)
        .transition(typingIndicatorTransition)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isOtherUserTyping)
    }
    
    // Separate transition to help compiler
    private var typingIndicatorTransition: AnyTransition {
        let insertionTransition = AnyTransition.scale(scale: 0.8, anchor: .leading)
            .combined(with: .move(edge: .leading))
            .combined(with: .opacity)
        
        let removalTransition = AnyTransition.scale(scale: 0.8, anchor: .leading)
            .combined(with: .move(edge: .leading))
            .combined(with: .opacity)
        
        return .asymmetric(insertion: insertionTransition, removal: removalTransition)
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
