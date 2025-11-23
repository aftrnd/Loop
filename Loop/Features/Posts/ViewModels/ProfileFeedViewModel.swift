import Foundation
import SwiftUI
import Combine
import FirebaseAuth

@MainActor
class ProfileFeedViewModel: ObservableObject {
    @Published var posts: [Loop] = []
    @Published var likedPosts: [Loop] = []
    @Published var isLoadingPosts = false
    @Published var isLoadingLikes = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    
    let userId: String
    
    init(userId: String) {
        self.userId = userId
    }
    
    // MARK: - Load Data
    
    func loadUserPosts() async {
        isLoadingPosts = true
        errorMessage = nil
        
        do {
            let loops = try await FirebaseService.shared.getUserLoops(userId: userId)
            posts = loops
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error loading user posts: \(error)")
        }
        
        isLoadingPosts = false
    }
    
    func loadUserLikedPosts() async {
        isLoadingLikes = true
        errorMessage = nil
        
        do {
            let loops = try await FirebaseService.shared.getUserLikedLoops(userId: userId)
            likedPosts = loops
        } catch {
            errorMessage = error.localizedDescription
            print("❌ Error loading user liked posts: \(error)")
        }
        
        isLoadingLikes = false
    }
    
    func refreshPosts() async {
        isRefreshing = true
        await loadUserPosts()
        isRefreshing = false
    }
    
    func refreshLikedPosts() async {
        isRefreshing = true
        await loadUserLikedPosts()
        isRefreshing = false
    }
    
    // MARK: - Helper Methods
    
    func clearError() {
        errorMessage = nil
    }
    
    func isLikedByCurrentUser(_ loop: Loop) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return loop.likes.contains(currentUserId)
    }
    
    func canDeleteLoop(_ loop: Loop) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return loop.authorId == currentUserId
    }
    
    func deleteLoop(_ loop: Loop) async {
        guard canDeleteLoop(loop) else { return }
        
        // Optimistically remove from UI
        if let index = posts.firstIndex(where: { $0.id == loop.id }) {
            posts.remove(at: index)
        }
        if let index = likedPosts.firstIndex(where: { $0.id == loop.id }) {
            likedPosts.remove(at: index)
        }
        
        // Perform backend operation
        do {
            try await FirebaseService.shared.deleteLoop(loop.id)
        } catch {
            // Revert on error - reload data
            await loadUserPosts()
            await loadUserLikedPosts()
            errorMessage = "Couldn't delete post. Please try again."
        }
    }
    
    // MARK: - Like Operations
    
    /// Updates a loop's like state in both posts and likedPosts arrays
    func updateLoopLikeState(loopId: String, isLiked: Bool) {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Update in posts array
        if let index = posts.firstIndex(where: { $0.id == loopId }) {
            var updatedLoop = posts[index]
            var newLikes = updatedLoop.likes
            
            if isLiked {
                if !newLikes.contains(currentUserId) {
                    newLikes.append(currentUserId)
                }
            } else {
                newLikes.removeAll { $0 == currentUserId }
            }
            
            updatedLoop = Loop(
                id: updatedLoop.id,
                authorId: updatedLoop.authorId,
                content: updatedLoop.content,
                media: updatedLoop.media,
                createdAt: updatedLoop.createdAt,
                updatedAt: updatedLoop.updatedAt,
                likes: newLikes,
                replies: updatedLoop.replies,
                isReply: updatedLoop.isReply,
                parentLoopId: updatedLoop.parentLoopId,
                replyToReplyId: updatedLoop.replyToReplyId,
                authorDisplayName: updatedLoop.authorDisplayName,
                authorUsername: updatedLoop.authorUsername,
                authorAvatarURL: updatedLoop.authorAvatarURL,
                authorBadgeType: updatedLoop.authorBadgeType
            )
            
            posts[index] = updatedLoop
        }
        
        // Update in likedPosts array
        if let index = likedPosts.firstIndex(where: { $0.id == loopId }) {
            var updatedLoop = likedPosts[index]
            var newLikes = updatedLoop.likes
            
            if isLiked {
                if !newLikes.contains(currentUserId) {
                    newLikes.append(currentUserId)
                }
            } else {
                newLikes.removeAll { $0 == currentUserId }
            }
            
            updatedLoop = Loop(
                id: updatedLoop.id,
                authorId: updatedLoop.authorId,
                content: updatedLoop.content,
                media: updatedLoop.media,
                createdAt: updatedLoop.createdAt,
                updatedAt: updatedLoop.updatedAt,
                likes: newLikes,
                replies: updatedLoop.replies,
                isReply: updatedLoop.isReply,
                parentLoopId: updatedLoop.parentLoopId,
                replyToReplyId: updatedLoop.replyToReplyId,
                authorDisplayName: updatedLoop.authorDisplayName,
                authorUsername: updatedLoop.authorUsername,
                authorAvatarURL: updatedLoop.authorAvatarURL,
                authorBadgeType: updatedLoop.authorBadgeType
            )
            
            likedPosts[index] = updatedLoop
        }
    }
}

