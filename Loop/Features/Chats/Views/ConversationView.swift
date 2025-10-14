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
        .safeAreaInset(edge: .bottom, spacing: 8) {
            MessageInputView(
                messageText: $viewModel.messageText,
                onSend: {
                    viewModel.sendMessage()
                },
                onTextChanged: {
                    viewModel.onTextChanged()
                }
            )
            .padding(.horizontal, 8)
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
                    HStack(spacing: 4) {
                        Text(chat.displayTitle)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        // Show badge for 1-on-1 chats if user has one
                        if !chat.isGroupChat, let badge = chat.otherParticipantBadgeType {
                            Image(systemName: badge.iconName)
                                .font(.system(size: 12))
                                .foregroundColor(badge.color)
                        }
                    }
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
        LazyVStack(spacing: 0, pinnedViews: []) {
            if viewModel.messages.isEmpty && !viewModel.isLoading {
                emptyState
            } else if viewModel.isLoading {
                loadingState
            } else {
                messagesWithTypingIndicator
            }
        }
        .animation(.spring(), value: viewModel.messages.count)
        .animation(.spring(), value: viewModel.messages.map { $0.likeCount })
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
                .foregroundColor(.primary)
            
            Text("Start the conversation")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
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
            VStack(spacing: 0) {
                // Date separator - centered with balanced spacing
                if shouldShowDateSeparator(at: index) {
                    Text(formatDateSeparator(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, index == 0 ? 0 : 16)
                        .padding(.bottom, 6)
                }
                
                // Timestamp - centered with minimal spacing
                if shouldShowTimestamp(at: index) {
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 10)
                        .padding(.bottom, 2)
                }
                
                MessageBubble(
                    message: message,
                    isGroupChat: chat.isGroupChat,
                    hasTail: shouldShowTail(at: index),
                    onLike: {
                        viewModel.toggleLike(for: message)
                    }
                )
                    .id(message.id)
                    .padding(.top, calculateMessageSpacing(at: index, message: message))
                    .animation(.spring(), value: message.likeCount)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.3, anchor: message.isFromUser ? .bottomTrailing : .bottomLeading)
                            .combined(with: .opacity)
                            .combined(with: .move(edge: message.isFromUser ? .trailing : .leading))
                            .combined(with: .offset(y: 15)),
                        removal: .scale(scale: 0.8, anchor: message.isFromUser ? .bottomTrailing : .bottomLeading)
                            .combined(with: .opacity)
                    ))
            }
        }
        
        // Typing indicator
        if viewModel.isOtherUserTyping {
            typingIndicatorBubble
                .padding(.top, calculateTypingIndicatorSpacing())
        }
    }
    
    // Calculate spacing between messages (iMessage-style grouping)
    private func calculateMessageSpacing(at index: Int, message: Message) -> CGFloat {
        // First message after date/timestamp separator needs minimal spacing
        if shouldShowDateSeparator(at: index) || shouldShowTimestamp(at: index) {
            return 2 // Minimal spacing after separator
        }
        
        // First message in conversation
        guard index > 0 else {
            return 0
        }
        
        let previousMessage = viewModel.messages[index - 1]
        let sameSender = message.isFromUser == previousMessage.isFromUser
        
        // Define spacing constants (grouped is exactly half of non-grouped)
        let differentSenderSpacing: CGFloat = 16
        let sameSenderSpacing: CGFloat = differentSenderSpacing / 2 // 8pt - exactly half
        
        // Calculate base spacing
        var spacing: CGFloat
        if sameSender {
            // Grouped messages from same sender - exactly half the spacing
            spacing = sameSenderSpacing
        } else {
            // Different sender - full spacing for visual separation
            spacing = differentSenderSpacing
        }
        
        // Add extra spacing if CURRENT message has likes (to make room for like bubble above)
        if message.likeCount > 0 {
            spacing += 8
        }
        
        return spacing
    }
    
    // Check if message should have a tail (only last message in a group)
    private func shouldShowTail(at index: Int) -> Bool {
        // Always show tail if it's the last message
        guard index < viewModel.messages.count - 1 else {
            return true
        }
        
        let currentMessage = viewModel.messages[index]
        let nextMessage = viewModel.messages[index + 1]
        
        // Show tail if next message is from different sender
        return currentMessage.isFromUser != nextMessage.isFromUser
    }
    
    // Check if we should show a date separator (new calendar day)
    private func shouldShowDateSeparator(at index: Int) -> Bool {
        guard index > 0 else { return true } // Always show date for first message
        
        let currentMessage = viewModel.messages[index]
        let previousMessage = viewModel.messages[index - 1]
        
        let calendar = Calendar.current
        let currentDay = calendar.startOfDay(for: currentMessage.timestamp)
        let previousDay = calendar.startOfDay(for: previousMessage.timestamp)
        
        // Only show date separator if it's a new calendar day
        return currentDay != previousDay
    }
    
    // Check if we should show a timestamp (5+ minute gap)
    private func shouldShowTimestamp(at: Int) -> Bool {
        guard at > 0 else { return false } // Don't show timestamp for first message (date separator handles it)
        
        let currentMessage = viewModel.messages[at]
        let previousMessage = viewModel.messages[at - 1]
        
        // Check if we're showing a date separator (if so, skip timestamp)
        if shouldShowDateSeparator(at: at) {
            return false
        }
        
        // Show timestamp if gap is 5 minutes or more
        let gap = currentMessage.timestamp.timeIntervalSince(previousMessage.timestamp)
        return gap >= 5 * 60 // 5 minutes in seconds
    }
    
    // Format date separator (e.g., "Yesterday 3:45 PM", "Sunday 10:30 AM", "Today 2:30 PM")
    private func formatDateSeparator(_ date: Date) -> AttributedString {
        let calendar = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        let timeString = timeFormatter.string(from: date)
        
        var dayString: String
        if calendar.isDateInToday(date) {
            dayString = "Today"
        } else if calendar.isDateInYesterday(date) {
            dayString = "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            // This week - show day name
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Full day name
            dayString = formatter.string(from: date)
        } else {
            // Older - show full date
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            dayString = formatter.string(from: date)
        }
        
        // Always include time with the day
        let fullString = "\(dayString) \(timeString)"
        
        // Create attributed string with medium weight for day, regular for time
        var attributedString = AttributedString(fullString)
        
        // Make the day part medium weight
        if let dayRange = attributedString.range(of: dayString) {
            attributedString[dayRange].font = .caption2.weight(.medium)
        }
        
        // Make the time part regular weight
        if let timeRange = attributedString.range(of: timeString) {
            attributedString[timeRange].font = .caption2.weight(.regular)
        }
        
        return attributedString
    }
    
    // Format timestamp (e.g., "Today 10:14 AM", "Yesterday 3:45 PM", "Monday 9:30 AM")
    private func formatTimestamp(_ date: Date) -> AttributedString {
        let calendar = Calendar.current
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        let timeString = timeFormatter.string(from: date)
        
        var dayString: String
        if calendar.isDateInToday(date) {
            dayString = "Today"
        } else if calendar.isDateInYesterday(date) {
            dayString = "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            // This week - show day name
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "EEEE" // Full day name
            dayString = dayFormatter.string(from: date)
        } else {
            // Older - show abbreviated date
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d" // e.g., "Oct 7"
            dayString = dateFormatter.string(from: date)
        }
        
        // Create attributed string with different font weights
        var attributedString = AttributedString("\(dayString) \(timeString)")
        
        // Make the day part slightly bolder
        if let dayRange = attributedString.range(of: dayString) {
            attributedString[dayRange].font = .caption2.weight(.medium)
        }
        
        // Keep the time part regular weight
        if let timeRange = attributedString.range(of: timeString) {
            attributedString[timeRange].font = .caption2.weight(.regular)
        }
        
        return attributedString
    }
    
    // Calculate spacing before typing indicator (consistent with message spacing)
    private func calculateTypingIndicatorSpacing() -> CGFloat {
        guard let lastMessage = viewModel.messages.last else {
            return 0
        }
        
        // Use the same spacing logic as messages (grouped is exactly half of non-grouped)
        let differentSenderSpacing: CGFloat = 16
        let sameSenderSpacing: CGFloat = differentSenderSpacing / 2 // 8pt - exactly half
        
        // Typing indicator is always from other user
        // If last message was from current user, use different-sender spacing
        // If last message was from other user, use same-sender spacing
        if lastMessage.isFromUser {
            return differentSenderSpacing // Different sender spacing
        } else {
            return sameSenderSpacing // Same sender spacing (grouped with previous messages)
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
                insertion: .scale(scale: 0.5, anchor: .bottomLeading)
                    .combined(with: .opacity)
                    .combined(with: .move(edge: .leading))
                    .combined(with: .offset(y: 10)),
                removal: .scale(scale: 0.5, anchor: .bottomLeading)
                    .combined(with: .opacity)
            )
        )
        .animation(.spring(), value: viewModel.isOtherUserTyping)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.spring()) {
            proxy.scrollTo("messagesBottom", anchor: .bottom)
        }
    }
}

#Preview {
    NavigationStack {
        ConversationView(chat: Chat(title: "Sample Chat", lastMessagePreview: "This is a sample message"))
    }
}
