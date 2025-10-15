import SwiftUI
import Combine

// MARK: - Animation State Manager
// This persists across view re-renders to ensure smooth animations
class LoopCardAnimationState: ObservableObject {
    @Published var heartScale: CGFloat = 1.0
    @Published var heartRotation: Double = 0
    @Published var particleTriggerID = UUID()
    
    private var animationTask: Task<Void, Never>?
    
    func triggerHeartAnimation() {
        // Cancel any existing animation
        animationTask?.cancel()
        
        // Start new animation
        animationTask = Task { @MainActor in
            // Scale up
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                heartScale = 1.5
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                heartRotation = 12
            }
            
            // Trigger particle animation with a new unique ID
            particleTriggerID = UUID()
            
            // Wait and scale down
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                heartScale = 1.0
                heartRotation = 0
            }
        }
    }
    
    deinit {
        animationTask?.cancel()
    }
}

// MARK: - Concentric Design Helper
extension View {
    /// Applies concentric corner radius that harmonizes with the parent container
    /// This follows Apple's concentricity design principle from WWDC
    func concentricCorners(
        _ radius: CGFloat,
        minimum: CGFloat = 0
    ) -> some View {
        self.clipShape(RoundedRectangle(cornerRadius: max(radius, minimum)))
    }
    
    /// Creates a concentric card background with proper shadow and corner radius
    func concentricCard(
        cornerRadius: CGFloat = 16,
        shadowRadius: CGFloat = 8,
        shadowOffset: CGSize = CGSize(width: 0, height: 2)
    ) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: .black.opacity(0.05),
                        radius: shadowRadius,
                        x: shadowOffset.width,
                        y: shadowOffset.height
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct LoopCardView: View {
    let loop: Loop
    let isLiked: Bool
    let cardIndex: Int
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    let onCardTap: (() -> Void)? // New: handle tap to view details
    let replyPreviews: [Loop]? // New: optional reply previews to show inline
    
    // Animation state persists across view re-renders
    @StateObject private var animationState = LoopCardAnimationState()
    
    @State private var showingFullText = false
    
    // Photo viewer state
    @State private var showPhotoViewer = false
    @State private var selectedPhotoIndex: Int = 0
    
    // Carousel state for page indicators
    @State private var currentCarouselIndex: Int = 0
    
    private let maxPreviewLength = 280
    private let maxReplyPreviews = 1 // Show max 1 reply preview (most recent from followed users)
    
    var body: some View {
        VStack(spacing: 0) {
            // When there are reply previews, use ReplyCardView layout for consistency
            if let replies = replyPreviews, !replies.isEmpty {
                replyThreadView(replies: replies)
            } else {
                // Standard card view when no reply previews
                cardContent
                    .zIndex(0)
                    .overlay(alignment: .bottomLeading) {
                        // Particle layer - renders above card content AND subsequent cards
                        GeometryReader { geo in
                            HeartParticleAnimationView(
                                iconSize: CardLayoutConstants.actionButtonIconSize,
                                triggerID: animationState.particleTriggerID
                            )
                            .frame(width: 200, height: 200) // Large enough for particles to fly
                            .position(x: CardLayoutConstants.actionButtonWidth / 2, y: geo.size.height - CardLayoutConstants.actionButtonHeight / 2) // Position at heart button
                            .allowsHitTesting(false)
                        }
                        .zIndex(Double(1000 - cardIndex)) // Higher z-index for earlier posts
                    }
                    .fullScreenCover(isPresented: $showPhotoViewer) {
                        FullScreenPhotoViewer(
                            allMedia: loop.media,
                            startingIndex: selectedPhotoIndex,
                            isPresented: $showPhotoViewer
                        )
                        .presentationBackground(.clear)
                    }
            }
        }
        .id(loop.id) // Stable identity prevents view recreation during updates
    }
    
    private var cardContent: some View {
        VStack(spacing: 0) {
            // Card content with padding
            VStack(alignment: .leading, spacing: 0) {
            // Header with author info using reusable component
            HStack(spacing: 0) {
                UserInfoHeader(
                    avatarURL: loop.authorAvatarURL,
                    displayName: loop.displayAuthorName,
                    username: loop.authorUsername,
                    badgeType: loop.authorBadgeType,
                    onAvatarTap: onAvatarTap
                )
                .debugFrame("LoopCard-Header", enabled: AppConstants.Debug.logFrameCoordinates)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(loop.timeAgoString)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.bottom, CardLayoutConstants.headerBottomSpacing)
            .debugFrame("LoopCard-HeaderContainer", enabled: AppConstants.Debug.logFrameCoordinates)
            
            // Content
            VStack(alignment: .leading, spacing: 0) {
                // Text content
                if !loop.content.isEmpty {
                    let shouldTruncate = loop.content.count > maxPreviewLength && !showingFullText
                    let displayText = shouldTruncate ? String(loop.content.prefix(maxPreviewLength)) + "..." : loop.content
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayText)
                            .font(.system(.body, design: .default))
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        if shouldTruncate {
                            Button("Show more") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingFullText = true
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        } else if loop.content.count > maxPreviewLength && showingFullText {
                            Button("Show less") {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showingFullText = false
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.bottom, loop.hasMedia ? CardLayoutConstants.contentSpacing : CardLayoutConstants.contentToActionsSpacing)
                }
                
                // Media content - unified approach for both single and multiple photos
                if loop.hasMedia {
                    LoopMediaView(
                        media: loop.media,
                        currentIndex: $currentCarouselIndex,
                        onPhotoTap: { index in
                            selectedPhotoIndex = index
                            showPhotoViewer = true
                        }
                    )
                    .padding(.bottom, CardLayoutConstants.contentToActionsSpacing)
                }
            }
            
            // Action buttons
            HStack(alignment: .center, spacing: CardLayoutConstants.actionButtonSpacing) {
                // Like button with scale animation
                Button(action: {
                    // Trigger animation - persists even if view re-renders
                    animationState.triggerHeartAnimation()
                    
                    // ViewModel handles all optimistic updates and backend calls
                    onLike()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                            .foregroundColor(isLiked ? .red : .secondary)
                            .scaleEffect(animationState.heartScale)
                            .rotationEffect(.degrees(animationState.heartRotation))
                        
                        Text(loop.likeCount > 99 ? "99+" : loop.likeCount > 0 ? "\(loop.likeCount)" : "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
                .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .leading)
                .contentShape(Rectangle())
                
                // Reply button - tapping shows detail view if onCardTap is provided
                Button(action: {
                    if let onCardTap = onCardTap {
                        onCardTap()
                    } else {
                        onReply()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(loop.replyCount > 99 ? "99+" : loop.replyCount > 0 ? "\(loop.replyCount)" : "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
                .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .leading)
                .contentShape(Rectangle())
                
                // Share button
                Button(action: {
                    // TODO: Implement share functionality
                }) {
                    Image(systemName: "paperplane")
                        .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .leading)
                .contentShape(Rectangle())
                
                // Page indicators for multi-image posts
                if loop.media.count > 1 {
                    PageIndicator(currentPage: currentCarouselIndex, pageCount: loop.media.count)
                        .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .center)
                }
                
                Spacer()
                
                // Three dots menu (only show if user can delete)
                if let onDelete = onDelete {
                    Menu {
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .debugFrame("LoopCard-ActionButtons", enabled: AppConstants.Debug.logFrameCoordinates)
            }
            .padding(.leading, CardLayoutConstants.horizontalPadding)
            .padding(.trailing, CardLayoutConstants.horizontalPadding)
            .padding(.top, CardLayoutConstants.topPadding)
            .padding(.bottom, CardLayoutConstants.bottomPadding)
            .concentricCard(cornerRadius: CardLayoutConstants.cornerRadius)
            
        }
    }
    
    @ViewBuilder
    private func replyThreadView(replies: [Loop]) -> some View {
        ReplyThreadWithLineView(
            loop: loop,
            replies: replies,
            isLiked: isLiked,
            onLike: onLike,
            onReply: onCardTap,
            onDelete: onDelete,
            onAvatarTap: onAvatarTap,
            onCardTap: onCardTap,
            showPhotoViewer: $showPhotoViewer,
            selectedPhotoIndex: $selectedPhotoIndex
        )
    }
}

// MARK: - Reply Thread With Dynamic Line
struct ReplyThreadWithLineView: View {
    let loop: Loop
    let replies: [Loop]
    let isLiked: Bool
    let onLike: () -> Void
    let onReply: (() -> Void)?
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    let onCardTap: (() -> Void)?
    @Binding var showPhotoViewer: Bool
    @Binding var selectedPhotoIndex: Int
    
    @State private var mainPostHeight: CGFloat = 0
    @State private var replyHeight: CGFloat = 0
    
    private let maxReplyPreviews = 1
    
    // MARK: - Computed Properties
    
    /// Perfectly calculated connecting line between avatars with even spacing
    @ViewBuilder
    private var connectingLine: some View {
        if mainPostHeight > 0 {
            let lineWidth = CardLayoutConstants.conversationLineWidth
            
            // Main avatar bottom edge
            let mainAvatarBottom = CardLayoutConstants.topPadding + CardLayoutConstants.avatarSize
            
            // Line starts after gap from main avatar
            let lineStart = mainAvatarBottom + CardLayoutConstants.avatarLineGap
            
            // Reply avatar top edge (after main post, divider, and reply padding)
            let replyAvatarTop = mainPostHeight + CardLayoutConstants.dividerHeight + CardLayoutConstants.topPadding
            
            // Line ends before gap to reply avatar
            let lineEnd = replyAvatarTop - CardLayoutConstants.avatarLineGap
            
            // Calculate line height
            let lineHeight = max(0, lineEnd - lineStart)
            
            // Horizontal position: center of avatar
            let avatarCenter = CardLayoutConstants.avatarSize / 2
            let lineX = CardLayoutConstants.horizontalPadding + avatarCenter - (lineWidth / 2)
            
            HStack(spacing: 0) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: lineStart)
                    
                    RoundedRectangle(cornerRadius: lineWidth / 2)
                        .fill(Color(.quaternaryLabel))
                        .frame(width: lineWidth, height: lineHeight)
                    
                    Spacer()
                }
                .frame(width: lineWidth)
                .offset(x: lineX)
                
                Spacer()
            }
        }
    }
    
    var body: some View {
        let previewReplies = Array(replies.prefix(maxReplyPreviews))
        
        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    // Main post
                    ReplyCardView(
                        reply: loop,
                        isLiked: isLiked,
                        indentLevel: 0,
                        nestedReplyCount: previewReplies.count,
                        isExpanded: true,
                        isLastInThread: false,
                        onLike: onLike,
                        onReply: onCardTap,
                        onToggleExpanded: nil,
                        onDelete: onDelete,
                        onAvatarTap: onAvatarTap,
                        showAsMainPost: true
                    )
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear {
                                    print("🟢 MAIN POST HEIGHT MEASURED: \(geo.size.height)")
                                    mainPostHeight = geo.size.height
                                }
                                .onChange(of: geo.size.height) { newHeight in
                                    print("🟢 MAIN POST HEIGHT CHANGED: \(newHeight)")
                                    mainPostHeight = newHeight
                                }
                        }
                    )
                    
                    // Divider - aligned with name/text
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: CardLayoutConstants.dividerHeight)
                        .padding(.leading, CardLayoutConstants.horizontalPadding + CardLayoutConstants.avatarSize + CardLayoutConstants.avatarSpacing)
                        .padding(.trailing, CardLayoutConstants.horizontalPadding)
                    
                    // Reply preview
                    ForEach(Array(previewReplies.enumerated()), id: \.element.id) { index, reply in
                        ReplyCardView(
                            reply: reply,
                            isLiked: false,
                            indentLevel: 1,
                            nestedReplyCount: 0,
                            isExpanded: false,
                            isLastInThread: false,
                            onLike: { onCardTap?() },
                            onReply: onCardTap,
                            onToggleExpanded: nil,
                            onDelete: nil,
                            onAvatarTap: onCardTap
                        )
                    }
                }
                
                // Connecting line with perfect spacing
                connectingLine
            }
            .concentricCard(cornerRadius: CardLayoutConstants.cornerRadius)
            .fullScreenCover(isPresented: $showPhotoViewer) {
                FullScreenPhotoViewer(
                    allMedia: loop.media,
                    startingIndex: selectedPhotoIndex,
                    isPresented: $showPhotoViewer
                )
                .presentationBackground(.clear)
            }
        }
    }
}

// MARK: - Preference Keys
struct MainPostHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ReplyHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct LoopMediaView: View {
    let media: [LoopMedia]
    @Binding var currentIndex: Int
    let onPhotoTap: (Int) -> Void
    
    var body: some View {
        if media.count == 1, let firstMedia = media.first {
            SingleMediaView(
                media: firstMedia,
                cornerRadius: CardLayoutConstants.mediaCornerRadius,
                onPhotoTap: { onPhotoTap(0) }
            )
        } else if media.count > 1 {
            // Multiple photos with same padding as single photos
            MultipleMediaView(
                media: media,
                cornerRadius: CardLayoutConstants.mediaCornerRadius,
                currentIndex: $currentIndex,
                onPhotoTap: onPhotoTap
            )
        }
    }
}

struct SingleMediaView: View {
    let media: LoopMedia
    let cornerRadius: CGFloat
    let onPhotoTap: () -> Void
    
    var body: some View {
        switch media.type {
        case .image:
            let displayMode = determineDisplayMode(media: media)
            
            CachedAsyncImage(url: URL(string: media.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: displayMode.height)
                    .clipped()
            } placeholder: {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: displayMode.height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.0)
                    )
            }
            .frame(height: displayMode.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onTapGesture {
                onPhotoTap()
            }
            
        case .video:
            // Placeholder for video - would implement video player here
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Video")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                )
            
        case .text:
            EmptyView()
        }
    }
    
    private func determineDisplayMode(media: LoopMedia) -> ImageDisplayMode {
        guard let width = media.width, let height = media.height, height > 0 else {
            // Default to square if no dimensions
            return ImageDisplayMode(height: 300, contentMode: .fill)
        }
        
        let aspectRatio = width / height
        
        // Calculate height based on aspect ratio to show proper proportions
        // Use a base width of ~350 (approximate card width minus padding) to calculate proportional height
        let baseWidth: CGFloat = 350
        let proportionalHeight = baseWidth / aspectRatio
        
        // Clamp height to reasonable bounds for UI
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        let clampedHeight = max(minHeight, min(maxHeight, proportionalHeight))
        
        return ImageDisplayMode(height: clampedHeight, contentMode: .fill)
    }
}

struct ImageDisplayMode {
    let height: CGFloat
    let contentMode: ContentMode
}

struct MultipleMediaView: View {
    let media: [LoopMedia]
    let cornerRadius: CGFloat
    @Binding var currentIndex: Int
    let onPhotoTap: (Int) -> Void
    @State private var scrollIndex: Int? = 0
    
    // Use the same height calculation as single photos
    var carouselHeight: CGFloat {
        guard let firstMedia = media.first else { return 300 }
        return determineDisplayMode(media: firstMedia).height
    }
    
    private func determineDisplayMode(media: LoopMedia) -> ImageDisplayMode {
        guard let width = media.width, let height = media.height, height > 0 else {
            // Default to square if no dimensions
            return ImageDisplayMode(height: 300, contentMode: .fill)
        }
        
        let aspectRatio = width / height
        
        // Calculate height based on aspect ratio to show proper proportions
        // Use a base width of ~350 (approximate card width minus padding) to calculate proportional height
        let baseWidth: CGFloat = 350
        let proportionalHeight = baseWidth / aspectRatio
        
        // Clamp height to reasonable bounds for UI
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        let clampedHeight = max(minHeight, min(maxHeight, proportionalHeight))
        
        return ImageDisplayMode(height: clampedHeight, contentMode: .fill)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image carousel
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(media.enumerated()), id: \.offset) { index, mediaItem in
                            CarouselPhotoView(
                                media: mediaItem,
                                cornerRadius: cornerRadius,
                                height: carouselHeight,
                                onPhotoTap: { onPhotoTap(index) }
                            )
                            .frame(width: geometry.size.width)
                            .containerRelativeFrame(.horizontal)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollIndex)
            }
            .frame(height: carouselHeight)
            .onChange(of: scrollIndex) { _, newValue in
                if let newValue = newValue {
                    currentIndex = newValue
                }
            }
        }
    }
}

struct CarouselPhotoView: View {
    let media: LoopMedia
    let cornerRadius: CGFloat
    let height: CGFloat
    let onPhotoTap: () -> Void
    
    var body: some View {
        switch media.type {
        case .image:
            let displayMode = determineDisplayMode(media: media)
            
            CachedAsyncImage(url: URL(string: media.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: displayMode.height)
                    .frame(height: displayMode.height)
                    .clipped()
            } placeholder: {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: displayMode.height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.0)
                    )
            }
            .frame(height: displayMode.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .onTapGesture {
                onPhotoTap()
            }
            
        case .video:
            // Placeholder for video - would implement video player here
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 200)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                        Text("Video")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                )
            
        case .text:
            EmptyView()
        }
    }
    
    private func determineDisplayMode(media: LoopMedia) -> ImageDisplayMode {
        guard let width = media.width, let height = media.height, height > 0 else {
            // Default to square if no dimensions
            return ImageDisplayMode(height: 300, contentMode: .fill)
        }
        
        let aspectRatio = width / height
        
        // Calculate height based on aspect ratio to show proper proportions
        // Use a base width of ~350 (approximate card width minus padding) to calculate proportional height
        let baseWidth: CGFloat = 350
        let proportionalHeight = baseWidth / aspectRatio
        
        // Clamp height to reasonable bounds for UI
        let minHeight: CGFloat = 150
        let maxHeight: CGFloat = 500
        let clampedHeight = max(minHeight, min(maxHeight, proportionalHeight))
        
        return ImageDisplayMode(height: clampedHeight, contentMode: .fill)
    }
}

// Compact page indicator component
struct PageIndicator: View {
    let currentPage: Int
    let pageCount: Int
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(currentPage == index ? Color.primary : Color.secondary.opacity(0.5))
                    .frame(width: 5, height: 5)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Sample loop with text only and reply preview
            LoopCardView(
                loop: Loop(
                    authorId: "user1",
                    content: "Just shipped a new feature for our app! Really excited to see how users respond to the new design. The team has been working hard on this for months. 🚀",
                    replies: ["reply1"],
                    authorDisplayName: "John Doe",
                    authorUsername: "johndoe",
                    authorBadgeType: .verified
                ),
                isLiked: false,
                cardIndex: 0,
                onLike: {},
                onReply: {},
                onDelete: {},
                onAvatarTap: {},
                onCardTap: {},
                replyPreviews: [
                    Loop(
                        authorId: "user2",
                        content: "This is amazing! Can't wait to try it out. The new design looks really sleek and modern!",
                        isReply: true,
                        authorDisplayName: "Jane Smith",
                        authorUsername: "janesmith",
                        authorBadgeType: .verified
                    )
                ]
            )
            
            // Sample loop with multiple replies to show "See more replies"
            LoopCardView(
                loop: Loop(
                    authorId: "user3",
                    content: "What do you think about the new iOS update? There are so many new features to explore!",
                    replies: ["reply1", "reply2", "reply3", "reply4"],
                    authorDisplayName: "Mike Johnson",
                    authorUsername: "mikej"
                ),
                isLiked: false,
                cardIndex: 1,
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {},
                onCardTap: {},
                replyPreviews: [
                    Loop(
                        authorId: "user4",
                        content: "I love the new control center! So much more customizable now.",
                        isReply: true,
                        authorDisplayName: "Sarah Wilson",
                        authorUsername: "sarahw",
                        authorBadgeType: .premium
                    )
                ]
            )
            
            // Square image (1:1)
            LoopCardView(
                loop: Loop(
                    authorId: "user2",
                    content: "Perfect square photo!",
                    media: [
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/400/400",
                            width: 400,
                            height: 400
                        )
                    ],
                    authorDisplayName: "Jane Smith",
                    authorUsername: "janesmith"
                ),
                isLiked: true,
                cardIndex: 1,
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {},
                onCardTap: nil,
                replyPreviews: nil
            )
            
            // 16:9 landscape
            LoopCardView(
                loop: Loop(
                    authorId: "user3",
                    content: "Cinematic landscape shot 🎬",
                    media: [
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/1600/900",
                            width: 1600,
                            height: 900
                        )
                    ],
                    authorDisplayName: "Mike Johnson",
                    authorUsername: "mikej"
                ),
                isLiked: false,
                cardIndex: 2,
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {},
                onCardTap: nil,
                replyPreviews: nil
            )
        }
        .padding(.horizontal, 16)
    }
    .background(Color(.systemGroupedBackground))
}
