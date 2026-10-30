import SwiftUI

struct LoopDetailView: View {
    @State private var viewModel: LoopDetailViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var profileUserToShow: ProfileUser?
    /// Measured reply card heights, read only by the conversation lines.
    @State private var replyHeights = ReplyHeightStore()
    
    // Debug overlay
    @AppStorage("showLayoutDebugOverlays") private var showDebugOverlay = false
    
    init(loop: Loop, onRepliesChanged: (() -> Void)? = nil) {
        _viewModel = State(initialValue: LoopDetailViewModel(loop: loop, onRepliesChanged: onRepliesChanged))
    }
    
    // MARK: - View Components
    
    private var mainPostView: some View {
        PostCard(
                        loop: viewModel.loop,
                        isLiked: viewModel.isLikedByCurrentUser(viewModel.loop),
                        onLike: {
                            Task {
                                await viewModel.toggleLike(for: viewModel.loop)
                            }
                        },
                        onComment: {
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
    }
    
    private var commentsHeaderView: some View {
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
    }
    
    @ViewBuilder
    private var repliesContentView: some View {
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
            commentsHeaderView
            
            // Replies list - threaded structure with collapsible nested replies
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.threadedReplies.enumerated()), id: \.element.id) { index, threadedReply in
                    threadView(threadedReply, index: index)

                    // Divider after each top-level reply
                    if index < viewModel.threadedReplies.count - 1 {
                        PostDivider()
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Reply Threads

    /// A top-level reply, its nested replies when expanded, and the conversation lines joining them.
    private func threadView(_ threadedReply: ThreadedReply, index: Int) -> some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Top-level reply
                topLevelReplyCard(threadedReply)

                // Show nested replies if expanded
                if threadedReply.isExpanded {
                    ForEach(Array(threadedReply.nestedReplies.enumerated()), id: \.element.id) { nestedIndex, nestedReply in
                        VStack(spacing: 0) {
                            nestedReplyCard(nestedReply, at: nestedIndex, in: threadedReply)
                                // 12pt spacing before each nested reply (matches contentToActionsSpacing)
                                .padding(.top, CardLayoutConstants.contentToActionsSpacing)
                        }
                    }

                    hideRepliesButton(for: threadedReply)
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
            .padding(.top, index == 0 ? 0 : 5)
            .padding(.bottom, index == viewModel.threadedReplies.count - 1 ? 0 : 5)

            // Connecting lines overlay - separate lines between each consecutive pair (O-O pattern)
            if threadedReply.isExpanded && !threadedReply.nestedReplies.isEmpty {
                ConversationLinesView(
                    threadedReply: threadedReply,
                    replyHeights: replyHeights,
                    parentIndex: index
                )
            }
        }
    }

    private func topLevelReplyCard(_ threadedReply: ThreadedReply) -> some View {
        ReplyCardView(
            reply: threadedReply.reply,
            isLiked: viewModel.isLikedByCurrentUser(threadedReply.reply),
            indentLevel: 0,
            nestedReplyCount: threadedReply.nestedReplies.count,
            isExpanded: threadedReply.isExpanded,
            isLastInThread: false,
            onLike: {
                Task {
                    await viewModel.toggleLike(for: threadedReply.reply)
                }
            },
            onReply: {
                viewModel.replyToReply(threadedReply.reply)
            },
            onToggleExpanded: threadedReply.nestedReplies.isEmpty ? nil : {
                withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
                    viewModel.toggleReplyExpansion(threadedReply.id)
                }
            },
            onDelete: viewModel.canDeleteLoop(threadedReply.reply) ? {
                Task {
                    await viewModel.deleteLoop(threadedReply.reply)
                }
            } : nil,
            onAvatarTap: {
                profileUserToShow = ProfileUser(userId: threadedReply.reply.authorId)
            },
            applyInternalPadding: false
        )
        .overlay(heightReader(for: threadedReply.reply.id))
    }

    private func nestedReplyCard(_ nestedReply: Loop, at nestedIndex: Int, in threadedReply: ThreadedReply) -> some View {
        let isLast = nestedIndex == threadedReply.nestedReplies.count - 1

        return ReplyCardView(
            reply: nestedReply,
            isLiked: viewModel.isLikedByCurrentUser(nestedReply),
            indentLevel: 1,
            nestedReplyCount: 0,
            isExpanded: false,
            isLastInThread: isLast,
            onLike: {
                Task {
                    await viewModel.toggleLike(for: nestedReply)
                }
            },
            onReply: isLast ? {
                viewModel.replyToReply(threadedReply.reply)
            } : nil,
            onToggleExpanded: nil,
            onDelete: viewModel.canDeleteLoop(nestedReply) ? {
                Task {
                    await viewModel.deleteLoop(nestedReply)
                }
            } : nil,
            onAvatarTap: {
                profileUserToShow = ProfileUser(userId: nestedReply.authorId)
            },
            applyInternalPadding: false
        )
        .overlay(heightReader(for: nestedReply.id))
    }

    /// Records the height of the card it overlays, for the conversation lines.
    private func heightReader(for replyId: String) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    replyHeights.record(geo.size.height, for: replyId)
                }
                .onChange(of: geo.size.height) { _, newHeight in
                    replyHeights.record(newHeight, for: replyId)
                }
        }
    }

    /// "Hide replies" button at the bottom of an expanded thread, in a container matching the action buttons.
    private func hideRepliesButton(for threadedReply: ThreadedReply) -> some View {
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
        .background(showDebugOverlay ? Color.orange.opacity(0.1) : Color.clear)
        .overlay(
            Group {
                if showDebugOverlay {
                    Rectangle()
                        .stroke(Color.red, lineWidth: 1)
                }
            }
        )
        .padding(.top, CardLayoutConstants.contentToActionsSpacing)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    mainPostView
                    
                    // Divider above replies section
                    PostDivider()
                        .padding(.top, 5)
                    
                    repliesContentView
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
                await viewModel.refresh()
            }
        }
        .sheet(isPresented: $viewModel.showingCompose) {
            ComposeLoopView(
                draft: $viewModel.composeDraft,
                isPresented: $viewModel.showingCompose,
                onPost: {
                    try await viewModel.postReply()
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
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .task {
            viewModel.start()
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearError()
                }
            }
        )
    }
}

// MARK: - Reply Heights

/// Reply card heights by reply ID, measured as the cards lay out. A reference type so that writing a height
/// only invalidates the views that read heights, not the detail view that owns the store.
@Observable
final class ReplyHeightStore {
    private(set) var heights: [String: CGFloat] = [:]

    func record(_ height: CGFloat, for replyId: String) {
        // Skipped when unchanged, so a card appearing again doesn't redraw the lines
        guard heights[replyId] != height else { return }
        heights[replyId] = height
    }
}

// MARK: - Conversation Lines Component
struct ConversationLinesView: View {
    let threadedReply: ThreadedReply
    let replyHeights: ReplyHeightStore
    let parentIndex: Int
    @AppStorage("showLayoutDebugOverlays") private var showDebugOverlay = false
    
    var body: some View {
        let lineWidth = CardLayoutConstants.conversationLineWidth
        let lineX = CardLayoutConstants.horizontalPadding + CardLayoutConstants.avatarSize / 2 - lineWidth / 2
        
        // Draw individual lines between each consecutive pair
        ForEach(Array(lineSegments.enumerated()), id: \.offset) { _, segment in
            RoundedRectangle(cornerRadius: lineWidth / 2)
                .fill(CardLayoutConstants.conversationLineColor)
                .frame(width: lineWidth, height: segment.height)
                .offset(x: lineX, y: segment.startY)
                .background(
                    Group {
                        if showDebugOverlay {
                            Rectangle()
                                .fill(Color.blue.opacity(0.3))
                                .frame(width: lineWidth, height: segment.height)
                                .offset(x: lineX, y: segment.startY)
                        }
                    }
                )
                .allowsHitTesting(false)
        }
    }
    
    private var lineSegments: [LineSegment] {
        var segments: [LineSegment] = []
        let externalTopPadding: CGFloat = parentIndex == 0 ? 0 : 5
        
        let heights = replyHeights.heights
        guard let parentHeight = heights[threadedReply.reply.id] else { return segments }
        
        // Line from parent to first nested reply
        if !threadedReply.nestedReplies.isEmpty {
            let parentAvatarBottom = externalTopPadding + CardLayoutConstants.topPadding + CardLayoutConstants.avatarSize
            let lineStart = parentAvatarBottom + CardLayoutConstants.avatarLineGap
            
            let firstNestedTop = externalTopPadding + parentHeight + CardLayoutConstants.contentToActionsSpacing + CardLayoutConstants.topPadding
            let lineEnd = firstNestedTop - CardLayoutConstants.avatarLineGap
            
            let height = max(0, lineEnd - lineStart)
            if height > 0 {
                segments.append(LineSegment(startY: lineStart, height: height))
            }
        }
        
        // Lines between consecutive nested replies (no dividers, just 12pt spacing)
        var cumulativeHeight = externalTopPadding + parentHeight + CardLayoutConstants.contentToActionsSpacing
        
        for i in 0..<threadedReply.nestedReplies.count {
            if i > 0 {
                // Previous nested reply
                let prevReply = threadedReply.nestedReplies[i - 1]
                let currentReply = threadedReply.nestedReplies[i]
                
                if let prevHeight = heights[prevReply.id], let _ = heights[currentReply.id] {
                    // Previous avatar bottom + gap
                    let prevAvatarBottom = cumulativeHeight + CardLayoutConstants.topPadding + CardLayoutConstants.avatarSize
                    let lineStart = prevAvatarBottom + CardLayoutConstants.avatarLineGap
                    
                    // Add previous reply height AND the 12pt spacing we added between nested replies
                    cumulativeHeight += prevHeight + CardLayoutConstants.contentToActionsSpacing
                    
                    // Current avatar top - gap
                    let currentAvatarTop = cumulativeHeight + CardLayoutConstants.topPadding
                    let lineEnd = currentAvatarTop - CardLayoutConstants.avatarLineGap
                    
                    let height = max(0, lineEnd - lineStart)
                    if height > 0 {
                        segments.append(LineSegment(startY: lineStart, height: height))
                    }
                }
            }
        }
        
        return segments
    }
    
    struct LineSegment {
        let startY: CGFloat
        let height: CGFloat
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

