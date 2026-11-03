import SwiftUI

/// Atomic component: Post header with avatar, name, badge, username, and timestamp
/// Single source of truth for all post headers - use this everywhere for consistency
struct PostHeader: View {
    /// Where the verified or premium badge sits
    enum BadgePlacement {
        /// Before the handle, as in posts
        case handle
        /// Before the name, for rows whose second line isn't a handle, such as a conversation's last message
        case name
    }
    
    // MARK: - Properties
    let avatarURL: String?
    let displayName: String
    let username: String?
    let badgeType: BadgeType?
    let badgePlacement: BadgePlacement
    /// A topic account's look, drawn in place of a photo
    let topic: LoopTopic?
    /// Where a topic post's story comes from, shown with the AI mark in place of the handle
    let source: String?
    /// Shorter ways to say `source`, shortest last; the first that fits shows when `source` doesn't
    let shorterSources: [String]
    let timestamp: String?
    let trailingIcon: String? // Optional trailing icon (e.g., "chevron.right")
    let showUsernamePrefix: Bool // Whether to show "@" before username
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
        badgePlacement: BadgePlacement = .handle,
        topic: LoopTopic? = nil,
        source: String? = nil,
        shorterSources: [String] = [],
        timestamp: String? = nil,
        trailingIcon: String? = nil,
        showUsernamePrefix: Bool = true,
        onAvatarTap: (() -> Void)? = nil,
        showDebugOverlay: Bool = false
    ) {
        self.avatarURL = avatarURL
        self.displayName = displayName
        self.username = username
        self.badgeType = badgeType
        self.badgePlacement = badgePlacement
        self.topic = topic
        self.source = source
        self.shorterSources = shorterSources
        self.timestamp = timestamp
        self.trailingIcon = trailingIcon
        self.showUsernamePrefix = showUsernamePrefix
        self.onAvatarTap = onAvatarTap
        self.showDebugOverlay = showDebugOverlay
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: spacing) {
            // Left: Avatar (full height)
            avatar
            
            // Right: Split container
            splitContainer
        }
        .frame(maxWidth: .infinity)
        // The header visibly ends with the avatar, below the text beside it
        .alignmentGuide(.visibleBottom) { $0[.bottom] }
        .background(showDebugOverlay ? Color.blue.opacity(0.1) : Color.clear)
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
            if let topic {
                TopicAvatar(topic: topic, size: avatarSize)
            } else if let avatarURLString = avatarURL, let avatarURL = URL(string: avatarURLString) {
                CachedAsyncImage(url: avatarURL, targetSize: CGSize(width: avatarSize, height: avatarSize)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(AvatarShape())
                } placeholder: {
                    AvatarShape()
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
                    AvatarShape()
                        .fill(Color(.systemGray5))
                        .frame(width: avatarSize, height: avatarSize)
                    
                    Color.clear
                        .frame(width: avatarSize, height: avatarSize)
                        .glassEffect(.regular, in: AvatarShape())
                    
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
    
    private var splitContainer: some View {
        VStack(alignment: .leading, spacing: 4) { // 4pt spacing - matches ChatRowView
            topHalf
            bottomHalf
        }
        .frame(maxHeight: avatarSize, alignment: .center)
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
    
    private var topHalf: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                if badgePlacement == .name, let badgeType {
                    badge(badgeType)
                }
                
                Text(displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if let timestamp = timestamp, !timestamp.isEmpty {
                HStack(spacing: 4) {
                    Text(timestamp)
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    
                    if let trailingIcon = trailingIcon {
                        Image(systemName: trailingIcon)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(
            Group {
                if showDebugOverlay {
                    Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                }
            }
        )
    }
    
    private var bottomHalf: some View {
        HStack(spacing: 0) {
            if topic != nil, let source, !source.isEmpty {
                topicSourceLine(source)
            } else if let username = username, !username.isEmpty {
                HStack(spacing: 4) {
                    if badgePlacement == .handle, let badgeType {
                        badge(badgeType)
                    }

                    Text(showUsernamePrefix ? "@\(username)" : username)
                        .font(.callout)
                        .fontWeight(.regular)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .overlay(
            Group {
                if showDebugOverlay {
                    Rectangle()
                        .stroke(Color.green, lineWidth: 2)
                }
            }
        )
    }

    private func sourceText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .fontWeight(.regular)
            .foregroundColor(.secondary)
            .lineLimit(1)
    }

    private func badge(_ badgeType: BadgeType) -> some View {
        Image(systemName: badgeType.iconName)
            .font(.system(size: 14))
            .foregroundColor(badgeType.color)
    }

    /// A topic post's second line: the AI mark, then the source of the story Loop wrote the post from
    private func topicSourceLine(_ source: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            AIMark()

            if shorterSources.isEmpty {
                sourceText(source)
            } else {
                ViewThatFits(in: .horizontal) {
                    ForEach([source] + shorterSources, id: \.self) { text in
                        sourceText(text)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Written by AI from \(source)")
    }
}

// MARK: - AI Mark

/// Marks what Loop wrote with AI: sparkles.2 cut out of a small plate with the avatar's corners, in the color of the
/// callout text beside it (secondary in posts). The plate is 1.3 times the callout's cap height and centered on its
/// capitals, so it overshoots them by 0.15 cap heights above and below; the symbol fills its middle four sevenths
struct AIMark: View {
    var fill: Color = .secondary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let capHeight = UIFont.preferredFont(forTextStyle: .callout, compatibleWith: traits).capHeight
        let side = capHeight * 1.3
        AvatarShape()
            .fill(fill)
            .overlay {
                Image(systemName: "sparkles.2")
                    .resizable()
                    .scaledToFit()
                    .padding(side * 3 / 14)
                    .blendMode(.destinationOut)
            }
            // The symbol shows the page through the plate
            .compositingGroup()
            .frame(width: side, height: side)
            // Its middle sits half a cap height above the baseline
            .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + capHeight / 2 }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Verified user with debug overlay
        PostHeader(
            avatarURL: nil,
            displayName: "John Doe",
            username: "johndoe",
            badgeType: .verified,
            timestamp: "2m",
            onAvatarTap: {},
            showDebugOverlay: true
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

        // Topic account
        PostHeader(
            avatarURL: nil,
            displayName: "Steelers",
            username: "steelers",
            badgeType: nil,
            topic: LoopTopic(id: "steelers", symbol: "football.fill", color: "#101820", ink: "#FFB612", style: "team"),
            source: "Yahoo Sports",
            timestamp: "12m",
            onAvatarTap: nil
        )
        .padding()
        .background(Color(.systemBackground))
    }
    .background(Color(.systemGroupedBackground))
}

