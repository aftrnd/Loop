import SwiftUI

/// Reusable user info header component showing avatar, display name, username, and badge
/// Used in both LoopCardView and ComposeLoopView for consistent styling
/// Uses CardLayoutConstants for pixel-perfect alignment across all card types
struct UserInfoHeader: View {
    let avatarURL: String?
    let displayName: String
    let username: String?
    let badgeType: BadgeType?
    let onAvatarTap: (() -> Void)?
    let avatarSize: CGFloat
    let spacing: CGFloat // Configurable spacing between avatar and text
    
    // Debug overlay
    @AppStorage("showLayoutDebugOverlays") private var showDebugOverlay = false
    
    init(
        avatarURL: String?,
        displayName: String,
        username: String?,
        badgeType: BadgeType?,
        onAvatarTap: (() -> Void)? = nil,
        avatarSize: CGFloat = CardLayoutConstants.avatarSize,
        spacing: CGFloat = CardLayoutConstants.avatarSpacing // Default: 10pt spacing (symmetrical with screen edge)
    ) {
        self.avatarURL = avatarURL
        self.displayName = displayName
        self.username = username
        self.badgeType = badgeType
        self.onAvatarTap = onAvatarTap
        self.avatarSize = avatarSize
        self.spacing = spacing
    }
    
    var body: some View {
        HStack(spacing: spacing) {
            // Avatar
            ZStack {
                if let avatarURLString = avatarURL, let avatarURL = URL(string: avatarURLString) {
                    // Show actual user avatar
                    CachedAsyncImage(url: avatarURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: avatarSize, height: avatarSize)
                            .clipShape(Circle())
                    } placeholder: {
                        // Placeholder while loading
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
            .onTapGesture {
                onAvatarTap?()
            }
            .debugFrame("UserInfoHeader-Avatar", enabled: AppConstants.Debug.logFrameCoordinates)
            
            VStack(alignment: .leading, spacing: 4) {
                // Display name
                Text(displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .overlay(
                        Group {
                            if showDebugOverlay {
                                Rectangle()
                                    .stroke(Color.green, lineWidth: 2)
                            }
                        }
                    )
                
                // Username with badge on its own line
                if let username = username, !username.isEmpty {
                    HStack(spacing: 4) {
                        // Badge if user has one (next to username)
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
                    .overlay(
                        Group {
                            if showDebugOverlay {
                                Rectangle()
                                    .stroke(Color.green, lineWidth: 2)
                            }
                        }
                    )
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .overlay(
                Group {
                    if showDebugOverlay {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(height: 2)
                            .offset(y: 0)
                    }
                }
            )
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // User with badge
        UserInfoHeader(
            avatarURL: nil,
            displayName: "John Doe",
            username: "johndoe",
            badgeType: .verified
        )
        .padding()
        
        // User without badge
        UserInfoHeader(
            avatarURL: nil,
            displayName: "Jane Smith",
            username: "janesmith",
            badgeType: nil
        )
        .padding()
        
        // User without username
        UserInfoHeader(
            avatarURL: nil,
            displayName: "Anonymous",
            username: nil,
            badgeType: nil
        )
        .padding()
    }
}





