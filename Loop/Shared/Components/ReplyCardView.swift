import SwiftUI

struct ReplyCardView: View {
    let reply: Loop
    let isLiked: Bool
    let indentLevel: Int // 0 = top-level reply, 1+ = nested
    let nestedReplyCount: Int // Number of nested replies
    let isExpanded: Bool // Whether nested replies are shown
    let onLike: () -> Void
    let onReply: (() -> Void)? // Reply to this reply
    let onToggleExpanded: (() -> Void)? // Toggle nested replies visibility
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    
    @State private var showingFullText = false
    
    private let maxPreviewLength = 280
    private let cardCornerRadius: CGFloat = 12
    
    // Clean, subtle indent for nested replies (like Reddit/Twitter)
    private var totalIndent: CGFloat {
        CGFloat(indentLevel) * 40 // 40px per nesting level
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                // Header row: Avatar + Name/Badge/Time
                HStack(alignment: .top, spacing: 12) {
                    // Avatar
                    avatarView
                        .frame(width: 56)
                    
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
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                }
                
                // Content - aligned with avatar's left edge, shifts right to align with name when expanded
                if !reply.content.isEmpty {
                    contentView
                        .padding(.leading, indentLevel == 0 && isExpanded && nestedReplyCount > 0 ? 68 : 0) // 56px avatar + 12px spacing
                }
                
                // Action buttons - aligned with avatar's left edge, shifts right to align with name when expanded
                actionButtonsView
                    .padding(.leading, indentLevel == 0 && isExpanded && nestedReplyCount > 0 ? 68 : 0) // 56px avatar + 12px spacing
            }
            .padding(.vertical, 12)
            
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
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                } placeholder: {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 56)
                }
            } else {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Text(String((reply.displayAuthorName ?? "?").prefix(1)).uppercased())
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
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
            
            // Reply button (if provided)
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
        .padding(.top, 4)
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

