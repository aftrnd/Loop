import SwiftUI

/// Composite component: Complete post card
/// Assembles atomic components (PostHeader + PostContent + PostActions) into a cohesive card
/// Handles both regular posts and posts with reply previews
struct PostCard: View {
    // MARK: - Properties
    let loop: Loop
    let isLiked: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onShare: (() -> Void)?
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    
    // Reply preview support (optional - defaults to nil for regular posts)
    let replyPreviews: [Loop]?
    let onReplyPreviewTap: (() -> Void)?
    
    // Debug overlays
    let showDebugOverlays: Bool
    
    // Initializer with default values for reply parameters
    init(
        loop: Loop,
        isLiked: Bool,
        onLike: @escaping () -> Void,
        onComment: @escaping () -> Void,
        onShare: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onAvatarTap: (() -> Void)? = nil,
        replyPreviews: [Loop]? = nil,
        onReplyPreviewTap: (() -> Void)? = nil,
        showDebugOverlays: Bool = false
    ) {
        self.loop = loop
        self.isLiked = isLiked
        self.onLike = onLike
        self.onComment = onComment
        self.onShare = onShare
        self.onDelete = onDelete
        self.onAvatarTap = onAvatarTap
        self.replyPreviews = replyPreviews
        self.onReplyPreviewTap = onReplyPreviewTap
        self.showDebugOverlays = showDebugOverlays
    }
    
    // State for conversation line
    @State private var mainPostHeight: CGFloat = 0
    
    // Content shifts when there are reply previews
    private var shouldShiftContent: Bool {
        guard let previews = replyPreviews else { return false }
        return !previews.isEmpty
    }
    
    private let maxReplyPreviews = 1
    
    // MARK: - Body
    var body: some View {
        if let replyPreviews = replyPreviews, !replyPreviews.isEmpty {
            // Post with reply preview
            postWithReplyView(replyPreviews: replyPreviews)
        } else {
            // Regular post
            regularPostView
        }
    }
    
    // MARK: - Regular Post (No Replies)
    
    private var regularPostView: some View {
        VStack(spacing: 0) {
            PostHeader(
                avatarURL: loop.authorAvatarURL,
                displayName: loop.displayAuthorName,
                username: loop.authorUsername,
                badgeType: loop.authorBadgeType,
                timestamp: loop.timeAgoString,
                onAvatarTap: onAvatarTap,
                showDebugOverlay: showDebugOverlays
            )
            .padding(.bottom, CardLayoutConstants.headerBottomSpacing)
            .background(showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear) // Debug: Bottom padding
            
            PostContent(
                text: loop.content,
                media: loop.media,
                showDebugOverlay: showDebugOverlays
            )
            .padding(.bottom, CardLayoutConstants.contentToActionsSpacing)
            .background(showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear) // Debug: Bottom padding
            
            PostActions(
                isLiked: isLiked,
                likeCount: loop.likeCount,
                onLike: onLike,
                commentCount: loop.replyCount,
                onComment: onComment,
                onShare: onShare,
                onDelete: onDelete,
                showDebugOverlay: showDebugOverlays
            )
        }
        .padding(.horizontal, CardLayoutConstants.horizontalPadding)
        .background(showDebugOverlays ? Color.yellow.opacity(0.05) : Color.clear) // Debug: Horizontal padding
        .padding(.top, CardLayoutConstants.topPadding)
        .background(showDebugOverlays ? Color.pink.opacity(0.05) : Color.clear) // Debug: Top padding
        .padding(.bottom, CardLayoutConstants.bottomPadding)
        .background(showDebugOverlays ? Color.cyan.opacity(0.05) : Color.clear) // Debug: Bottom padding
        .background(Color(.systemBackground))
        .overlay(
            Group {
                if showDebugOverlays {
                    RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius)
                        .stroke(Color.red, lineWidth: 2)
                }
            }
        )
    }
    
    // MARK: - Post with Reply Preview
    
    private func postWithReplyView(replyPreviews: [Loop]) -> some View {
        let previewReplies = Array(replyPreviews.prefix(maxReplyPreviews))
        
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Main post with content shift
                mainPostWithShift
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    mainPostHeight = geo.size.height
                                }
                                .onChange(of: geo.size.height) { _, newHeight in
                                    mainPostHeight = newHeight
                                }
                        }
                    )
                
                // Spacing before reply (same as content to actions spacing: 12pt)
                (showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear) // Debug: Reply spacing
                    .frame(height: CardLayoutConstants.contentToActionsSpacing)
                
                // Reply previews
                ForEach(previewReplies) { reply in
                    replyPreviewView(reply: reply)
                }
            }
            .padding(.horizontal, CardLayoutConstants.horizontalPadding)
            .background(showDebugOverlays ? Color.yellow.opacity(0.05) : Color.clear) // Debug: Horizontal padding
            .padding(.top, CardLayoutConstants.topPadding)
            .background(showDebugOverlays ? Color.pink.opacity(0.05) : Color.clear) // Debug: Top padding
            .padding(.bottom, CardLayoutConstants.bottomPadding)
            .background(showDebugOverlays ? Color.cyan.opacity(0.05) : Color.clear) // Debug: Bottom padding
            
            // Conversation line
            if !previewReplies.isEmpty {
                conversationLine
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius))
        .overlay(
            Group {
                if showDebugOverlays {
                    RoundedRectangle(cornerRadius: CardLayoutConstants.cornerRadius)
                        .stroke(Color.red, lineWidth: 2)
                }
            }
        )
    }
    
    private var mainPostWithShift: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - uses HStack internally with avatar + spacing + name
            PostHeader(
                avatarURL: loop.authorAvatarURL,
                displayName: loop.displayAuthorName,
                username: loop.authorUsername,
                badgeType: loop.authorBadgeType,
                timestamp: loop.timeAgoString,
                onAvatarTap: onAvatarTap,
                showDebugOverlay: showDebugOverlays
            )
            .padding(.bottom, CardLayoutConstants.headerBottomSpacing)
            .background(showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear) // Debug: Bottom padding
            
            // Content - shifts to align with name (avatar + spacing from header's left edge)
            HStack(spacing: 0) {
                // Spacer matching avatar + spacing to align with name
                (showDebugOverlays ? Color.red.opacity(0.2) : Color.clear) // Debug: Spacer for alignment
                    .frame(width: CardLayoutConstants.avatarSize + CardLayoutConstants.avatarSpacing)
                
                PostContent(
                    text: loop.content,
                    media: loop.media,
                    showDebugOverlay: showDebugOverlays
                )
            }
            .padding(.bottom, CardLayoutConstants.contentToActionsSpacing)
            .background(showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear) // Debug: Bottom padding
            
            // Actions - shifts to align with name (avatar + spacing from header's left edge)
            HStack(spacing: 0) {
                // Spacer matching avatar + spacing to align with name
                (showDebugOverlays ? Color.red.opacity(0.2) : Color.clear) // Debug: Spacer for alignment
                    .frame(width: CardLayoutConstants.avatarSize + CardLayoutConstants.avatarSpacing)
                
                PostActions(
                    isLiked: isLiked,
                    likeCount: loop.likeCount,
                    onLike: onLike,
                    commentCount: loop.replyCount,
                    onComment: onComment,
                    onShare: onShare,
                    onDelete: onDelete,
                    showDebugOverlay: showDebugOverlays
                )
            }
        }
        // NO padding here - padding is applied to the whole card in postWithReplyView
    }
    
    private func replyPreviewView(reply: Loop) -> some View {
        Button(action: {
            onReplyPreviewTap?()
        }) {
            VStack(spacing: 0) {
                PostHeader(
                    avatarURL: reply.authorAvatarURL,
                    displayName: reply.displayAuthorName,
                    username: reply.authorUsername,
                    badgeType: reply.authorBadgeType,
                    timestamp: reply.timeAgoString,
                    onAvatarTap: onReplyPreviewTap,
                    showDebugOverlay: showDebugOverlays
                )
                
                if !reply.content.isEmpty {
                    (showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear) // Debug: Spacing
                        .frame(height: CardLayoutConstants.headerBottomSpacing)
                    
                    HStack {
                        Text(reply.content)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .truncationMode(.tail)
                        Spacer()
                    }
                    .overlay(
                        Group {
                            if showDebugOverlays {
                                Rectangle()
                                    .stroke(Color.red, lineWidth: 1)
                            }
                        }
                    )
                }
            }
            // NO padding here - padding is applied to the whole card
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var conversationLine: some View {
        if mainPostHeight > 0 {
            let lineWidth = CardLayoutConstants.conversationLineWidth
            
            // Main avatar position (from card's top edge)
            let mainAvatarTop = CardLayoutConstants.topPadding
            let mainAvatarBottom = mainAvatarTop + CardLayoutConstants.avatarSize
            
            // Line starts 10pt below main avatar
            let lineStart = mainAvatarBottom + CardLayoutConstants.avatarLineGap
            
            // Reply position calculation:
            // mainPostHeight (measured height of main post content)
            // + contentToActionsSpacing (12pt spacing)
            // + topPadding (card padding before reply header starts)
            let replyHeaderTop = mainPostHeight + CardLayoutConstants.contentToActionsSpacing + CardLayoutConstants.topPadding
            let replyAvatarTop = replyHeaderTop // Avatar is at top of header
            
            // Line ends 10pt above reply avatar
            let lineEnd = replyAvatarTop - CardLayoutConstants.avatarLineGap
            
            // Line height
            let lineHeight = max(0, lineEnd - lineStart)
            
            // Horizontal position: centered on avatar
            let avatarCenter = CardLayoutConstants.avatarSize / 2
            let lineX = CardLayoutConstants.horizontalPadding + avatarCenter - (lineWidth / 2)
            
            if showDebugOverlays {
                Color.cyan.opacity(0.3) // Debug: Show full line area
                    .frame(height: lineHeight)
                    .offset(y: lineStart)
            }
            
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: lineStart)
                    
                    RoundedRectangle(cornerRadius: lineWidth / 2)
                        .fill(CardLayoutConstants.conversationLineColor)
                        .frame(width: lineWidth, height: lineHeight)
                    
                    Spacer()
                }
                .frame(width: lineWidth)
                .offset(x: lineX)
                
                Spacer()
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Text only post
            PostCard(
                loop: Loop(
                    authorId: "user1",
                    content: "Just shipped a new feature! Really excited to see how users respond. 🚀",
                    authorDisplayName: "John Doe",
                    authorUsername: "johndoe",
                    authorBadgeType: .verified
                ),
                isLiked: false,
                onLike: {},
                onComment: {},
                onShare: {},
                onDelete: {},
                onAvatarTap: {}
            )
            .padding(.horizontal)
            
            // Post with image
            PostCard(
                loop: Loop(
                    authorId: "user2",
                    content: "Beautiful sunset today 🌅",
                    media: [
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/400/300",
                            width: 400,
                            height: 300
                        )
                    ],
                    authorDisplayName: "Jane Smith",
                    authorUsername: "janesmith",
                    authorBadgeType: .premium
                ),
                isLiked: true,
                onLike: {},
                onComment: {},
                onShare: nil,
                onDelete: nil,
                onAvatarTap: nil
            )
            .padding(.horizontal)
            
            // Post with multiple images
            PostCard(
                loop: Loop(
                    authorId: "user3",
                    content: "Check out these amazing photos from my trip!",
                    media: [
                        LoopMedia(type: .image, url: "https://picsum.photos/400/400", width: 400, height: 400),
                        LoopMedia(type: .image, url: "https://picsum.photos/500/300", width: 500, height: 300)
                    ],
                    authorDisplayName: "Mike Johnson",
                    authorUsername: "mikej",
                    authorBadgeType: nil
                ),
                isLiked: false,
                onLike: {},
                onComment: {},
                onShare: {},
                onDelete: nil,
                onAvatarTap: nil
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}

