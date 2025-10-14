import SwiftUI

struct ReplyCardView: View {
    let reply: Loop
    let isLiked: Bool
    let indentLevel: Int // 0 = top-level reply, 1+ = nested
    let onLike: () -> Void
    let onReply: (() -> Void)? // New: reply to this reply
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    
    @State private var showingFullText = false
    
    private let maxPreviewLength = 280
    private let cardCornerRadius: CGFloat = 12
    private let leftPadding: CGFloat = 10 // Match main post left padding
    
    // Clean, subtle indent for nested replies (like Reddit/Twitter)
    private var totalIndent: CGFloat {
        leftPadding + (CGFloat(indentLevel) * 32) // 32px per nesting level for clean look
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left indicator line (white/subtle)
            Rectangle()
                .fill(Color.white.opacity(0.15)) // Subtle white line for all replies
                .frame(width: 2)
                .padding(.leading, totalIndent)
                .padding(.trailing, 10) // Spacing between line and content
            
            VStack(alignment: .leading, spacing: 10) {
                // Header with author info
                HStack(spacing: 0) {
                    UserInfoHeader(
                        avatarURL: reply.authorAvatarURL,
                        displayName: reply.displayAuthorName,
                        username: reply.authorUsername,
                        badgeType: reply.authorBadgeType,
                        onAvatarTap: onAvatarTap,
                        avatarSize: 32 // Slightly smaller for replies
                    )
                    
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
                
                // Content
                if !reply.content.isEmpty {
                    let shouldTruncate = reply.content.count > maxPreviewLength && !showingFullText
                    let displayText = shouldTruncate ? String(reply.content.prefix(maxPreviewLength)) + "..." : reply.content
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayText)
                            .font(.subheadline) // Slightly smaller text for replies
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
                
                // Action buttons (simplified for replies)
                HStack(spacing: 0) {
                    // Like button
                    Button(action: onLike) {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(isLiked ? .red : .secondary)
                            
                            if reply.likeCount > 0 {
                                Text(reply.likeCount > 99 ? "99+" : "\(reply.likeCount)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(width: 45, alignment: .leading)
                    .contentShape(Rectangle())
                    
                    // Reply button (if provided)
                    if let onReply = onReply {
                        Button(action: onReply) {
                            Image(systemName: "arrow.turn.up.left")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 45, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    
                    Spacer()
                    
                    // Three dots menu (only show if user can delete)
                    if let onDelete = onDelete {
                        Menu {
                            Button("Delete", role: .destructive, action: onDelete)
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
            .padding(.trailing, 10) // Match main post right padding
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            // Sample top-level reply
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
                onLike: {},
                onReply: {},
                onDelete: {},
                onAvatarTap: {}
            )
            
            Divider()
                .padding(.horizontal)
            
            // Sample nested reply (reply to reply)
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
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {}
            )
            
            Divider()
                .padding(.horizontal)
            
            // Sample top-level reply
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
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: {}
            )
        }
        .padding(.vertical, 16)
    }
    .background(Color(.systemGroupedBackground))
}

