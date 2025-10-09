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
    
    // Compose state
    @Published var showingCompose = false
    @Published var composeDraft = LoopDraft()
    @Published var isPosting = false
    
    // Optimistic updates tracking
    @Published private(set) var pendingLikeOperations: Set<String> = [] // Loop IDs with pending like/unlike operations
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
            // When appending, just add the new loops
            loops.append(contentsOf: newLoops)
        } else {
            // When replacing, preserve optimistic updates for loops with pending operations
            var mergedLoops: [Loop] = []
            
            for newLoop in newLoops {
                if pendingLikeOperations.contains(newLoop.id) {
                    // This loop has a pending operation - keep the existing optimistic state
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
            
            loops = mergedLoops
        }
        
        lastDocument = documents.last
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
        
        do {
            try await FirebaseService.shared.createLoop(
                content: composeDraft.content,
                media: composeDraft.media,
                isReply: composeDraft.isReply,
                parentLoopId: composeDraft.parentLoopId
            )
            
            // Success - clear the compose state
            hideCompose()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isPosting = false
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
            
            // If operation is still pending after timeout, show error and revert
            if pendingLikeOperations.contains(loop.id) {
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
            
            // Success - cancel timeout and clean up
            timeoutTask.cancel()
            likeTimeoutTasks.removeValue(forKey: loop.id)
            pendingLikeOperations.remove(loop.id)
            print("✅ SUCCESS - Like operation completed for \(loop.id.prefix(8)), pending count: \(pendingLikeOperations.count)")
            
            // Note: The Firestore listener will update with the authoritative server state
            // But we keep our optimistic state until then (handled in processLoopDocuments)
            
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
            
            // Show error message
            errorMessage = "Couldn't update like. Please try again."
        }
    }
    
    // Helper method to update loop likes
    private func updateLoopLikes(loopId: String, currentUserId: String, shouldAdd: Bool) {
        guard let index = loops.firstIndex(where: { $0.id == loopId }) else { return }
        
        var updatedLoop = loops[index]
        var newLikes = updatedLoop.likes
        
        if shouldAdd {
            // Add like
            if !newLikes.contains(currentUserId) {
                newLikes.append(currentUserId)
            }
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
        
        loops[index] = updatedLoop
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
        loops.remove(at: index)
        
        // Perform backend operation
        do {
            try await FirebaseService.shared.deleteLoop(loop.id)
        } catch {
            // REVERT: Operation failed, restore the loop
            loops.insert(deletedLoop, at: min(index, loops.count))
            
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
