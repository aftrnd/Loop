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
    
    private let currentUserId = Auth.auth().currentUser?.uid
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
            errorMessage = tab == .posts ? "Couldn't load posts. Please try again." : "Couldn't load likes. Please try again."
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
        guard let currentUserId else { return false }
        return loop.likes.contains(currentUserId)
    }
    
    func canDeleteLoop(_ loop: Loop) -> Bool {
        guard let currentUserId else { return false }
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
    
    /// Flips the like locally, then writes it, and reverts if the write fails, as the home feed does.
    /// Repeat taps read the current state rather than the row's captured copy, so they alternate.
    func toggleLike(for loop: Loop) async {
        guard let currentUserId else { return }
        
        let current = posts.first { $0.id == loop.id } ?? likedPosts.first { $0.id == loop.id } ?? loop
        let wasLiked = current.likes.contains(currentUserId)
        setLiked(!wasLiked, loopId: loop.id, userId: currentUserId)
        
        // Your own Likes tab gains or loses this post, so refetch it the next time it is shown
        if userId == currentUserId {
            loadedTabs.remove(.likes)
        }
        
        do {
            if wasLiked {
                try await FirebaseService.shared.unlikeLoop(loop.id)
            } else {
                try await FirebaseService.shared.likeLoop(loop.id)
            }
        } catch {
            logger.error("Like change failed: \(error.localizedDescription, privacy: .public)")
            setLiked(wasLiked, loopId: loop.id, userId: currentUserId)
            errorMessage = "Couldn't update like. Please try again."
        }
    }
    
    /// Sets the like in both lists. Animated, as in the home feed, so the heart morphs and the count rolls.
    private func setLiked(_ liked: Bool, loopId: String, userId: String) {
        withAnimation(.snappy(duration: 0.3)) {
            for index in posts.indices where posts[index].id == loopId && posts[index].likes.contains(userId) != liked {
                if liked {
                    posts[index].likes.append(userId)
                } else {
                    posts[index].likes.removeAll { $0 == userId }
                }
            }
            for index in likedPosts.indices where likedPosts[index].id == loopId && likedPosts[index].likes.contains(userId) != liked {
                if liked {
                    likedPosts[index].likes.append(userId)
                } else {
                    likedPosts[index].likes.removeAll { $0 == userId }
                }
            }
        }
    }
}

