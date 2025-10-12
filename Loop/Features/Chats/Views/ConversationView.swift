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
            .padding(.horizontal, 18)
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
        .toolbar(.hidden, for: .tabBar)
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
            .scrollBounceBehavior(.always, axes: [.vertical])
            .scrollIndicators(.visible)
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
        .animation(.spring(response: 0.6, dampingFraction: 0.65, blendDuration: 0), value: viewModel.messages.count)
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
        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
            MessageBubble(message: message)
                .id(message.id)
                .padding(.top, shouldAddExtraSpacing(at: index) ? AppConstants.UI.spacing : 0)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.3, anchor: message.isFromUser ? .bottomTrailing : .bottomLeading)
                        .combined(with: .opacity)
                        .combined(with: .move(edge: message.isFromUser ? .trailing : .leading))
                        .combined(with: .offset(y: 15)),
                    removal: .scale(scale: 0.8, anchor: message.isFromUser ? .bottomTrailing : .bottomLeading)
                        .combined(with: .opacity)
                ))
        }
        
        // Typing indicator
        if viewModel.isOtherUserTyping {
            typingIndicatorBubble
                .padding(.top, shouldAddExtraSpacingForTypingIndicator() ? AppConstants.UI.spacing : 0)
        }
    }
    
    // Check if we should add extra spacing between messages from different senders
    private func shouldAddExtraSpacing(at index: Int) -> Bool {
        guard index > 0 else { return false }
        let currentMessage = viewModel.messages[index]
        let previousMessage = viewModel.messages[index - 1]
        // Add extra spacing when sender changes
        return currentMessage.isFromUser != previousMessage.isFromUser
    }
    
    // Check if we should add extra spacing before typing indicator
    private func shouldAddExtraSpacingForTypingIndicator() -> Bool {
        guard let lastMessage = viewModel.messages.last else { return false }
        // Add extra spacing if last message was from current user (typing indicator is always from other user)
        return lastMessage.isFromUser
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
                insertion: .scale(scale: 0.5, anchor: .bottomLeading)
                    .combined(with: .opacity)
                    .combined(with: .move(edge: .leading))
                    .combined(with: .offset(y: 10)),
                removal: .scale(scale: 0.5, anchor: .bottomLeading)
                    .combined(with: .opacity)
            )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.65), value: viewModel.isOtherUserTyping)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            proxy.scrollTo("messagesBottom", anchor: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(chat: Chat(title: "Sample Chat", lastMessagePreview: "This is a sample message"))
    }
}
