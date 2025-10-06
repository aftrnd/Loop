import SwiftUI

struct LoopCardView: View {
    let loop: Loop
    let isLiked: Bool
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    
    @State private var showingFullText = false
    
    private let maxPreviewLength = 280
    
    var body: some View {
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
                                .frame(width: 50, height: 50)
                                .clipShape(Circle())
                        } placeholder: {
                            // Placeholder while loading
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 50, height: 50)
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
                            HStack(spacing: 4) {
                                Image(systemName: "at")
                                    .font(.callout)
                                    .fontWeight(.heavy)
                                    .foregroundStyle(.secondary)
                                Text(username)
                                    .font(.callout)
                                    .fontWeight(.regular)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 12) {
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
                }
                
                // Media content
                if loop.hasMedia {
                    LoopMediaView(media: loop.media)
                }
            }
            
            // Action buttons
            HStack(spacing: 24) {
                // Like button
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isLiked ? .red : .secondary)
                        
                        if loop.likeCount > 0 {
                            Text("\(loop.likeCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // Reply button
                Button(action: onReply) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        if loop.replyCount > 0 {
                            Text("\(loop.replyCount)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                
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
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
    }
}

struct LoopMediaView: View {
    let media: [LoopMedia]
    
    var body: some View {
        if media.count == 1, let firstMedia = media.first {
            SingleMediaView(media: firstMedia)
        } else if media.count > 1 {
            MultipleMediaView(media: media)
        }
    }
}

struct SingleMediaView: View {
    let media: LoopMedia
    
    var body: some View {
        switch media.type {
        case .image:
            CachedAsyncImage(url: URL(string: media.url)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 200)
                    .overlay(
                        ProgressView()
                            .scaleEffect(1.2)
                    )
            }
            .frame(maxHeight: 400)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
        case .video:
            // Placeholder for video - would implement video player here
            RoundedRectangle(cornerRadius: 12)
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
}

struct MultipleMediaView: View {
    let media: [LoopMedia]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(media, id: \.id) { mediaItem in
                    SingleMediaView(media: mediaItem)
                        .frame(width: 200)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollTargetBehavior(.viewAligned)
    }
}

#Preview {
    VStack(spacing: 0) {
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
        
        Divider()
            .padding(.horizontal, 16)
        
        // Sample loop with media
        LoopCardView(
            loop: Loop(
                authorId: "user2",
                content: "Beautiful sunset from my hike today!",
                media: [
                    LoopMedia(
                        type: .image,
                        url: "https://picsum.photos/400/300"
                    )
                ],
                likes: ["user1", "user3", "user4"],
                replies: ["reply1", "reply2"],
                authorDisplayName: "Jane Smith",
                authorUsername: "janesmith"
            ),
            isLiked: true,
            onLike: {},
            onReply: {},
            onDelete: nil,
            onAvatarTap: {}
        )
    }
    .background(Color(.systemBackground))
}
