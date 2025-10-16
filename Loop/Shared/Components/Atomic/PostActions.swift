import SwiftUI
import Combine

/// Atomic component: Post action buttons (like, comment, share, menu)
/// Single source of truth for all post action bars
struct PostActions: View {
    // MARK: - Properties
    
    // Like action
    let isLiked: Bool
    let likeCount: Int
    let onLike: () -> Void
    
    // Comment action
    let commentCount: Int
    let onComment: (() -> Void)?
    
    // Share action
    let onShare: (() -> Void)?
    
    // Menu action
    let onDelete: (() -> Void)?
    
    // Debug overlay
    let showDebugOverlay: Bool
    
    // Animation state
    @StateObject private var animationState = PostActionsAnimationState()
    
    init(
        isLiked: Bool,
        likeCount: Int,
        onLike: @escaping () -> Void,
        commentCount: Int,
        onComment: (() -> Void)?,
        onShare: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        showDebugOverlay: Bool = false
    ) {
        self.isLiked = isLiked
        self.likeCount = likeCount
        self.onLike = onLike
        self.commentCount = commentCount
        self.onComment = onComment
        self.onShare = onShare
        self.onDelete = onDelete
        self.showDebugOverlay = showDebugOverlay
    }
    
    // MARK: - Body
    var body: some View {
        HStack(alignment: .center, spacing: CardLayoutConstants.actionButtonSpacing) {
            // Like button
            likeButton
            
            // Comment button
            if let onComment = onComment {
                commentButton(action: onComment)
            }
            
            // Share button
            if let onShare = onShare {
                shareButton(action: onShare)
            }
            
            Spacer()
            
            // Menu (delete)
            if let onDelete = onDelete {
                menuButton(onDelete: onDelete)
            }
        }
        .frame(maxWidth: .infinity)
        .background(showDebugOverlay ? Color.orange.opacity(0.1) : Color.clear) // Debug: Actions background
        .overlay(
            Group {
                if showDebugOverlay {
                    Rectangle()
                        .stroke(Color.red, lineWidth: 1)
                }
            }
        )
        .overlay(alignment: .bottomLeading) {
            // Heart particle animation overlay
            GeometryReader { geo in
                HeartParticleAnimationView(
                    iconSize: CardLayoutConstants.actionButtonIconSize,
                    triggerID: animationState.particleTriggerID
                )
                .frame(width: 200, height: 200)
                .position(
                    x: CardLayoutConstants.actionButtonWidth / 2,
                    y: CardLayoutConstants.actionButtonHeight / 2
                )
                .allowsHitTesting(false)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var likeButton: some View {
        Button(action: {
            // Trigger animation
            animationState.triggerHeartAnimation()
            
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Action
            onLike()
        }) {
            HStack(spacing: 4) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                    .foregroundColor(isLiked ? .red : .secondary)
                    .scaleEffect(animationState.heartScale)
                    .rotationEffect(.degrees(animationState.heartRotation))
                
                if likeCount > 0 {
                    Text(likeCount > 99 ? "99+" : "\(likeCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
    
    private func commentButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "bubble.left")
                    .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                    .foregroundColor(.secondary)
                
                if commentCount > 0 {
                    Text(commentCount > 99 ? "99+" : "\(commentCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
    
    private func shareButton(action: @escaping () -> Void) -> some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            Image(systemName: "paperplane")
                .font(.system(size: CardLayoutConstants.actionButtonIconSize, weight: .medium))
                .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .frame(width: CardLayoutConstants.actionButtonWidth, alignment: .leading)
        .contentShape(Rectangle())
    }
    
    private func menuButton(onDelete: @escaping () -> Void) -> some View {
        Menu {
            Button("Delete", role: .destructive) {
                // Haptic feedback
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

// MARK: - Animation State Manager
class PostActionsAnimationState: ObservableObject {
    @Published var heartScale: CGFloat = 1.0
    @Published var heartRotation: Double = 0
    @Published var particleTriggerID = UUID()
    
    private var animationTask: Task<Void, Never>?
    
    func triggerHeartAnimation() {
        // Cancel any existing animation
        animationTask?.cancel()
        
        // Start new animation
        animationTask = Task { @MainActor in
            // Scale up
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                heartScale = 1.5
            }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                heartRotation = 12
            }
            
            // Trigger particle animation
            particleTriggerID = UUID()
            
            // Wait and scale down
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15 seconds
            
            guard !Task.isCancelled else { return }
            
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                heartScale = 1.0
                heartRotation = 0
            }
        }
    }
    
    deinit {
        animationTask?.cancel()
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        // Liked post with counts
        PostActions(
            isLiked: true,
            likeCount: 42,
            onLike: {},
            commentCount: 8,
            onComment: {},
            onShare: {},
            onDelete: {}
        )
        .padding()
        .background(Color(.systemBackground))
        
        // Unliked post
        PostActions(
            isLiked: false,
            likeCount: 0,
            onLike: {},
            commentCount: 0,
            onComment: {},
            onShare: nil,
            onDelete: nil
        )
        .padding()
        .background(Color(.systemBackground))
        
        // High counts
        PostActions(
            isLiked: true,
            likeCount: 150,
            onLike: {},
            commentCount: 99,
            onComment: {},
            onShare: {},
            onDelete: {}
        )
        .padding()
        .background(Color(.systemBackground))
    }
    .background(Color(.systemGroupedBackground))
}

