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
                    .padding(.horizontal, -10) // Cancel out LoopCardView's internal padding
                    .padding(.top, 10)
                    
                    // Divider above replies section
                    Divider()
                        .padding(.top, 12)
                    
                    // Replies section
                    if viewModel.isLoading && viewModel.threadedReplies.isEmpty {
                        // Loading state
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading replies...")
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
                                Text("No replies yet")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Text("Be the first to reply!")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button(action: {
                                viewModel.showReplyCompose()
                            }) {
                                Text("Add Reply")
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(Color.accentColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(20)
                            }
                        }
                        .padding(.vertical, 40)
                    } else {
                        // Replies header
                        HStack {
                            Text("Replies")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("\(viewModel.replies.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 12)
                        
                        // Replies list - threaded structure with collapsible nested replies
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.threadedReplies.enumerated()), id: \.element.id) { index, threadedReply in
                                ZStack(alignment: .topLeading) {
                                    // Connecting line overlay (only when expanded)
                                    if threadedReply.isExpanded && !threadedReply.nestedReplies.isEmpty {
                                        // Calculate line height based on number of nested replies
                                        let nestedRepliesHeight = CGFloat(threadedReply.nestedReplies.count) * 100 // Approximate height per reply
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.3))
                                            .frame(width: 2)
                                            .offset(x: 27, y: 68) // Position at avatar center, start below parent avatar
                                            .frame(height: nestedRepliesHeight + 30) // Extend to last nested avatar with padding
                                    }
                                    
                                    VStack(spacing: 0) {
                                        // Top-level reply
                                        ReplyCardView(
                                            reply: threadedReply.reply,
                                            isLiked: viewModel.isLikedByCurrentUser(threadedReply.reply),
                                            indentLevel: 0,
                                            nestedReplyCount: threadedReply.nestedReplies.count,
                                            isExpanded: threadedReply.isExpanded,
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
                                            }
                                        )
                                        
                                        // Show nested replies if expanded
                                        if threadedReply.isExpanded {
                                            ForEach(Array(threadedReply.nestedReplies.enumerated()), id: \.element.id) { nestedIndex, nestedReply in
                                                ReplyCardView(
                                                    reply: nestedReply,
                                                    isLiked: viewModel.isLikedByCurrentUser(nestedReply),
                                                    indentLevel: 1,
                                                    nestedReplyCount: 0,
                                                    isExpanded: false,
                                                    onLike: {
                                                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                                        impactFeedback.impactOccurred()
                                                        
                                                        Task {
                                                            await viewModel.toggleLike(for: nestedReply)
                                                        }
                                                    },
                                                    onReply: {
                                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                                        impactFeedback.impactOccurred()
                                                        
                                                        viewModel.replyToReply(nestedReply)
                                                    },
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
                                                
                                                if nestedIndex < threadedReply.nestedReplies.count - 1 {
                                                    Divider()
                                                        .padding(.horizontal, 12)
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
                                                .padding(.top, 12)
                                                
                                                Spacer()
                                            }
                                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                                        }
                                    }
                                }
                                
                                // Divider after each top-level reply
                                if index < viewModel.threadedReplies.count - 1 {
                                    Divider()
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
                .padding(.horizontal, 18) // Apply consistent horizontal padding to entire VStack
            }
            .background(Color(.systemBackground))
            .navigationTitle("Reply")
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

