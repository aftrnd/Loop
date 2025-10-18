import SwiftUI

// MARK: - View Extensions
extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Debug helper to log frame coordinates
    func debugFrame(_ label: String, enabled: Bool = false) -> some View {
        self.overlay(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        if enabled {
                            let frame = geometry.frame(in: .global)
                            print("📐 \(label): x=\(frame.minX), y=\(frame.minY), width=\(frame.width), height=\(frame.height)")
                        }
                    }
            }
        )
    }
}

// MARK: - Shared Layout Constants
/// Single source of truth for ALL card layout values - ensures pixel-perfect alignment
enum CardLayoutConstants {
    // MARK: - Card Structure
    /// Spacing from screen edges - IMMUTABLE, used everywhere
    static let horizontalPadding: CGFloat = 10
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 8
    static let cornerRadius: CGFloat = 16
    
    // MARK: - Avatar
    static let avatarSize: CGFloat = 56
    /// Space between avatar and text - MUST equal TOTAL left spacing for perfect symmetry
    /// Left side: screen edge → list inset (10pt) → card padding (10pt) → avatar = 20pt total
    /// Right side: avatar → 20pt → name/content (to match left side)
    static let avatarSpacing: CGFloat = horizontalPadding * 2 // 20pt - matches total left spacing
    
    // MARK: - Content Spacing
    /// IMMUTABLE spacing values - consistent across all post types
    /// The pattern: Header -> 12pt -> Content (text/media) -> 12pt -> Actions
    static let headerBottomSpacing: CGFloat = 12 // Space between header and content
    static let contentSpacing: CGFloat = 12 // Space between content elements (text -> media)
    static let contentToActionsSpacing: CGFloat = 12 // Space between any content and action buttons
    
    // MARK: - Action Buttons
    static let actionButtonHeight: CGFloat = 31 // Standard hit target height
    static let actionButtonIconSize: CGFloat = 18
    static let actionButtonSpacing: CGFloat = 0 // No spacing between button frames (they have internal spacing)
    static let actionButtonWidth: CGFloat = 50 // Standard width for each action button (with counts)
    
    // MARK: - Dividers & Lines
    static let dividerHeight: CGFloat = 1.15
    static let dividerColor: Color = Color(.separator)
    static let conversationLineWidth: CGFloat = 2.5
    static let conversationLineColor: Color = Color(.separator)
    static let avatarLineGap: CGFloat = 12 // Gap between avatar edge and conversation line
    
    // MARK: - Media
    static let mediaCornerRadius: CGFloat = 12
    static let photoCarouselSpacing: CGFloat = 10 // Spacing between photos in multi-photo carousels
    
    // MARK: - Computed Values (DO NOT MODIFY - Derived from base values)
    /// Total shift for content when aligning with name
    /// This ensures content aligns perfectly: screenEdge(10) + cardPadding(10) + avatar(56) + spacing(20) = 96pt from screen edge
    static let contentShift: CGFloat = avatarSize + avatarSpacing // 56 + 20 = 76
    
    // MARK: - Animations
    static let contentShiftAnimationResponse: CGFloat = 0.3
    static let contentShiftAnimationDamping: CGFloat = 0.8
}

struct ReplyCardView: View {
    let reply: Loop
    let isLiked: Bool
    let indentLevel: Int // 0 = top-level reply, 1+ = nested
    let nestedReplyCount: Int // Number of nested replies
    let isExpanded: Bool // Whether nested replies are shown
    let isLastInThread: Bool // Whether this is the last reply in a nested thread
    let onLike: () -> Void
    let onReply: (() -> Void)? // Reply to this reply
    let onToggleExpanded: (() -> Void)? // Toggle nested replies visibility
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    var showAsMainPost: Bool = false // Show comment/share buttons instead of reply button
    var applyInternalPadding: Bool = true // Whether to apply internal padding (false when in thread container)
    
    @State private var showingFullText = false
    @State private var showPhotoViewer = false
    @State private var selectedPhotoIndex: Int = 0
    @State private var currentMediaIndex: Int = 0
    
    // Debug overlay
    @AppStorage("showLayoutDebugOverlays") private var showDebugOverlay = false
    
    private let maxPreviewLength = 280
    
    // Determines if content should shift right (to align with name instead of avatar)
    private var shouldShiftContent: Bool {
        // Shift content for:
        // 1. Top-level replies that are expanded with nested replies
        // 2. Nested replies that are NOT the last one (so line can continue down)
        return (indentLevel == 0 && isExpanded && nestedReplyCount > 0) ||
               (indentLevel == 1 && !isLastInThread)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                // Header row: Avatar + Name/Badge/Time - using PostHeader component for consistency
                PostHeader(
                    avatarURL: reply.authorAvatarURL,
                    displayName: reply.displayAuthorName,
                    username: reply.authorUsername,
                    badgeType: reply.authorBadgeType,
                    timestamp: reply.timeAgoString,
                    onAvatarTap: onAvatarTap,
                    showDebugOverlay: showDebugOverlay
                )
                .padding(.bottom, CardLayoutConstants.headerBottomSpacing)
                .debugFrame("ReplyCard-HeaderContainer", enabled: showDebugOverlay)
                
                // Content - separated containers for text and media
                // Pattern: Text container → 12pt → Media container, then 12pt → Actions
                VStack(alignment: .leading, spacing: CardLayoutConstants.contentSpacing) {
                    // Text content - own container with debug outline, shifts right when needed
                    if !reply.content.isEmpty {
                        contentView
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(showDebugOverlay ? Color.green.opacity(0.1) : Color.clear)
                            .overlay(
                                Group {
                                    if showDebugOverlay {
                                        Rectangle()
                                            .stroke(Color.red, lineWidth: 1)
                                    }
                                }
                            )
                            .padding(.leading, shouldShiftContent ? CardLayoutConstants.contentShift : 0)
                            .animation(.spring(response: CardLayoutConstants.contentShiftAnimationResponse, dampingFraction: CardLayoutConstants.contentShiftAnimationDamping), value: shouldShiftContent)
                    }
                    
                    // Media content - own container with debug outline, shifts right when needed
                    if reply.hasMedia {
                        mediaView
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(showDebugOverlay ? Color.green.opacity(0.1) : Color.clear)
                            .overlay(
                                Group {
                                    if showDebugOverlay {
                                        Rectangle()
                                            .stroke(Color.red, lineWidth: 1)
                                    }
                                }
                            )
                            .padding(.leading, shouldShiftContent ? CardLayoutConstants.contentShift : 0)
                            .animation(.spring(response: CardLayoutConstants.contentShiftAnimationResponse, dampingFraction: CardLayoutConstants.contentShiftAnimationDamping), value: shouldShiftContent)
                    }
                }
                .padding(.bottom, CardLayoutConstants.contentToActionsSpacing)
                
                // Action buttons - using reusable PostActions component
                PostActions(
                    isLiked: isLiked,
                    likeCount: reply.likeCount,
                    onLike: onLike,
                    commentCount: reply.replyCount,
                    onComment: onReply,
                    onShare: showAsMainPost ? {} : nil,
                    onDelete: onDelete,
                    isReplyPreview: !showAsMainPost,
                    showDebugOverlay: showDebugOverlay
                )
                .padding(.leading, shouldShiftContent ? CardLayoutConstants.contentShift : 0)
                .animation(.spring(response: CardLayoutConstants.contentShiftAnimationResponse, dampingFraction: CardLayoutConstants.contentShiftAnimationDamping), value: shouldShiftContent)
                .debugFrame("ReplyCard-ActionButtons", enabled: showDebugOverlay)
                
                // Show/Hide nested replies button - in container matching action buttons
                if indentLevel == 0 && nestedReplyCount > 0, let onToggleExpanded = onToggleExpanded, !isExpanded {
                    HStack(spacing: 0) {
                        Button(action: onToggleExpanded) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                Text("View \(nestedReplyCount) \(nestedReplyCount == 1 ? "reply" : "replies")")
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
                    .padding(.leading, shouldShiftContent ? CardLayoutConstants.contentShift : 0)
                    .animation(.spring(response: CardLayoutConstants.contentShiftAnimationResponse, dampingFraction: CardLayoutConstants.contentShiftAnimationDamping), value: shouldShiftContent)
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
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .if(applyInternalPadding) { view in
                view
                    .padding(.leading, CardLayoutConstants.horizontalPadding)
                    .padding(.trailing, CardLayoutConstants.horizontalPadding)
                    .padding(.top, CardLayoutConstants.topPadding)
                    .padding(.bottom, CardLayoutConstants.bottomPadding)
            }
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            FullScreenPhotoViewer(
                allMedia: reply.media,
                startingIndex: selectedPhotoIndex,
                isPresented: $showPhotoViewer
            )
            .presentationBackground(.clear)
        }
    }
    
    // MARK: - Reusable Components
    private var contentView: some View {
        Group {
            if !reply.content.isEmpty {
                let shouldTruncate = reply.content.count > maxPreviewLength && !showingFullText
                let displayText = shouldTruncate ? String(reply.content.prefix(maxPreviewLength)) + "..." : reply.content
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    if shouldTruncate {
                        Button("Show more") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingFullText = true
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    } else if reply.content.count > maxPreviewLength && showingFullText {
                        Button("Show less") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingFullText = false
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(.accentColor)
                    }
                }
            }
        }
    }
    
    private var mediaView: some View {
        Group {
            if reply.media.count == 1, let firstMedia = reply.media.first {
                // Single image - tappable
                SingleReplyMediaView(
                    media: firstMedia,
                    onPhotoTap: {
                        selectedPhotoIndex = 0
                        showPhotoViewer = true
                    },
                    showDebugOverlay: showDebugOverlay
                )
            } else if reply.media.count > 1 {
                // Multiple images - swipeable carousel
                MultipleReplyMediaView(
                    media: reply.media,
                    currentIndex: $currentMediaIndex,
                    onPhotoTap: { index in
                        selectedPhotoIndex = index
                        showPhotoViewer = true
                    },
                    showDebugOverlay: showDebugOverlay
                )
            }
        }
    }
    
}

// MARK: - Helper Views for Reply Media

struct SingleReplyMediaView: View {
    let media: LoopMedia
    let onPhotoTap: () -> Void
    var showDebugOverlay: Bool = false
    
    var body: some View {
        if let width = media.width, let height = media.height, height > 0 {
            let aspectRatio = CGFloat(width) / CGFloat(height)
            // Calculate proportional height like regular media views
            let baseWidth: CGFloat = 350
            let proportionalHeight = baseWidth / aspectRatio
            let minHeight: CGFloat = 150
            let maxHeight: CGFloat = 500
            
            // Photo height determines post height, always crop sides to fit width
            let mediaHeight: CGFloat = max(minHeight, min(maxHeight, proportionalHeight))
            
            GeometryReader { geometry in
                CachedAsyncImage(url: URL(string: media.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geometry.size.width, height: mediaHeight)
                        .clipped()
                } placeholder: {
                    RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius)
                        .fill(Color(.systemGray5))
                        .frame(width: geometry.size.width, height: mediaHeight)
                        .overlay(
                            ProgressView()
                                .scaleEffect(1.0)
                        )
                }
                .frame(width: geometry.size.width, height: mediaHeight)
                .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius))
                .overlay(
                    Group {
                        if showDebugOverlay {
                            RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius)
                                .stroke(Color.red, lineWidth: 1)
                        }
                    }
                )
            }
            .frame(height: mediaHeight)
            .onTapGesture {
                onPhotoTap()
            }
        }
    }
}

struct MultipleReplyMediaView: View {
    let media: [LoopMedia]
    @Binding var currentIndex: Int
    let onPhotoTap: (Int) -> Void
    var showDebugOverlay: Bool = false
    
    // Local state for scroll position (needs to be optional for ScrollView API)
    @State private var scrollPosition: Int?
    
    var carouselHeight: CGFloat {
        guard let firstMedia = media.first,
              let width = firstMedia.width,
              let height = firstMedia.height,
              height > 0 else { return 300 }
        
        let aspectRatio = CGFloat(width) / CGFloat(height)
        // Calculate proportional height like regular media views
        let baseWidth: CGFloat = 350
        let proportionalHeight = baseWidth / aspectRatio
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        
        // Photo height determines post height, always crop sides to fit width
        return max(minHeight, min(maxHeight, proportionalHeight))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let containerWidth = geometry.size.width
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: CardLayoutConstants.photoCarouselSpacing) {
                    ForEach(Array(media.enumerated()), id: \.offset) { index, mediaItem in
                        ReplyCarouselPhotoView(
                            media: mediaItem,
                            height: carouselHeight,
                            onPhotoTap: { onPhotoTap(index) },
                            showDebugOverlay: showDebugOverlay
                        )
                        .frame(width: containerWidth, height: carouselHeight)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $scrollPosition)
            .onChange(of: scrollPosition) { _, newValue in
                if let newValue = newValue {
                    currentIndex = newValue
                }
            }
        }
        .frame(height: carouselHeight)
        .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius))
        .overlay(
            Group {
                if showDebugOverlay {
                    RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius)
                        .stroke(Color.red, lineWidth: 1)
                }
            }
        )
        .overlay(alignment: .bottom) {
            // Page indicators inside photo container
            PageIndicator(currentPage: currentIndex, pageCount: media.count)
                .padding(.bottom, 8)
        }
    }
}

struct ReplyCarouselPhotoView: View {
    let media: LoopMedia
    let height: CGFloat
    let onPhotoTap: () -> Void
    var showDebugOverlay: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            CachedAsyncImage(url: URL(string: media.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: height)
                    .clipped()
            } placeholder: {
                RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius)
                    .fill(Color(.systemGray5))
                    .frame(width: geometry.size.width, height: height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.0)
                    )
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius))
        .overlay(
            Group {
                if showDebugOverlay {
                    RoundedRectangle(cornerRadius: CardLayoutConstants.mediaCornerRadius)
                        .stroke(Color.red, lineWidth: 1)
                }
            }
        )
        .onTapGesture {
            onPhotoTap()
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            // Sample top-level reply with nested replies
            ReplyCardView(
                reply: Loop(
                    authorId: "user1",
                    content: "This is a great post! Thanks for sharing. I really appreciate the detailed explanation.",
                    isReply: true,
                    parentLoopId: "parent123",
                    authorDisplayName: "Jane Doe",
                    authorUsername: "janedoe",
                    authorBadgeType: .verified
                ),
                isLiked: false,
                indentLevel: 0,
                nestedReplyCount: 2,
                isExpanded: false,
                isLastInThread: false,
                onLike: {},
                onReply: {},
                onToggleExpanded: {},
                onDelete: {},
                onAvatarTap: {}
            )
            
            Divider()
                .padding(.horizontal)
            
            // Sample nested reply (reply to reply) - would be hidden by default
            ReplyCardView(
                reply: Loop(
                    authorId: "user2",
                    content: "Totally agree with this! 👍",
                    isReply: true,
                    parentLoopId: "parent123",
                    replyToReplyId: "user1reply",
                    authorDisplayName: "Mike Smith",
                    authorUsername: "mikesmith"
                ),
                isLiked: true,
                indentLevel: 1,
                nestedReplyCount: 0,
                isExpanded: false,
                isLastInThread: true,
                onLike: {},
                onReply: {},
                onToggleExpanded: nil,
                onDelete: nil,
                onAvatarTap: {}
            )
            
            Divider()
                .padding(.horizontal)
            
            // Sample top-level reply without nested replies
            ReplyCardView(
                reply: Loop(
                    authorId: "user3",
                    content: "I have a different perspective on this. While I understand your point, I think there are other factors to consider. Let me explain my reasoning...",
                    isReply: true,
                    parentLoopId: "parent123",
                    authorDisplayName: "Alex Johnson",
                    authorUsername: "alexj",
                    authorBadgeType: .premium
                ),
                isLiked: false,
                indentLevel: 0,
                nestedReplyCount: 0,
                isExpanded: false,
                isLastInThread: false,
                onLike: {},
                onReply: {},
                onToggleExpanded: nil,
                onDelete: nil,
                onAvatarTap: {}
            )
        }
        .padding(.vertical, 16)
    }
    .background(Color(.systemGroupedBackground))
}

