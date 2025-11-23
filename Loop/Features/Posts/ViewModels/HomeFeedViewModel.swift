import Foundation
import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class HomeFeedViewModel: ObservableObject {
    @Published var loops: [Loop] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var errorMessage: String?
    @Published var hasMoreContent = true
    
    // Reply previews for each loop
    @Published var replyPreviews: [String: [Loop]] = [:] // loopId -> reply previews
    
    // Compose state
    @Published var showingCompose = false
    @Published var composeDraft = LoopDraft()
    @Published var isPosting = false
    
    // Optimistic updates tracking
    @Published private(set) var pendingLikeOperations: Set<String> = [] // Loop IDs with pending like/unlike operations
    private var completedLikeOperations: Set<String> = [] // Loop IDs that completed successfully (in grace period)
    private var likeTimeoutTasks: [String: Task<Void, Never>] = [:] // Timeout tasks for each operation
    private let operationTimeout: TimeInterval = 2.0 // Show error after 2 seconds
    
    private var lastDocument: DocumentSnapshot?
    private var listener: ListenerRegistration?
    private let pageSize = 20
    
    init() {
        startListening()
    }
    
    deinit {
        listener?.remove()
    }
    
    // MARK: - Feed Management
    
    func startListening() {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Only show loading spinner if not currently refreshing and list is empty
        if !isRefreshing && loops.isEmpty {
            isLoading = true
        }
        
        // Listen to loops from users that the current user follows
        // For now, we'll show all public loops, but in production you'd filter by following
        listener = Firestore.firestore()
            .collection("loops")
            .whereField("isReply", isEqualTo: false) // Only show main loops, not replies
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    self.isLoading = false
                    return
                }
                
                Task {
                    await self.processLoopDocuments(documents)
                    self.isLoading = false
                }
            }
    }
    
    func refreshFeed() async {
        isRefreshing = true
        lastDocument = nil
        hasMoreContent = true
        
        // Restart the listener to get fresh data
        listener?.remove()
        
        // Wait for fresh data to load before completing refresh
        do {
            let snapshot = try await Firestore.firestore()
                .collection("loops")
                .whereField("isReply", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .limit(to: pageSize)
                .getDocuments()
            
            await processLoopDocuments(snapshot.documents)
            
            // Now restart the listener for real-time updates
            startListening()
        } catch {
            errorMessage = error.localizedDescription
            // Still restart listener even on error
            startListening()
        }
        
        isRefreshing = false
    }
    
    func loadMoreContent() async {
        guard !isLoading, hasMoreContent, let lastDoc = lastDocument else { return }
        
        isLoading = true
        
        do {
            let snapshot = try await Firestore.firestore()
                .collection("loops")
                .whereField("isReply", isEqualTo: false)
                .order(by: "createdAt", descending: true)
                .start(afterDocument: lastDoc)
                .limit(to: pageSize)
                .getDocuments()
            
            if snapshot.documents.isEmpty {
                hasMoreContent = false
            } else {
                await processLoopDocuments(snapshot.documents, append: true)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func processLoopDocuments(_ documents: [QueryDocumentSnapshot], append: Bool = false) async {
        var newLoops: [Loop] = []
        
        for doc in documents {
            if let loop = await parseLoopFromDocument(doc) {
                newLoops.append(loop)
            }
        }
        
        if append {
            // When appending, just add the new loops (no animation needed for loading more)
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                loops.append(contentsOf: newLoops)
            }
        } else {
            // When replacing, preserve optimistic updates for loops with pending operations
            var mergedLoops: [Loop] = []
            
            for newLoop in newLoops {
                // Preserve optimistic state if operation is pending OR completed (during grace period)
                let shouldPreserveOptimisticState = pendingLikeOperations.contains(newLoop.id) 
                    || completedLikeOperations.contains(newLoop.id)
                
                if shouldPreserveOptimisticState {
                    // This loop has an active operation - keep the existing optimistic state
                    if let existingLoop = loops.first(where: { $0.id == newLoop.id }) {
                        mergedLoops.append(existingLoop)
                        print("🔒 PRESERVED optimistic state for loop \(newLoop.id.prefix(8)) during listener update")
                    } else {
                        // New loop, but somehow has pending operation (shouldn't happen)
                        mergedLoops.append(newLoop)
                    }
                } else {
                    // No pending operation - use the fresh data from the server
                    mergedLoops.append(newLoop)
                }
            }
            
            // Disable animations to prevent flickering during state updates
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                loops = mergedLoops
            }
        }
        
        lastDocument = documents.last
        
        // Fetch reply previews for loops with replies
        await fetchReplyPreviewsForLoops(newLoops)
    }
    
    private func fetchReplyPreviewsForLoops(_ loops: [Loop]) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            print("❌ DEBUG: No current user ID, can't fetch reply previews")
            return 
        }
        
        // Get current user's following list
        let currentUser = try? await FirebaseService.shared.getUser(withId: currentUserId)
        let followingIds = currentUser?.following ?? []
        
        print("👥 DEBUG: Current user is following \(followingIds.count) users: \(followingIds)")
        
        for loop in loops {
            // Only fetch if loop has replies
            guard loop.replyCount > 0 else {
                print("🔍 DEBUG: Loop \(loop.id.prefix(8)) has no replies (replyCount: \(loop.replyCount)), skipping")
                continue
            }
            
            print("🔍 DEBUG: Loop \(loop.id.prefix(8)) has \(loop.replyCount) replies, fetching...")
            
            do {
                // Fetch replies (already sorted newest first from Firestore)
                let replies = try await FirebaseService.shared.getReplies(for: loop.id)
                
                print("🔍 DEBUG: Fetched \(replies.count) total replies for loop \(loop.id.prefix(8))")
                
                // Log each reply author
                for (index, reply) in replies.enumerated() {
                    print("   Reply \(index + 1): from \(reply.authorDisplayName ?? "unknown") (ID: \(reply.authorId.prefix(8)))")
                }
                
                // Filter to only show replies from:
                // 1. Users you're following, OR
                // 2. Yourself (even though you don't follow yourself)
                // 3. MUST be a top-level reply (not a reply to a comment)
                let relevantReplies = replies.filter { reply in
                    let isFollowing = followingIds.contains(reply.authorId)
                    let isYou = reply.authorId == currentUserId
                    let isTopLevel = reply.replyToReplyId == nil
                    print("   Checking reply from \(reply.authorDisplayName ?? "unknown"): isFollowing=\(isFollowing), isYou=\(isYou), isTopLevel=\(isTopLevel)")
                    return (isFollowing || isYou) && isTopLevel
                }
                
                print("🔍 DEBUG: Found \(relevantReplies.count) relevant replies for loop \(loop.id.prefix(8))")
                
                // Only show the most recent relevant reply (max 1)
                if let mostRecentRelevantReply = relevantReplies.first {
                    print("✅ DEBUG: Showing reply preview from \(mostRecentRelevantReply.displayAuthorName) for loop \(loop.id.prefix(8))")
                    print("✅ DEBUG: Reply content: \(mostRecentRelevantReply.content.prefix(50))...")
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        replyPreviews[loop.id] = [mostRecentRelevantReply]
                        print("✅ DEBUG: Updated replyPreviews dict, now has \(replyPreviews.count) entries")
                    }
                } else {
                    print("❌ DEBUG: No relevant replies to show for loop \(loop.id.prefix(8))")
                }
            } catch {
                print("❌ Error fetching reply previews for loop \(loop.id.prefix(8)): \(error)")
            }
        }
        
        print("📊 DEBUG: Final replyPreviews dictionary has \(replyPreviews.count) entries")
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
    
    func showCompose() {
        composeDraft = LoopDraft()
        showingCompose = true
    }
    
    func hideCompose() {
        showingCompose = false
        composeDraft = LoopDraft()
    }
    
    func postLoop() async {
        guard composeDraft.isValid, composeDraft.isWithinCharacterLimit else { return }
        
        isPosting = true
        let isReply = composeDraft.isReply
        let parentLoopId = composeDraft.parentLoopId
        
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
            
            // If this was a reply, refresh the reply preview for that loop
            if isReply, let parentId = parentLoopId {
                await refreshReplyPreviewForLoop(parentId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isPosting = false
    }
    
    func refreshReplyPreviewForLoop(_ loopId: String) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        // Get current user's following list
        let currentUser = try? await FirebaseService.shared.getUser(withId: currentUserId)
        let followingIds = currentUser?.following ?? []
        
        do {
            // Fetch replies (already sorted newest first from Firestore)
            let replies = try await FirebaseService.shared.getReplies(for: loopId)
            
            print("🔍 DEBUG: Fetched \(replies.count) total replies for loop \(loopId)")
            
            // If no replies, clear the preview
            if replies.isEmpty {
                print("❌ DEBUG: No replies found, clearing preview")
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    replyPreviews.removeValue(forKey: loopId)
                }
                return
            }
            
            // Filter to only show replies from:
            // 1. Users you're following, OR
            // 2. Yourself (even though you don't follow yourself)
            // 3. MUST be a top-level reply (not a reply to a comment)
            let relevantReplies = replies.filter { reply in
                let isFollowing = followingIds.contains(reply.authorId)
                let isYou = reply.authorId == currentUserId
                let isTopLevel = reply.replyToReplyId == nil
                print("🔍 DEBUG: Reply from \(reply.authorDisplayName ?? "unknown") - isFollowing: \(isFollowing), isYou: \(isYou), isTopLevel: \(isTopLevel)")
                return (isFollowing || isYou) && isTopLevel
            }
            
            print("🔍 DEBUG: Found \(relevantReplies.count) relevant replies")
            
            // Only show the most recent relevant reply (max 1)
            if let mostRecentRelevantReply = relevantReplies.first {
                print("✅ DEBUG: Showing reply preview from \(mostRecentRelevantReply.authorDisplayName ?? "unknown")")
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    replyPreviews[loopId] = [mostRecentRelevantReply]
                }
            } else {
                // No relevant replies, clear preview
                print("❌ DEBUG: No relevant replies to show, clearing preview")
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    replyPreviews.removeValue(forKey: loopId)
                }
            }
        } catch {
            print("❌ Error fetching reply preview for loop \(loopId): \(error)")
        }
    }
    
    // MARK: - Loop Actions
    
    func toggleLike(for loop: Loop) async {
        // Prevent duplicate operations on the same loop
        guard !pendingLikeOperations.contains(loop.id) else {
            print("⛔️ BLOCKED - Operation already pending for \(loop.id.prefix(8))")
            return
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            return 
        }
        
        let isCurrentlyLiked = loop.likes.contains(currentUserId)
        
        // Mark operation as pending
        pendingLikeOperations.insert(loop.id)
        print("🔒 STARTED like operation for \(loop.id.prefix(8)), isPending count: \(pendingLikeOperations.count)")
        
        // OPTIMISTIC UPDATE: Update UI immediately
        updateLoopLikes(loopId: loop.id, currentUserId: currentUserId, shouldAdd: !isCurrentlyLiked)
        
        // Start timeout task
        let timeoutTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(operationTimeout * 1_000_000_000))
            
            // Check if still pending AND not completed (completed operations are in grace period)
            if pendingLikeOperations.contains(loop.id) && !completedLikeOperations.contains(loop.id) {
                print("⏱️ TIMEOUT - Like operation for \(loop.id.prefix(8)) took too long")
                
                // Revert the optimistic update
                updateLoopLikes(loopId: loop.id, currentUserId: currentUserId, shouldAdd: isCurrentlyLiked)
                
                // Clean up
                pendingLikeOperations.remove(loop.id)
                likeTimeoutTasks.removeValue(forKey: loop.id)
                
                // Show error
                errorMessage = "Failed to update like. Please check your connection."
            }
        }
        likeTimeoutTasks[loop.id] = timeoutTask
        
        // Perform backend operation
        do {
            if isCurrentlyLiked {
                try await FirebaseService.shared.unlikeLoop(loop.id)
            } else {
                try await FirebaseService.shared.likeLoop(loop.id)
            }
            
            // Success - mark as completed immediately
            completedLikeOperations.insert(loop.id)
            timeoutTask.cancel()
            likeTimeoutTasks.removeValue(forKey: loop.id)
            print("✅ SUCCESS - Like operation completed for \(loop.id.prefix(8)), pending count: \(pendingLikeOperations.count)")
            
            // Keep operation "pending" for a grace period to let Firestore listener catch up
            // This prevents stale listener events from overwriting our optimistic state
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000) // 500ms grace period
                pendingLikeOperations.remove(loop.id)
                completedLikeOperations.remove(loop.id)
                print("🔓 RELEASED - Removed \(loop.id.prefix(8)) from pending after grace period, count: \(pendingLikeOperations.count)")
            }
            
            // Note: The Firestore listener will update with the authoritative server state
            // During the grace period, our optimistic state is protected from stale updates
            
        } catch {
            // REVERT: Operation failed
            print("❌ ERROR - Like operation failed for \(loop.id.prefix(8)): \(error.localizedDescription)")
            
            // Cancel timeout task
            timeoutTask.cancel()
            likeTimeoutTasks.removeValue(forKey: loop.id)
            
            // Revert the optimistic update
            updateLoopLikes(loopId: loop.id, currentUserId: currentUserId, shouldAdd: isCurrentlyLiked)
            
            // Clean up
            pendingLikeOperations.remove(loop.id)
            completedLikeOperations.remove(loop.id)
            
            // Show error message
            errorMessage = "Couldn't update like. Please try again."
        }
    }
    
    // Helper method to update loop likes
    private func updateLoopLikes(loopId: String, currentUserId: String, shouldAdd: Bool) {
        guard let index = loops.firstIndex(where: { $0.id == loopId }) else { return }
        
        var updatedLoop = loops[index]
        var newLikes = updatedLoop.likes
        
        // Check if update is actually needed
        let alreadyLiked = newLikes.contains(currentUserId)
        if shouldAdd && alreadyLiked {
            // Already liked, no change needed
            print("⚠️ SKIP - Loop \(loopId.prefix(8)) already liked")
            return
        } else if !shouldAdd && !alreadyLiked {
            // Already not liked, no change needed
            print("⚠️ SKIP - Loop \(loopId.prefix(8)) already not liked")
            return
        }
        
        if shouldAdd {
            // Add like
            newLikes.append(currentUserId)
        } else {
            // Remove like
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
        
        // Update without animation to prevent flicker
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            loops[index] = updatedLoop
        }
    }
    
    func replyToLoop(_ loop: Loop) {
        composeDraft = LoopDraft()
        composeDraft.isReply = true
        composeDraft.parentLoopId = loop.id
        showingCompose = true
    }
    
    func canDeleteLoop(_ loop: Loop) -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        return loop.authorId == currentUserId
    }
    
    func deleteLoop(_ loop: Loop) async {
        guard canDeleteLoop(loop) else { return }
        
        // OPTIMISTIC UPDATE: Remove from UI immediately
        guard let index = loops.firstIndex(where: { $0.id == loop.id }) else { return }
        let deletedLoop = loops[index]
        
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            loops.remove(at: index)
            // Also clear any reply previews for this loop
            replyPreviews.removeValue(forKey: loop.id)
        }
        
        // Perform backend operation
        do {
            try await FirebaseService.shared.deleteLoop(loop.id)
        } catch {
            // REVERT: Operation failed, restore the loop
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                loops.insert(deletedLoop, at: min(index, loops.count))
            }
            
            // Re-fetch reply preview if it had one
            if deletedLoop.replyCount > 0 {
                Task {
                    await fetchReplyPreviewsForLoops([deletedLoop])
                }
            }
            
            // Show error message
            errorMessage = "Couldn't delete post. Please try again."
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
}
