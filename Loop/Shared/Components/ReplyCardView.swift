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
}

// MARK: - Shared Layout Constants
enum CardLayoutConstants {
    static let horizontalPadding: CGFloat = 10
    static let topPadding: CGFloat = 8
    static let bottomPadding: CGFloat = 8
    static let avatarSize: CGFloat = 56
    static let avatarSpacing: CGFloat = 12
    static let avatarLineGap: CGFloat = 10
    static let dividerHeight: CGFloat = 1.15
    static let cornerRadius: CGFloat = 16
    static let contentShift: CGFloat = 68 // avatarSize (56) + avatarSpacing (12)
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
    
    private let maxPreviewLength = 280
    private let cardCornerRadius: CGFloat = 12
    
    // Clean, subtle indent for nested replies (like Reddit/Twitter)
    private var totalIndent: CGFloat {
        CGFloat(indentLevel) * 40 // 40px per nesting level
    }
    
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
            VStack(alignment: .leading, spacing: CardLayoutConstants.avatarSpacing) {
                // Header row: Avatar + Name/Badge/Time
                HStack(alignment: .center, spacing: CardLayoutConstants.avatarSpacing) {
                    // Avatar
                    avatarView
                        .frame(width: CardLayoutConstants.avatarSize)
                    
                    // Name, badge, username, and time
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                // Display name
                                Text(reply.displayAuthorName)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                
                                // Username with badge
                                if let username = reply.authorUsername, !username.isEmpty {
                                    HStack(spacing: 4) {
                                        if let badgeType = reply.authorBadgeType {
                                            Image(systemName: badgeType.iconName)
                                                .font(.system(size: 14))
                                                .foregroundColor(badgeType.color)
                                        }
                                        
                                        Text("@\(username)")
                                            .font(.callout)
                                            .fontWeight(.regular)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                Text(reply.timeAgoString)
                                    .font(.subheadline)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                }
                
                // Content - aligned with avatar's left edge, shifts right to align with name when:
                // - Top-level reply that's expanded with nested replies, OR
                // - Nested reply that's NOT the last one in the thread
                if !reply.content.isEmpty {
                    contentView
                        .padding(.leading, shouldShiftContent ? CardLayoutConstants.contentShift : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldShiftContent)
                }
                
                // Action buttons - aligned with avatar's left edge, shifts right when content does
                actionButtonsView
                    .padding(.leading, shouldShiftContent ? CardLayoutConstants.contentShift : 0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: shouldShiftContent)
            }
            .if(applyInternalPadding) { view in
                view
                    .padding(.leading, CardLayoutConstants.horizontalPadding)
                    .padding(.trailing, CardLayoutConstants.horizontalPadding)
                    .padding(.top, CardLayoutConstants.topPadding)
                    .padding(.bottom, CardLayoutConstants.bottomPadding)
            }
            
            // Show/Hide nested replies button - shows at top when collapsed
            if indentLevel == 0 && nestedReplyCount > 0, let onToggleExpanded = onToggleExpanded, !isExpanded {
                HStack {
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
                    .padding(.leading, 0) // Align with content at left edge
                    .padding(.bottom, 12)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    // MARK: - Reusable Components
    private var avatarView: some View {
        Group {
            if let avatarURLString = reply.authorAvatarURL, let avatarURL = URL(string: avatarURLString) {
                CachedAsyncImage(url: avatarURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: CardLayoutConstants.avatarSize, height: CardLayoutConstants.avatarSize)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: CardLayoutConstants.avatarSize, height: CardLayoutConstants.avatarSize)
                }
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: CardLayoutConstants.avatarSize, height: CardLayoutConstants.avatarSize)
                    .overlay {
                        Text(String((reply.displayAuthorName ?? "?").prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
            }
        }
        .background {
            // Add mask/border for middle nested replies to create spacing from the line
            if indentLevel == 1 && !isLastInThread {
                Circle()
                    .fill(Color(.systemBackground))
                    .frame(width: CardLayoutConstants.avatarSize + 20, height: CardLayoutConstants.avatarSize + 20)
            }
        }
        .onTapGesture {
            onAvatarTap?()
        }
    }
    
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
    
    private var actionButtonsView: some View {
        HStack(spacing: 0) {
            // Like button
            Button(action: onLike) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isLiked ? .red : .secondary)
                    
                    if reply.likeCount > 0 {
                        Text(reply.likeCount > 99 ? "99+" : "\(reply.likeCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            .buttonStyle(.plain)
            .frame(width: 50, alignment: .leading)
            .contentShape(Rectangle())
            
            // Show different buttons based on context
            if showAsMainPost {
                // Comment button (for main posts with reply previews)
                if let onReply = onReply {
                    Button(action: onReply) {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text(reply.replyCount > 99 ? "99+" : reply.replyCount > 0 ? "\(reply.replyCount)" : "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 50, alignment: .leading)
                    .contentShape(Rectangle())
                }
                
                // Share button
                Button(action: {
                    // TODO: Implement share functionality
                }) {
                    Image(systemName: "paperplane")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 50, alignment: .leading)
                .contentShape(Rectangle())
            } else {
                // Reply button (for actual replies)
                if let onReply = onReply {
                    Button(action: onReply) {
                        Image(systemName: "arrow.turn.up.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 50, alignment: .leading)
                    .contentShape(Rectangle())
                }
            }
            
            Spacer()
            
            // Three dots menu (only show if user can delete)
            if let onDelete = onDelete {
                Menu {
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
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

