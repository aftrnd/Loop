import Foundation
import SwiftUI
import FirebaseAuth
import os

/// The feeds under a profile's header.
enum ProfileFeedTab: String, CaseIterable {
    case posts = "Posts"
    case likes = "Likes"
}

@MainActor
@Observable
final class ProfileFeedViewModel {
    private(set) var posts: [Loop] = []
    private(set) var likedPosts: [Loop] = []
    private(set) var isLoadingPosts = false
    private(set) var isLoadingLikes = false
    var errorMessage: String?
    
    let userId: String
    
    private let logger = Logger(subsystem: "com.nejack.Loop", category: "ProfileFeedViewModel")
    
    /// Tabs whose results are loaded. Each tab is fetched once, so switching back to it doesn't refetch.
    @ObservationIgnored private var loadedTabs: Set<ProfileFeedTab> = []
    
    init(userId: String) {
        self.userId = userId
    }
    
    // MARK: - Load Data
    
    /// Loads `tab` unless it is already loaded or loading. Pass `force` to reload a loaded tab.
    func load(_ tab: ProfileFeedTab, force: Bool = false) async {
        guard force || !loadedTabs.contains(tab), !isLoading(tab) else { return }
        
        setLoading(true, for: tab)
        defer { setLoading(false, for: tab) }
        
        do {
            switch tab {
            case .posts:
                posts = try await FirebaseService.shared.getUserLoops(userId: userId)
            case .likes:
                likedPosts = try await FirebaseService.shared.getUserLikedLoops(userId: userId)
            }
            loadedTabs.insert(tab)
        } catch {
            logger.error("Profile \(tab.rawValue, privacy: .public) load failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func isLoading(_ tab: ProfileFeedTab) -> Bool {
        switch tab {
        case .posts: isLoadingPosts
        case .likes: isLoadingLikes
        }
    }
    
    private func setLoading(_ isLoading: Bool, for tab: ProfileFeedTab) {
        switch tab {
        case .posts: isLoadingPosts = isLoading
        case .likes: isLoadingLikes = isLoading
        }
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
            // Revert on error - reload whatever has been loaded
            for tab in loadedTabs {
                await load(tab, force: true)
            }
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

