import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - Threaded Reply Structure
struct ThreadedReply: Identifiable {
    let id: String
    let reply: Loop
    let nestedReplies: [Loop] // Replies to this reply, sorted oldest first
    let indentLevel: Int
    var isExpanded: Bool // For collapsing/expanding nested replies
    
    init(reply: Loop, nestedReplies: [Loop] = [], indentLevel: Int = 0, isExpanded: Bool = false) {
        self.id = reply.id
        self.reply = reply
        self.nestedReplies = nestedReplies
        self.indentLevel = indentLevel
        self.isExpanded = isExpanded
    }
}

@MainActor
class LoopDetailViewModel: ObservableObject {
    @Published var loop: Loop
    @Published var replies: [Loop] = [] // Raw replies from Firebase
    @Published var threadedReplies: [ThreadedReply] = [] // Organized threaded structure
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    
    // Compose state for replies
    @Published var showingCompose = false
    @Published var composeDraft = LoopDraft()
    @Published var isPosting = false
    
    // Optimistic updates tracking for likes
    @Published private(set) var pendingLikeOperations: Set<String> = []
    private var completedLikeOperations: Set<String> = []
    private var likeTimeoutTasks: [String: Task<Void, Never>] = [:]
    private let operationTimeout: TimeInterval = 2.0
    
    // Callback for when replies change (to notify parent feed)
    var onRepliesChanged: (() -> Void)?
    
    private var listener: ListenerRegistration?
    
    init(loop: Loop, onRepliesChanged: (() -> Void)? = nil) {
        self.loop = loop
        self.onRepliesChanged = onRepliesChanged
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Data Loading
    
    func loadReplies() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch all replies for this loop
            replies = try await FirebaseService.shared.getReplies(for: loop.id)
            
            // Organize into threaded structure
            organizeThreadedReplies()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func organizeThreadedReplies() {
        // Separate top-level replies (replies to the POST) from nested replies (replies to replies)
        let topLevelReplies = replies.filter { $0.replyToReplyId == nil }
            .sorted { $0.createdAt > $1.createdAt } // Newest first
        
        var threaded: [ThreadedReply] = []
        
        for topLevelReply in topLevelReplies {
            // Find all replies to this reply
            let nestedReplies = replies.filter { $0.replyToReplyId == topLevelReply.id }
                .sorted { $0.createdAt < $1.createdAt } // Oldest first for nested
            
            // Check if this reply was previously expanded
            let wasExpanded = threadedReplies.first(where: { $0.id == topLevelReply.id })?.isExpanded ?? false
            
            // Add only the top-level reply (nested replies are hidden by default)
            threaded.append(ThreadedReply(
                reply: topLevelReply,
                nestedReplies: nestedReplies,
                indentLevel: 0,
                isExpanded: wasExpanded
            ))
        }
        
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            threadedReplies = threaded
        }
    }
    
    func toggleReplyExpansion(_ replyId: String) {
        if let index = threadedReplies.firstIndex(where: { $0.id == replyId }) {
            var updated = threadedReplies[index]
            updated = ThreadedReply(
                reply: updated.reply,
                nestedReplies: updated.nestedReplies,
                indentLevel: updated.indentLevel,
                isExpanded: !updated.isExpanded
            )
            threadedReplies[index] = updated
        }
    }
    
    func refreshReplies() async {
        isRefreshing = true
        await loadReplies()
        isRefreshing = false
    }
    
    func startListeningForReplies() {
        listener?.remove()
        
        listener = Firestore.firestore()
            .collection("loops")
            .whereField("parentLoopId", isEqualTo: loop.id)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task {
                    await self.processReplyDocuments(documents)
                }
            }
    }
    
    private func processReplyDocuments(_ documents: [QueryDocumentSnapshot]) async {
        var newReplies: [Loop] = []
        
        for doc in documents {
            if let reply = await parseLoopFromDocument(doc) {
                newReplies.append(reply)
            }
        }
        
        // Preserve optimistic states for replies with pending operations
        var mergedReplies: [Loop] = []
        
        for newReply in newReplies {
            let shouldPreserveOptimisticState = pendingLikeOperations.contains(newReply.id) 
                || completedLikeOperations.contains(newReply.id)
            
            if shouldPreserveOptimisticState {
                if let existingReply = replies.first(where: { $0.id == newReply.id }) {
                    mergedReplies.append(existingReply)
                } else {
                    mergedReplies.append(newReply)
                }
            } else {
                mergedReplies.append(newReply)
            }
        }
        
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            replies = mergedReplies
        }
        
        // Re-organize threaded structure
        organizeThreadedReplies()
    }
    
    private func parseLoopFromDocument(_ doc: QueryDocumentSnapshot) async -> Loop? {
        let data = doc.data()
        
        guard let authorId = data["authorId"] as? String,
              let content = data["content"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        // Parse media
        let mediaArray = data["media"] as? [[String: Any]] ?? []
        let media = mediaArray.compactMap { mediaData -> LoopMedia? in
            guard let id = mediaData["id"] as? String,
                  let typeString = mediaData["type"] as? String,
                  let type = LoopMediaType(rawValue: typeString),
                  let url = mediaData["url"] as? String else {
                return nil
            }
            
            return LoopMedia(
                id: id,
                type: type,
                url: url,
                thumbnailURL: mediaData["thumbnailURL"] as? String,
                width: mediaData["width"] as? Double,
                height: mediaData["height"] as? Double
            )
        }
        
        // Fetch author information
        let author = try? await FirebaseService.shared.getUser(withId: authorId)
        
        return Loop(
            id: doc.documentID,
            authorId: authorId,
            content: content,
            media: media,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAtTimestamp.dateValue(),
            likes: data["likes"] as? [String] ?? [],
            replies: data["replies"] as? [String] ?? [],
            isReply: data["isReply"] as? Bool ?? false,
            parentLoopId: data["parentLoopId"] as? String,
            replyToReplyId: data["replyToReplyId"] as? String,
            authorDisplayName: author?.displayName,
            authorUsername: author?.username,
            authorAvatarURL: author?.avatarURL,
            authorBadgeType: author?.badgeType
        )
    }
    
    // MARK: - Compose Actions
    
    func showReplyCompose() {
        composeDraft = LoopDraft()
        composeDraft.isReply = true
        composeDraft.parentLoopId = loop.id
        showingCompose = true
    }
    
    func replyToReply(_ reply: Loop) {
        // Reply to a reply - sets both parent loop and the reply being replied to
        composeDraft = LoopDraft()
        composeDraft.isReply = true
        composeDraft.parentLoopId = loop.id // Root post
        composeDraft.replyToReplyId = reply.id // The reply being replied to
        showingCompose = true
    }
    
    func hideCompose() {
        showingCompose = false
        composeDraft = LoopDraft()
    }
    
    func postReply() async {
        guard composeDraft.isValid, composeDraft.isWithinCharacterLimit else { return }
        
        isPosting = true
        
        do {
            try await FirebaseService.shared.createLoop(
                content: composeDraft.content,
                media: composeDraft.media,
                isReply: composeDraft.isReply,
                parentLoopId: composeDraft.parentLoopId,
                replyToReplyId: composeDraft.replyToReplyId
            )
            
            // Success - clear the compose state
            hideCompose()
            
            // Refresh replies to show the new one
            await loadReplies()
            
            // Notify parent that replies changed
            onRepliesChanged?()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isPosting = false
    }
    
    // MARK: - Like Actions
    
    func toggleLike(for targetLoop: Loop) async {
        guard !pendingLikeOperations.contains(targetLoop.id) else {
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            return 
        }
        
        let isCurrentlyLiked = targetLoop.likes.contains(currentUserId)
        
        pendingLikeOperations.insert(targetLoop.id)
        
        // Update the appropriate loop (main or reply)
        if targetLoop.id == loop.id {
            updateLoopLikes(loopId: targetLoop.id, currentUserId: currentUserId, shouldAdd: !isCurrentlyLiked, isMainLoop: true)
        } else {
            updateLoopLikes(loopId: targetLoop.id, currentUserId: currentUserId, shouldAdd: !isCurrentlyLiked, isMainLoop: false)
        }
        
        // Start timeout task
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(operationTimeout * 1_000_000_000))
            
            if pendingLikeOperations.contains(targetLoop.id) && !completedLikeOperations.contains(targetLoop.id) {
                // Revert the optimistic update
                if targetLoop.id == loop.id {
                    updateLoopLikes(loopId: targetLoop.id, currentUserId: currentUserId, shouldAdd: isCurrentlyLiked, isMainLoop: true)
                } else {
                    updateLoopLikes(loopId: targetLoop.id, currentUserId: currentUserId, shouldAdd: isCurrentlyLiked, isMainLoop: false)
                }
                
                pendingLikeOperations.remove(targetLoop.id)
                likeTimeoutTasks.removeValue(forKey: targetLoop.id)
                
                errorMessage = "Failed to update like. Please check your connection."
            }
        }
        likeTimeoutTasks[targetLoop.id] = timeoutTask
        
        // Perform backend operation
        do {
            if isCurrentlyLiked {
                try await FirebaseService.shared.unlikeLoop(targetLoop.id)
            } else {
                try await FirebaseService.shared.likeLoop(targetLoop.id)
            }
            
            completedLikeOperations.insert(targetLoop.id)
            timeoutTask.cancel()
            likeTimeoutTasks.removeValue(forKey: targetLoop.id)
            
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                pendingLikeOperations.remove(targetLoop.id)
                completedLikeOperations.remove(targetLoop.id)
            }
            
        } catch {
            timeoutTask.cancel()
            likeTimeoutTasks.removeValue(forKey: targetLoop.id)
            
            // Revert the optimistic update
            if targetLoop.id == loop.id {
                updateLoopLikes(loopId: targetLoop.id, currentUserId: currentUserId, shouldAdd: isCurrentlyLiked, isMainLoop: true)
            } else {
                updateLoopLikes(loopId: targetLoop.id, currentUserId: currentUserId, shouldAdd: isCurrentlyLiked, isMainLoop: false)
            }
            
            pendingLikeOperations.remove(targetLoop.id)
            completedLikeOperations.remove(targetLoop.id)
            
            errorMessage = "Couldn't update like. Please try again."
        }
    }
    
    private func updateLoopLikes(loopId: String, currentUserId: String, shouldAdd: Bool, isMainLoop: Bool) {
        if isMainLoop {
            var updatedLoop = loop
            var newLikes = updatedLoop.likes
            
            if shouldAdd {
                newLikes.append(currentUserId)
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
                authorDisplayName: updatedLoop.authorDisplayName,
                authorUsername: updatedLoop.authorUsername,
                authorAvatarURL: updatedLoop.authorAvatarURL,
                authorBadgeType: updatedLoop.authorBadgeType
            )
            
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                loop = updatedLoop
            }
        } else {
            guard let index = replies.firstIndex(where: { $0.id == loopId }) else { return }
            
            var updatedReply = replies[index]
            var newLikes = updatedReply.likes
            
            if shouldAdd {
                newLikes.append(currentUserId)
            } else {
                newLikes.removeAll { $0 == currentUserId }
            }
            
            updatedReply = Loop(
                id: updatedReply.id,
                authorId: updatedReply.authorId,
                content: updatedReply.content,
                media: updatedReply.media,
                createdAt: updatedReply.createdAt,
                updatedAt: updatedReply.updatedAt,
                likes: newLikes,
                replies: updatedReply.replies,
                isReply: updatedReply.isReply,
                parentLoopId: updatedReply.parentLoopId,
                authorDisplayName: updatedReply.authorDisplayName,
                authorUsername: updatedReply.authorUsername,
                authorAvatarURL: updatedReply.authorAvatarURL,
                authorBadgeType: updatedReply.authorBadgeType
            )
            
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                replies[index] = updatedReply
            }
        }
    }
    
    func canDeleteLoop(_ targetLoop: Loop) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return targetLoop.authorId == currentUserId
    }
    
    func deleteLoop(_ targetLoop: Loop) async {
        guard canDeleteLoop(targetLoop) else { return }
        
        if targetLoop.id == loop.id {
            // Can't delete the main loop from detail view - should navigate back
            return
        }
        
        // OPTIMISTIC: Remove reply and all its nested replies, update reply count immediately
        guard let index = replies.firstIndex(where: { $0.id == targetLoop.id }) else { return }
        let deletedReply = replies[index]
        
        // Find all nested replies to this comment (replies where replyToReplyId == targetLoop.id)
        let nestedRepliesToDelete = replies.filter { $0.replyToReplyId == targetLoop.id }
        let deletedNestedReplies = nestedRepliesToDelete
        
        // Update loop's reply count optimistically - remove this reply AND all nested replies
        var updatedLoop = loop
        var newReplies = updatedLoop.replies
        newReplies.removeAll { $0 == targetLoop.id }
        // Also remove all nested replies from the count
        for nestedReply in nestedRepliesToDelete {
            newReplies.removeAll { $0 == nestedReply.id }
        }
        
        updatedLoop = Loop(
            id: updatedLoop.id,
            authorId: updatedLoop.authorId,
            content: updatedLoop.content,
            media: updatedLoop.media,
            createdAt: updatedLoop.createdAt,
            updatedAt: updatedLoop.updatedAt,
            likes: updatedLoop.likes,
            replies: newReplies,
            isReply: updatedLoop.isReply,
            parentLoopId: updatedLoop.parentLoopId,
            replyToReplyId: updatedLoop.replyToReplyId,
            authorDisplayName: updatedLoop.authorDisplayName,
            authorUsername: updatedLoop.authorUsername,
            authorAvatarURL: updatedLoop.authorAvatarURL,
            authorBadgeType: updatedLoop.authorBadgeType
        )
        
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            loop = updatedLoop
            // Remove the deleted reply
            replies.remove(at: index)
            // Remove all nested replies
            replies.removeAll { nestedReply in
                nestedRepliesToDelete.contains { $0.id == nestedReply.id }
            }
            organizeThreadedReplies()
        }
        
        do {
            try await FirebaseService.shared.deleteLoop(targetLoop.id)
            // Notify parent that replies changed
            onRepliesChanged?()
        } catch {
            // REVERT: Restore reply, nested replies, and count on error
            var revertedLoop = loop
            var revertedReplies = revertedLoop.replies
            revertedReplies.append(targetLoop.id)
            // Restore nested replies to the count
            for nestedReply in deletedNestedReplies {
                revertedReplies.append(nestedReply.id)
            }
            
            revertedLoop = Loop(
                id: revertedLoop.id,
                authorId: revertedLoop.authorId,
                content: revertedLoop.content,
                media: revertedLoop.media,
                createdAt: revertedLoop.createdAt,
                updatedAt: revertedLoop.updatedAt,
                likes: revertedLoop.likes,
                replies: revertedReplies,
                isReply: revertedLoop.isReply,
                parentLoopId: revertedLoop.parentLoopId,
                replyToReplyId: revertedLoop.replyToReplyId,
                authorDisplayName: revertedLoop.authorDisplayName,
                authorUsername: revertedLoop.authorUsername,
                authorAvatarURL: revertedLoop.authorAvatarURL,
                authorBadgeType: revertedLoop.authorBadgeType
            )
            
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                loop = revertedLoop
                replies.insert(deletedReply, at: min(index, replies.count))
                // Restore nested replies
                replies.append(contentsOf: deletedNestedReplies)
                organizeThreadedReplies()
            }
            
            errorMessage = "Couldn't delete comment. Please try again."
        }
    }
    
    func isLikedByCurrentUser(_ targetLoop: Loop) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return targetLoop.likes.contains(currentUserId)
    }
    
    func clearError() {
        errorMessage = nil
    }
}

