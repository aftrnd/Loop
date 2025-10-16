import SwiftUI

/// Composite component: Reply post with optional indentation and conversation line
/// Extends PostCard with reply-specific features (indentation, conversation lines)
struct ReplyPost: View {
    // MARK: - Properties
    let reply: Loop
    let isLiked: Bool
    let indentLevel: Int // 0 = no indent, 1+ = nested reply
    let showConversationLine: Bool // Show connecting line to parent
    let onLike: () -> Void
    let onReply: () -> Void
    let onDelete: (() -> Void)?
    let onAvatarTap: (() -> Void)?
    
    // MARK: - Computed Properties
    
    /// Calculate indent offset based on level
    private var indentOffset: CGFloat {
        CGFloat(indentLevel) * CardLayoutConstants.contentShift
    }
    
    // MARK: - Body
    var body: some View {
        HStack(spacing: 0) {
            // Conversation line (if needed)
            if showConversationLine && indentLevel > 0 {
                conversationLine
            }
            
            // Main content
            VStack(spacing: 0) {
                // Header
                PostHeader(
                    avatarURL: reply.authorAvatarURL,
                    displayName: reply.displayAuthorName,
                    username: reply.authorUsername,
                    badgeType: reply.authorBadgeType,
                    timestamp: reply.timeAgoString,
                    onAvatarTap: onAvatarTap
                )
                .padding(.bottom, CardLayoutConstants.headerBottomSpacing)
                
                // Content (text + media)
                PostContent(
                    text: reply.content,
                    media: reply.media
                )
                .padding(.bottom, CardLayoutConstants.contentToActionsSpacing)
                
                // Actions (different from main post - shows reply icon instead of comment)
                replyActionsView
            }
            .padding(.horizontal, CardLayoutConstants.horizontalPadding)
            .padding(.top, CardLayoutConstants.topPadding)
            .padding(.bottom, CardLayoutConstants.bottomPadding)
            .padding(.leading, indentOffset) // Indent based on level
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Subviews
    
    private var conversationLine: some View {
        VStack {
            Rectangle()
                .fill(CardLayoutConstants.conversationLineColor)
                .frame(width: CardLayoutConstants.conversationLineWidth)
        }
        .padding(.leading, CardLayoutConstants.horizontalPadding + (CardLayoutConstants.avatarSize / 2))
    }
    
    private var replyActionsView: some View {
        HStack(spacing: CardLayoutConstants.actionButtonSpacing) {
            // Like button
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onLike()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
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
            .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .leading)
            .contentShape(Rectangle())
            
            // Reply button (different icon for replies)
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                onReply()
            }) {
                Image(systemName: "arrow.turn.up.left")
                    .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .leading)
            .contentShape(Rectangle())
            
            Spacer()
            
            // Delete menu
            if let onDelete = onDelete {
                Menu {
                    Button("Delete", role: .destructive) {
                        let impactFeedback = UINotificationFeedbackGenerator()
                        impactFeedback.notificationOccurred(.warning)
                        onDelete()
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: 0) {
            // Main post
            PostCard(
                loop: Loop(
                    authorId: "user1",
                    content: "This is the main post that people are replying to.",
                    authorDisplayName: "John Doe",
                    authorUsername: "johndoe",
                    authorBadgeType: .verified
                ),
                isLiked: false,
                onLike: {},
                onComment: {},
                onShare: {},
                onDelete: {},
                onAvatarTap: {}
            )
            .padding(.horizontal)
            
            PostDivider()
            
            // Level 0 reply (no indent)
            ReplyPost(
                reply: Loop(
                    authorId: "user2",
                    content: "This is a direct reply to the main post.",
                    isReply: true,
                    parentLoopId: "main",
                    authorDisplayName: "Jane Smith",
                    authorUsername: "janesmith",
                    authorBadgeType: .premium
                ),
                isLiked: false,
                indentLevel: 0,
                showConversationLine: false,
                onLike: {},
                onReply: {},
                onDelete: {},
                onAvatarTap: {}
            )
            .padding(.horizontal)
            
            PostDivider()
            
            // Level 1 reply (indented with line)
            ReplyPost(
                reply: Loop(
                    authorId: "user3",
                    content: "This is a nested reply - notice the indent and conversation line.",
                    isReply: true,
                    parentLoopId: "main",
                    replyToReplyId: "reply1",
                    authorDisplayName: "Mike Johnson",
                    authorUsername: "mikej",
                    authorBadgeType: nil
                ),
                isLiked: true,
                indentLevel: 1,
                showConversationLine: true,
                onLike: {},
                onReply: {},
                onDelete: nil,
                onAvatarTap: nil
            )
            .padding(.horizontal)
            
            PostDivider()
            
            // Another level 0 reply
            ReplyPost(
                reply: Loop(
                    authorId: "user4",
                    content: "Another top-level reply.",
                    isReply: true,
                    parentLoopId: "main",
                    authorDisplayName: "Sarah Wilson",
                    authorUsername: "sarahw",
                    authorBadgeType: .verified
                ),
                isLiked: false,
                indentLevel: 0,
                showConversationLine: false,
                onLike: {},
                onReply: {},
                onDelete: {},
                onAvatarTap: {}
            )
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
    .background(Color(.systemGroupedBackground))
}

