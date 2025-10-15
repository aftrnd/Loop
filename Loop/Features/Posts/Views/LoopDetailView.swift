import SwiftUI

struct LoopDetailView: View {
    @StateObject private var viewModel: LoopDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var profileUserToShow: ProfileUser?
    
    init(loop: Loop, onRepliesChanged: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: LoopDetailViewModel(loop: loop, onRepliesChanged: onRepliesChanged))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Main loop (the one being replied to)
                    LoopCardView(
                        loop: viewModel.loop,
                        isLiked: viewModel.isLikedByCurrentUser(viewModel.loop),
                        cardIndex: 0,
                        onLike: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            Task {
                                await viewModel.toggleLike(for: viewModel.loop)
                            }
                        },
                        onReply: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            viewModel.showReplyCompose()
                        },
                        onDelete: nil, // Can't delete main loop from detail view
                        onAvatarTap: {
                            profileUserToShow = ProfileUser(userId: viewModel.loop.authorId)
                        },
                        onCardTap: nil, // Already in detail view, no need to navigate
                        replyPreviews: nil // Don't show reply previews in detail view
                    )
                    .padding(.horizontal, -10) // Cancel out LoopCardView's internal 10pt padding to match page padding
                    .padding(.top, 10)
                    
                    // Divider above replies section
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(maxWidth: .infinity)
                        .frame(height: 1.15)
                        .padding(.top, 3)
                    
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
                        // Comments header
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
                        .padding(.top, 20)
                        .padding(.bottom, 8)
                        
                        // Replies list - threaded structure with collapsible nested replies
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.threadedReplies.enumerated()), id: \.element.id) { index, threadedReply in
                                ZStack(alignment: .topLeading) {
                                    // Connecting line overlay (only when expanded)
                                    if threadedReply.isExpanded && !threadedReply.nestedReplies.isEmpty {
                                        // Line starts below parent avatar + gap
                                        let lineStartY = CardLayoutConstants.topPadding + CardLayoutConstants.avatarSize + CardLayoutConstants.avatarLineGap
                                        
                                        // Estimate card heights more accurately
                                        // Structure of ReplyCardView:
                                        // - 12pt top padding
                                        // - 56px avatar (in header with content beside it)
                                        // - 12pt spacing (between header and content)
                                        // - Content (variable, estimated ~40pt for 2 lines)
                                        // - Action buttons (~30pt)
                                        // - 12pt bottom padding
                                        // Total minimum: ~150pt per card
                                        let estimatedCardHeight: CGFloat = 145
                                        
                                        // Calculate where last nested avatar's top is:
                                        // 1. Parent card takes up estimatedCardHeight
                                        // 2. Then all nested replies except last: (count - 1) * estimatedCardHeight
                                        // 3. Then last reply's top padding to get to its avatar top
                                        let parentCardHeight = estimatedCardHeight
                                        let nestedRepliesBeforeLast = CGFloat(threadedReply.nestedReplies.count - 1) * estimatedCardHeight
                                        let lastAvatarTop = parentCardHeight + nestedRepliesBeforeLast + CardLayoutConstants.topPadding
                                        
                                        // Line ends before last nested avatar - gap
                                        let lineEndY = lastAvatarTop - CardLayoutConstants.avatarLineGap
                                        let lineHeight = max(10, lineEndY - lineStartY) // Minimum 10pt line
                                        
                                        RoundedRectangle(cornerRadius: CardLayoutConstants.conversationLineWidth / 2)
                                            .fill(Color(.quaternaryLabel))
                                            .frame(width: CardLayoutConstants.conversationLineWidth, height: lineHeight)
                                            .offset(x: CardLayoutConstants.avatarSize / 2 - CardLayoutConstants.conversationLineWidth / 2, y: lineStartY) // Replies have negative padding, so no need to add horizontal padding
                                    }
                                    
                                    VStack(spacing: 0) {
                                        // Top-level reply
                                        ReplyCardView(
                                            reply: threadedReply.reply,
                                            isLiked: viewModel.isLikedByCurrentUser(threadedReply.reply),
                                            indentLevel: 0,
                                            nestedReplyCount: threadedReply.nestedReplies.count,
                                            isExpanded: threadedReply.isExpanded,
                                            isLastInThread: false, // Top-level comments are never "last in thread"
                                            onLike: {
                                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                impactFeedback.impactOccurred()
                                                
                                                Task {
                                                    await viewModel.toggleLike(for: threadedReply.reply)
                                                }
                                            },
                                            onReply: {
                                                // Always reply to the top-level comment, adding to nested list
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
                                            }
                                        )
                                        .padding(.horizontal, -CardLayoutConstants.horizontalPadding) // Cancel internal padding to match main post
                                        
                                        // Show nested replies if expanded
                                        if threadedReply.isExpanded {
                                            // Divider after parent reply when expanded (aligned with name/text)
                                            Rectangle()
                                                .fill(Color(.separator))
                                                .frame(maxWidth: .infinity)
                                                .frame(height: CardLayoutConstants.dividerHeight)
                                                .padding(.leading, CardLayoutConstants.contentShift) // Avatar + spacing (replies have negative padding)
                                            
                                            ForEach(Array(threadedReply.nestedReplies.enumerated()), id: \.element.id) { nestedIndex, nestedReply in
                                                ReplyCardView(
                                                    reply: nestedReply,
                                                    isLiked: viewModel.isLikedByCurrentUser(nestedReply),
                                                    indentLevel: 1,
                                                    nestedReplyCount: 0,
                                                    isExpanded: false,
                                                    isLastInThread: nestedIndex == threadedReply.nestedReplies.count - 1, // Check if this is the last nested reply
                                                    onLike: {
                                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                        impactFeedback.impactOccurred()
                                                        
                                                        Task {
                                                            await viewModel.toggleLike(for: nestedReply)
                                                        }
                                                    },
                                                    onReply: (nestedIndex == threadedReply.nestedReplies.count - 1) ? {
                                                        // Only last nested reply can be replied to
                                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                        impactFeedback.impactOccurred()
                                                        
                                                        viewModel.replyToReply(threadedReply.reply) // Reply to parent comment
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
                                                    }
                                                )
                                                .padding(.horizontal, -CardLayoutConstants.horizontalPadding) // Cancel internal padding to match main post
                                                
                                                // Divider between nested replies (aligned with name/text)
                                                if nestedIndex < threadedReply.nestedReplies.count - 1 {
                                                    Rectangle()
                                                        .fill(Color(.separator))
                                                        .frame(maxWidth: .infinity)
                                                        .frame(height: CardLayoutConstants.dividerHeight)
                                                        .padding(.leading, CardLayoutConstants.contentShift) // Avatar + spacing (replies have negative padding)
                                                }
                                            }
                                            
                                            // "Hide replies" button at bottom when expanded
                                            HStack {
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
                                                .padding(.leading, 0) // Left-aligned like "View replies"
                                                .padding(.bottom, 12) // Bottom padding to match divider spacing
                                                
                                                Spacer()
                                            }
                                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                                        }
                                    }
                                }
                                
                                // Divider after each top-level reply
                                if index < viewModel.threadedReplies.count - 1 {
                                    Rectangle()
                                        .fill(Color(.separator))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 1.15)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 20) // Doubled padding for more breathing room
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

