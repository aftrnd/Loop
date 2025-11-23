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
    let onReplyDelete: ((Loop) -> Void)? // Delete individual replies
    let isReplyLiked: ((Loop) -> Bool)? // Check if reply is liked by current user
    
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
        onReplyDelete: ((Loop) -> Void)? = nil,
        isReplyLiked: ((Loop) -> Bool)? = nil,
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
        self.onReplyDelete = onReplyDelete
        self.isReplyLiked = isReplyLiked
        self.showDebugOverlays = showDebugOverlays
    }
    
    // State for conversation line
    @State private var mainPostHeight: CGFloat = 0
    
    // Entrance animation state
    @State private var entranceOpacity: Double = 0
    @State private var conversationLineOpacity: Double = 0
    
    // Animated shift state - controls the actual padding value
    @State private var contentShiftAmount: CGFloat = 0
    
    // Content shifts when there are reply previews
    private var shouldShiftContent: Bool {
        guard let previews = replyPreviews else { return false }
        return !previews.isEmpty
    }
    
    private let maxReplyPreviews = 1
    
    // MARK: - Body
    var body: some View {
        let previewReplies = replyPreviews?.prefix(maxReplyPreviews).map { $0 } ?? []
        let hasReplies = !previewReplies.isEmpty
        
        // Use same view structure for both cases to enable smooth animation
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                // Main post content with animated shift
                mainPostContent
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
                
                // Reply preview (only visible when there are replies)
                if hasReplies {
                    // Spacing before reply
                    (showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear)
                        .frame(height: CardLayoutConstants.contentToActionsSpacing)
                    
                    ForEach(previewReplies) { reply in
                        replyPreviewView(reply: reply)
                    }
                }
            }
            .padding(.horizontal, CardLayoutConstants.horizontalPadding)
            .background(showDebugOverlays ? Color.yellow.opacity(0.05) : Color.clear)
            .padding(.top, CardLayoutConstants.topPadding)
            .background(showDebugOverlays ? Color.pink.opacity(0.05) : Color.clear)
            .padding(.bottom, CardLayoutConstants.bottomPadding)
            .background(showDebugOverlays ? Color.cyan.opacity(0.05) : Color.clear)
            
            // Conversation line (only visible when there are replies)
            if hasReplies {
                conversationLine
                    .opacity(conversationLineOpacity)
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
    
    // MARK: - Main Post Content (unified for all cases)
    
    private var mainPostContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header - always stays in same position
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
            .background(showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear)
            
            // Content - animates shift when replies appear
            PostContent(
                text: loop.content,
                media: loop.media,
                showDebugOverlay: showDebugOverlays
            )
            .opacity(entranceOpacity)
            .padding(.bottom, CardLayoutConstants.contentToActionsSpacing)
            .background(showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear)
            .padding(.leading, contentShiftAmount)
            
            // Actions - animates shift when replies appear
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
            .opacity(entranceOpacity)
            .padding(.leading, contentShiftAmount)
        }
        .onAppear {
            // Set initial shift state if replies already present
            if shouldShiftContent {
                contentShiftAmount = CardLayoutConstants.contentShift
            }
            
            // Entrance animation (fade in content and conversation line)
            withAnimation(.spring(response: CardLayoutConstants.contentShiftAnimationResponse, dampingFraction: CardLayoutConstants.contentShiftAnimationDamping)) {
                entranceOpacity = 1
                conversationLineOpacity = 1
            }
        }
        .onChange(of: shouldShiftContent) { _, newValue in
            // Animate shift and line visibility when replies appear/disappear
            withAnimation(.spring(response: CardLayoutConstants.contentShiftAnimationResponse, dampingFraction: CardLayoutConstants.contentShiftAnimationDamping)) {
                contentShiftAmount = newValue ? CardLayoutConstants.contentShift : 0
                conversationLineOpacity = newValue ? 1 : 0
            }
        }
    }
    
    private func replyPreviewView(reply: Loop) -> some View {
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
            .padding(.bottom, CardLayoutConstants.headerBottomSpacing)
            .background(showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear) // Debug: Bottom padding
            
            // Content - use PostContent component for consistent styling
            PostContent(
                text: reply.content,
                media: reply.media,
                maxPreviewLength: 280,
                showDebugOverlay: showDebugOverlays
            )
            .opacity(entranceOpacity)
            .padding(.bottom, CardLayoutConstants.contentToActionsSpacing)
            .background(showDebugOverlays ? Color.purple.opacity(0.05) : Color.clear) // Debug: Bottom padding
            
            // Actions - same as main posts, show delete menu if deletable
            PostActions(
                isLiked: isReplyLiked?(reply) ?? false,
                likeCount: reply.likeCount,
                onLike: {
                    // Tap anywhere on reply preview to view full thread
                    onReplyPreviewTap?()
                },
                commentCount: reply.replyCount,
                onComment: {
                    onReplyPreviewTap?()
                },
                onShare: nil,
                onDelete: self.onReplyDelete != nil ? {
                    self.onReplyDelete?(reply)
                } : nil,
                isReplyPreview: true, // Show arrow icon for reply previews
                showDebugOverlay: showDebugOverlays
            )
            .opacity(entranceOpacity)
        }
        // NO padding here - padding is applied to the whole card
    }
    
    @ViewBuilder
    private var conversationLine: some View {
        if mainPostHeight > 0 {
            let lineWidth = CardLayoutConstants.conversationLineWidth
            
            // Main avatar position (from card's top edge)
            let mainAvatarTop = CardLayoutConstants.topPadding
            let mainAvatarBottom = mainAvatarTop + CardLayoutConstants.avatarSize
            
            // Line starts 12pt below main avatar
            let lineStart = mainAvatarBottom + CardLayoutConstants.avatarLineGap
            
            // Reply position calculation:
            // mainPostHeight (measured height of main post content)
            // + contentToActionsSpacing (12pt spacing)
            // + topPadding (card padding before reply header starts)
            let replyHeaderTop = mainPostHeight + CardLayoutConstants.contentToActionsSpacing + CardLayoutConstants.topPadding
            let replyAvatarTop = replyHeaderTop // Avatar is at top of header
            
            // Line ends 12pt above reply avatar
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

