import SwiftUI

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
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    
    @State private var showingFullText = false
    @State private var likeAnimationScale: CGFloat = 1.0
    
    private let maxPreviewLength = 280
    private let cardCornerRadius: CGFloat = 16
    private let mediaCornerRadius: CGFloat = 12
    
    var body: some View {
        VStack(spacing: 0) {
            // Card content with padding
            VStack(alignment: .leading, spacing: 12) {
            // Header with author info
            HStack(spacing: 16) {
                // Avatar
                ZStack {
                    if let avatarURLString = loop.authorAvatarURL, let avatarURL = URL(string: avatarURLString) {
                        // Show actual user avatar
                        CachedAsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 56, height: 56)
                                .clipShape(Circle())
                        } placeholder: {
                            // Placeholder while loading
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 56, height: 56)
                                .overlay {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                        }
                    } else {
                        // Default avatar with initials
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 50, height: 50)
                        
                        Color.clear
                            .frame(width: 50, height: 50)
                            .glassEffect(.regular, in: Circle())
                        
                        Text(String(loop.displayAuthorName.prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                .onTapGesture {
                    onAvatarTap?()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center) {
                        HStack(spacing: 4) {
                            Text(loop.displayAuthorName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            // Badge if user has one
                            if let badgeType = loop.authorBadgeType {
                                Image(systemName: badgeType.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(badgeType.color)
                            }
                        }
                        
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
                    
                    // Username on its own line below the name (exact ProfileView styling)
                    if let username = loop.authorUsername, !username.isEmpty {
                        HStack {
                            Text("@\(username)")
                                .font(.callout)
                                .fontWeight(.regular)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            
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
                    .padding(.bottom, loop.hasMedia ? 12 : 0)
                }
                
                // Media content - unified approach for both single and multiple photos
                if loop.hasMedia {
                    LoopMediaView(media: loop.media)
                }
            }
            
            // Action buttons
            HStack(spacing: 0) {
                // Like button
                Button(action: {
                    // Trigger bounce animation
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        likeAnimationScale = 1.3
                    }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) {
                        likeAnimationScale = 1.0
                    }
                    onLike()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isLiked ? .red : .secondary)
                            .scaleEffect(likeAnimationScale)
                        
                        Text(loop.likeCount > 99 ? "99+" : loop.likeCount > 0 ? "\(loop.likeCount)" : "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 44, alignment: .leading)
                .contentShape(Rectangle())
                
                // Reply button
                Button(action: onReply) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(loop.replyCount > 99 ? "99+" : loop.replyCount > 0 ? "\(loop.replyCount)" : "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 44, alignment: .leading)
                .contentShape(Rectangle())
                
                // Share button
                Button(action: {
                    // TODO: Implement share functionality
                }) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 44, alignment: .leading)
                .contentShape(Rectangle())
                
                Spacer()
                
                // Three dots menu (only show if user can delete)
                if let onDelete = onDelete {
                    Menu {
                        Button("Delete", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            }
            .padding(.leading, 10)
            .padding(.trailing, 10)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .concentricCard(cornerRadius: cardCornerRadius)
            
        }
    }
}

struct LoopMediaView: View {
    let media: [LoopMedia]
    private let mediaCornerRadius: CGFloat = 12
    
    var body: some View {
        if media.count == 1, let firstMedia = media.first {
            SingleMediaView(media: firstMedia, cornerRadius: mediaCornerRadius)
        } else if media.count > 1 {
            // Multiple photos with same padding as single photos
            MultipleMediaView(media: media, cornerRadius: mediaCornerRadius)
        }
    }
}

struct SingleMediaView: View {
    let media: LoopMedia
    let cornerRadius: CGFloat
    
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
    @State private var currentIndex = 0
    
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
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(Array(media.enumerated()), id: \.element.id) { index, mediaItem in
                        CarouselPhotoView(
                            media: mediaItem,
                            cornerRadius: cornerRadius,
                            height: carouselHeight
                        )
                        .frame(width: geometry.size.width)
                        .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: .constant(currentIndex))
        }
        .frame(height: carouselHeight)
    }
}

struct CarouselPhotoView: View {
    let media: LoopMedia
    let cornerRadius: CGFloat
    let height: CGFloat
    
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

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Sample loop with text only
            LoopCardView(
                loop: Loop(
                    authorId: "user1",
                    content: "Just shipped a new feature for our app! Really excited to see how users respond to the new design. The team has been working hard on this for months. 🚀",
                    authorDisplayName: "John Doe",
                    authorUsername: "johndoe",
                    authorBadgeType: .verified
                ),
                isLiked: false,
                onLike: {},
                onReply: {},
                onDelete: {},
                onAvatarTap: {}
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
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {}
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
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {}
            )
            
            // 9:16 portrait (should be tall)
            LoopCardView(
                loop: Loop(
                    authorId: "user4",
                    content: "Tall portrait mode 📱 (9:16 ratio)",
                    media: [
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/900/1600",
                            width: 900,
                            height: 1600
                        )
                    ],
                    authorDisplayName: "Sarah Wilson",
                    authorUsername: "sarahw"
                ),
                isLiked: false,
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {}
            )
            
            // Very wide panorama
            LoopCardView(
                loop: Loop(
                    authorId: "user5",
                    content: "Ultra-wide panorama (should be short)",
                    media: [
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/2000/600",
                            width: 2000,
                            height: 600
                        )
                    ],
                    authorDisplayName: "Alex Chen",
                    authorUsername: "alexc"
                ),
                isLiked: true,
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {}
            )
            
            // Very tall portrait
            LoopCardView(
                loop: Loop(
                    authorId: "user6",
                    content: "Very tall portrait (should be tall)",
                    media: [
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/600/2000",
                            width: 600,
                            height: 2000
                        )
                    ],
                    authorDisplayName: "Emma Davis",
                    authorUsername: "emmad"
                ),
                isLiked: false,
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {}
            )
            
            // Multiple photos carousel
            LoopCardView(
                loop: Loop(
                    authorId: "user7",
                    content: "Check out this amazing carousel! Swipe to see more photos 📸✨",
                    media: [
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/400/600?random=1",
                            width: 400,
                            height: 600
                        ),
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/600/400?random=2",
                            width: 600,
                            height: 400
                        ),
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/500/500?random=3",
                            width: 500,
                            height: 500
                        ),
                        LoopMedia(
                            type: .image,
                            url: "https://picsum.photos/800/400?random=4",
                            width: 800,
                            height: 400
                        )
                    ],
                    authorDisplayName: "Sarah Wilson",
                    authorUsername: "sarahw"
                ),
                isLiked: false,
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {}
            )
        }
        .padding(.horizontal, 16)
    }
    .background(Color(.systemGroupedBackground))
}
