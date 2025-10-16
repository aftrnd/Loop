import SwiftUI

/// Atomic component: Post header with avatar, name, badge, username, and timestamp
/// Single source of truth for all post headers - use this everywhere for consistency
struct PostHeader: View {
    // MARK: - Properties
    let avatarURL: String?
    let displayName: String
    let username: String?
    let badgeType: BadgeType?
    let timestamp: String
    let onAvatarTap: (() -> Void)?
    let showDebugOverlay: Bool
    
    // MARK: - Layout Configuration
    private let avatarSize: CGFloat = CardLayoutConstants.avatarSize
    private let spacing: CGFloat = CardLayoutConstants.avatarSpacing
    
    init(
        avatarURL: String?,
        displayName: String,
        username: String?,
        badgeType: BadgeType?,
        timestamp: String,
        onAvatarTap: (() -> Void)? = nil,
        showDebugOverlay: Bool = false
    ) {
        self.avatarURL = avatarURL
        self.displayName = displayName
        self.username = username
        self.badgeType = badgeType
        self.timestamp = timestamp
        self.onAvatarTap = onAvatarTap
        self.showDebugOverlay = showDebugOverlay
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            // Left: Avatar + Name/Username
            HStack(spacing: spacing) {
                avatar
                nameStack
            }
            
            Spacer()
            
            // Right: Timestamp
            timestampView
        }
        .frame(maxWidth: .infinity)
        .background(showDebugOverlay ? Color.blue.opacity(0.1) : Color.clear) // Debug: Header background
        .overlay(
            Group {
                if showDebugOverlay {
                    Rectangle()
                        .stroke(Color.red, lineWidth: 1)
                }
            }
        )
    }
    
    // MARK: - Subviews
    
    private var avatar: some View {
        Group {
            if let avatarURLString = avatarURL, let avatarURL = URL(string: avatarURLString) {
                CachedAsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                }
            } else {
                // Default avatar with initials
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: avatarSize, height: avatarSize)
                    
                    Color.clear
                        .frame(width: avatarSize, height: avatarSize)
                        .glassEffect(.regular, in: Circle())
                    
                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
        }
        .onTapGesture {
            onAvatarTap?()
        }
    }
    
    private var nameStack: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Display name
            Text(displayName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
            
            // Username with badge
            if let username = username, !username.isEmpty {
                HStack(spacing: 4) {
                    // Badge icon
                    if let badgeType = badgeType {
                        Image(systemName: badgeType.iconName)
                            .font(.system(size: 14))
                            .foregroundColor(badgeType.color)
                    }
                    
                    Text("@\(username)")
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }
    
    private var timestampView: some View {
        Text(timestamp)
            .font(.subheadline)
            .monospacedDigit()
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Verified user
        PostHeader(
            avatarURL: nil,
            displayName: "John Doe",
            username: "johndoe",
            badgeType: .verified,
            timestamp: "2m",
            onAvatarTap: {}
        )
        .padding()
        .background(Color(.systemBackground))
        
        // Premium user
        PostHeader(
            avatarURL: nil,
            displayName: "Jane Smith",
            username: "janesmith",
            badgeType: .premium,
            timestamp: "1h",
            onAvatarTap: nil
        )
        .padding()
        .background(Color(.systemBackground))
        
        // Regular user
        PostHeader(
            avatarURL: nil,
            displayName: "Mike Johnson",
            username: "mikej",
            badgeType: nil,
            timestamp: "3d",
            onAvatarTap: nil
        )
        .padding()
        .background(Color(.systemBackground))
    }
    .background(Color(.systemGroupedBackground))
}

