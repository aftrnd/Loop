import SwiftUI

/// Reusable user info header component showing avatar, display name, username, and badge
/// Used in both LoopCardView and ComposeLoopView for consistent styling
struct UserInfoHeader: View {
    let avatarURL: String?
    let displayName: String
    let username: String?
    let badgeType: BadgeType?
    let onAvatarTap: (() -> Void)?
    
    init(
        avatarURL: String?,
        displayName: String,
        username: String?,
        badgeType: BadgeType?,
        onAvatarTap: (() -> Void)? = nil
    ) {
        self.avatarURL = avatarURL
        self.displayName = displayName
        self.username = username
        self.badgeType = badgeType
        self.onAvatarTap = onAvatarTap
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                if let avatarURLString = avatarURL, let avatarURL = URL(string: avatarURLString) {
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
                    
                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            .onTapGesture {
                onAvatarTap?()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                // Display name (no badge here)
                HStack(alignment: .center) {
                    Text(displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Spacer()
                }
                
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
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                    }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
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





