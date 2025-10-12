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
        .toolbar(.visible, for: .tabBar)
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
                    .id("messagesBottom")
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .scrollDismissesKeyboard(.interactively)
            .defaultScrollAnchor(shouldAnchorToBottom ? .bottom : .top)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isOtherUserTyping) { _, isTyping in
                if isTyping {
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
            .contentMargins(.bottom, AppConstants.UI.spacing, for: .scrollContent)
            .task {
                // Mark chat as read when conversation opens
                try? await FirebaseService.shared.markChatAsRead(chatId: chat.id.uuidString)
                
                // Continuously mark as read while viewing (every 2 seconds)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    try? await FirebaseService.shared.markChatAsRead(chatId: chat.id.uuidString)
                }
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
        LazyVStack(spacing: AppConstants.UI.spacing, pinnedViews: []) {
            if viewModel.messages.isEmpty && !viewModel.isLoading {
                emptyState
            } else if viewModel.isLoading {
                loadingState
            } else {
                messagesWithTypingIndicator
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets())
        .padding(.horizontal, AppConstants.UI.padding)
        .padding(.top, AppConstants.UI.padding)
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
                .modifier(ScrollEffectModifier())
                .id(message.id)
        }
        
        // Typing indicator
        if viewModel.isOtherUserTyping {
            typingIndicatorBubble
                .transition(.opacity)
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
        HStack(spacing: 0) {
            TypingIndicatorView()
                .padding(.horizontal, AppConstants.UI.padding)
                .padding(.vertical, AppConstants.UI.spacing + 2)
                .background(Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            Spacer(minLength: 0)
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .leading).combined(with: .scale(scale: 0.8, anchor: .leading)).combined(with: .opacity),
                removal: .opacity.combined(with: .scale(scale: 0.8, anchor: .leading))
            )
        )
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        proxy.scrollTo("messagesBottom", anchor: .bottom)
    }
}

// MARK: - Scroll Effect Modifier
struct ScrollEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .visualEffect { content, geometryProxy in
                content
                    .scaleEffect(scaleForPosition(geometryProxy))
            }
    }
    
    private func scaleForPosition(_ proxy: GeometryProxy) -> CGFloat {
        let midY = proxy.frame(in: .global).midY
        let screenHeight = UIScreen.main.bounds.height
        let centerY = screenHeight / 2
        
        let distance = abs(midY - centerY)
        let maxDistance = screenHeight / 2
        let normalizedDistance = min(distance / maxDistance, 1.0)
        
        // Scale from 1.0 at center to 0.95 at edges
        return 1.0 - (normalizedDistance * 0.05)
    }
}

#Preview {
    NavigationStack {
        ConversationView(chat: Chat(title: "Sample Chat", lastMessagePreview: "This is a sample message"))
    }
}
