import SwiftUI

struct LoopDetailView: View {
    @StateObject private var viewModel: LoopDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var profileUserToShow: ProfileUser?
    @State private var replyHeights: [String: CGFloat] = [:] // Store actual heights by reply ID
    
    // Debug overlay
    @AppStorage("showLayoutDebugOverlays") private var showDebugOverlay = false
    
    init(loop: Loop, onRepliesChanged: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: LoopDetailViewModel(loop: loop, onRepliesChanged: onRepliesChanged))
    }
    
    // Helper function to calculate conversation line height
    private func calculateLineHeight(for threadedReply: ThreadedReply) -> CGFloat {
        guard let parentHeight = replyHeights[threadedReply.reply.id], parentHeight > 0 else {
            return 0
        }
        
        // Line starts below parent avatar + gap
        let lineStartY = CardLayoutConstants.topPadding + CardLayoutConstants.avatarSize + CardLayoutConstants.avatarLineGap
        
        // Calculate where last nested avatar's top is using actual measurements
        // 1. Parent card actual height
        let parentCardHeight = parentHeight
        // 2. Divider after parent
        let dividerHeight = CardLayoutConstants.dividerHeight
        // 3. Sum of all nested reply heights except the last
        var nestedHeightsBeforeLast: CGFloat = 0
        for i in 0..<(threadedReply.nestedReplies.count - 1) {
            let nestedReply = threadedReply.nestedReplies[i]
            nestedHeightsBeforeLast += replyHeights[nestedReply.id] ?? 145
            // Add divider height between nested replies
            if i < threadedReply.nestedReplies.count - 2 {
                nestedHeightsBeforeLast += CardLayoutConstants.dividerHeight
            }
        }
        
        // 4. Last reply's top padding to get to its avatar top
        let lastAvatarTop = parentCardHeight + dividerHeight + nestedHeightsBeforeLast + CardLayoutConstants.topPadding
        
        // Line ends before last nested avatar - gap
        let lineEndY = lastAvatarTop - CardLayoutConstants.avatarLineGap
        return max(10, lineEndY - lineStartY)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Main loop (the one being replied to)
                    PostCard(
                        loop: viewModel.loop,
                        isLiked: viewModel.isLikedByCurrentUser(viewModel.loop),
                        onLike: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            Task {
                                await viewModel.toggleLike(for: viewModel.loop)
                            }
                        },
                        onComment: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            viewModel.showReplyCompose()
                        },
                        onShare: nil,
                        onDelete: nil, // Can't delete main loop from detail view
                        onAvatarTap: {
                            profileUserToShow = ProfileUser(userId: viewModel.loop.authorId)
                        },
                        showDebugOverlays: showDebugOverlay
                    )
                    .padding(.top, 10)
                    
                    // Divider above replies section
                    PostDivider()
                        .padding(.top, 5)
                    
                    // Replies section
                    if viewModel.isLoading && viewModel.threadedReplies.isEmpty {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading comments...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 40)
                    } else if viewModel.threadedReplies.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 8) {
                                Text("No Comments")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Be the first to comment!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                viewModel.showReplyCompose()
                            }) {
                                Text("Add Comment")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.primary)
                                    .foregroundColor(Color(.systemBackground))
                                    .cornerRadius(20)
                            }
                        }
                        .padding(.vertical, 40)
                    } else {
                        // Comments header - in container matching posts
                        VStack(spacing: 0) {
                            HStack {
                                Text("Comments")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                                
                                Text("\(viewModel.replies.count)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .padding(.horizontal, CardLayoutConstants.horizontalPadding)
                        .padding(.top, CardLayoutConstants.topPadding)
                        .padding(.bottom, CardLayoutConstants.bottomPadding)
                        .background(Color(.systemBackground))
                        .overlay(
                            Group {
                                if showDebugOverlay {
                                    RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius)
                                        .stroke(Color.red, lineWidth: 2)
                                }
                            }
                        )
                        .padding(.top, 5)
                        
                        PostDivider()
                            .padding(.top, 5)
                        
                        // Replies list - threaded structure with collapsible nested replies
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.threadedReplies.enumerated()), id: \.element.id) { index, threadedReply in
                                ZStack(alignment: .topLeading) {
                                    // Connecting line overlay (only when expanded)
                                    if threadedReply.isExpanded && !threadedReply.nestedReplies.isEmpty {
                                        let lineHeight = calculateLineHeight(for: threadedReply)
                                        
                                        if lineHeight > 0 {
                                            let lineStartY = CardLayoutConstants.topPadding + CardLayoutConstants.avatarSize + CardLayoutConstants.avatarLineGap
                                            let lineX = CardLayoutConstants.horizontalPadding + CardLayoutConstants.avatarSize / 2 - CardLayoutConstants.conversationLineWidth / 2
                                            
                                            RoundedRectangle(cornerRadius: CardLayoutConstants.conversationLineWidth / 2)
                                                .fill(CardLayoutConstants.conversationLineColor)
                                                .frame(width: CardLayoutConstants.conversationLineWidth, height: lineHeight)
                                                .offset(x: lineX, y: lineStartY)
                                        }
                                    }
                                    
                                    VStack(spacing: 0) {
                                        // Top-level reply - wrapped in container like PostCard
                                        ReplyCardView(
                                            reply: threadedReply.reply,
                                            isLiked: viewModel.isLikedByCurrentUser(threadedReply.reply),
                                            indentLevel: 0,
                                            nestedReplyCount: threadedReply.nestedReplies.count,
                                            isExpanded: threadedReply.isExpanded,
                                            isLastInThread: false,
                                            onLike: {
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                impactFeedback.impactOccurred()
                                                
                                                Task {
                                                    await viewModel.toggleLike(for: threadedReply.reply)
                                                }
                                            },
                                            onReply: {
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                impactFeedback.impactOccurred()
                                                
                                                viewModel.replyToReply(threadedReply.reply)
                                            },
                                            onToggleExpanded: threadedReply.nestedReplies.isEmpty ? nil : {
                                                withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
                                                    viewModel.toggleReplyExpansion(threadedReply.id)
                                                }
                                            },
                                            onDelete: viewModel.canDeleteLoop(threadedReply.reply) ? {
                                                let impactFeedback = UINotificationFeedbackGenerator()
                                                impactFeedback.notificationOccurred(.warning)
                                                
                                                Task {
                                                    await viewModel.deleteLoop(threadedReply.reply)
                                                }
                                            } : nil,
                                            onAvatarTap: {
                                                profileUserToShow = ProfileUser(userId: threadedReply.reply.authorId)
                                            },
                                            applyInternalPadding: false
                                        )
                                        .padding(.horizontal, CardLayoutConstants.horizontalPadding)
                                        .padding(.top, CardLayoutConstants.topPadding)
                                        .padding(.bottom, CardLayoutConstants.bottomPadding)
                                        .background(Color(.systemBackground))
                                        .overlay(
                                            Group {
                                                if showDebugOverlay {
                                                    RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius)
                                                        .stroke(Color.red, lineWidth: 2)
                                                }
                                            }
                                        )
                                        .overlay(
                                            GeometryReader { geo in
                                                Color.clear
                                                    .onAppear {
                                                        replyHeights[threadedReply.reply.id] = geo.size.height
                                                    }
                                                    .onChange(of: geo.size.height) { newHeight in
                                                        replyHeights[threadedReply.reply.id] = newHeight
                                                    }
                                            }
                                        )
                                        .padding(.top, index == 0 ? 0 : 5)
                                        .padding(.bottom, index == viewModel.threadedReplies.count - 1 ? 0 : 5)
                                        
                                        // Show nested replies if expanded
                                        if threadedReply.isExpanded {
                                            // Divider after parent reply when expanded (aligned with name/text)
                                            Rectangle()
                                                .fill(CardLayoutConstants.dividerColor)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: CardLayoutConstants.dividerHeight)
                                                .padding(.leading, CardLayoutConstants.contentShift)
                                            
                                            ForEach(Array(threadedReply.nestedReplies.enumerated()), id: \.element.id) { nestedIndex, nestedReply in
                                                ReplyCardView(
                                                    reply: nestedReply,
                                                    isLiked: viewModel.isLikedByCurrentUser(nestedReply),
                                                    indentLevel: 1,
                                                    nestedReplyCount: 0,
                                                    isExpanded: false,
                                                    isLastInThread: nestedIndex == threadedReply.nestedReplies.count - 1,
                                                    onLike: {
                                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                        impactFeedback.impactOccurred()
                                                        
                                                        Task {
                                                            await viewModel.toggleLike(for: nestedReply)
                                                        }
                                                    },
                                                    onReply: (nestedIndex == threadedReply.nestedReplies.count - 1) ? {
                                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                        impactFeedback.impactOccurred()
                                                        
                                                        viewModel.replyToReply(threadedReply.reply)
                                                    } : nil,
                                                    onToggleExpanded: nil,
                                                    onDelete: viewModel.canDeleteLoop(nestedReply) ? {
                                                        let impactFeedback = UINotificationFeedbackGenerator()
                                                        impactFeedback.notificationOccurred(.warning)
                                                        
                                                        Task {
                                                            await viewModel.deleteLoop(nestedReply)
                                                        }
                                                    } : nil,
                                                    onAvatarTap: {
                                                        profileUserToShow = ProfileUser(userId: nestedReply.authorId)
                                                    },
                                                    applyInternalPadding: false
                                                )
                                                .padding(.horizontal, CardLayoutConstants.horizontalPadding)
                                                .overlay(
                                                    GeometryReader { geo in
                                                        Color.clear
                                                            .onAppear {
                                                                replyHeights[nestedReply.id] = geo.size.height
                                                            }
                                                            .onChange(of: geo.size.height) { newHeight in
                                                                replyHeights[nestedReply.id] = newHeight
                                                            }
                                                    }
                                                )
                                                
                                                // Divider between nested replies (aligned with name/text)
                                                if nestedIndex < threadedReply.nestedReplies.count - 1 {
                                                    Rectangle()
                                                        .fill(CardLayoutConstants.dividerColor)
                                                        .frame(maxWidth: .infinity)
                                                        .frame(height: CardLayoutConstants.dividerHeight)
                                                        .padding(.leading, CardLayoutConstants.contentShift)
                                                }
                                            }
                                            
                                            // "Hide replies" button at bottom when expanded - aligned like action buttons
                                            VStack(spacing: 0) {
                                                HStack(spacing: 0) {
                                                    Button(action: {
                                                        withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
                                                            viewModel.toggleReplyExpansion(threadedReply.id)
                                                        }
                                                    }) {
                                                        HStack(spacing: 6) {
                                                            Image(systemName: "chevron.up")
                                                                .font(.system(size: 12, weight: .semibold))
                                                                .foregroundColor(.secondary)
                                                            
                                                            Text("Hide replies")
                                                                .font(.caption)
                                                                .fontWeight(.medium)
                                                                .foregroundColor(.secondary)
                                                        }
                                                        .padding(.vertical, 6)
                                                        .padding(.horizontal, 12)
                                                        .background(Color(.systemGray5))
                                                        .cornerRadius(8)
                                                    }
                                                    .buttonStyle(.plain)
                                                    
                                                    Spacer()
                                                }
                                                .padding(.top, 8)
                                            }
                                            .padding(.horizontal, CardLayoutConstants.horizontalPadding)
                                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                                        }
                                    }
                                }
                                
                                // Divider after each top-level reply
                                if index < viewModel.threadedReplies.count - 1 {
                                    PostDivider()
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 10) // Foundation padding - matches home/messages listRowInsets
            }
            .background(Color(.systemBackground))
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        viewModel.showReplyCompose()
                    }) {
                        Image(systemName: "arrow.turn.up.left")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
            }
            .refreshable {
                await viewModel.refreshReplies()
            }
        }
        .sheet(isPresented: $viewModel.showingCompose) {
            ComposeLoopView(
                draft: $viewModel.composeDraft,
                isPresented: $viewModel.showingCompose,
                onPost: {
                    await viewModel.postReply()
                }
            )
            .presentationDetents([.fraction(0.40), .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough: .fraction(0.35)))
            .presentationContentInteraction(.scrolls)
        }
        .sheet(item: $profileUserToShow) { profileUser in
            ProfileView(userId: profileUser.userId)
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            await viewModel.loadReplies()
            viewModel.startListeningForReplies()
        }
    }
}

#Preview {
    LoopDetailView(
        loop: Loop(
            authorId: "user1",
            content: "This is the main loop post that people are replying to. It has some interesting content that sparked a discussion!",
            media: [],
            likes: ["user2", "user3"],
            replies: ["reply1", "reply2", "reply3"],
            authorDisplayName: "John Doe",
            authorUsername: "johndoe",
            authorBadgeType: .verified
        )
    )
}

