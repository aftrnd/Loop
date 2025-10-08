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
    private var likeOperationCooldowns: [String: Date] = [:] // Loop IDs with cooldown timestamp
    private let cooldownDuration: TimeInterval = 0.3 // 300ms cooldown between operations
    
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
            loops.append(contentsOf: newLoops)
        } else {
            loops = newLoops
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
    
    // Synchronously start a like operation (returns false if already pending or in cooldown)
    func startLikeOperation(for loopId: String) -> Bool {
        let isPending = pendingLikeOperations.contains(loopId)
        
        // Check cooldown period
        if let lastOperationTime = likeOperationCooldowns[loopId] {
            let timeSinceLastOp = Date().timeIntervalSince(lastOperationTime)
            if timeSinceLastOp < cooldownDuration {
                let remainingCooldown = cooldownDuration - timeSinceLastOp
                print("⏱️ COOLDOWN - \(loopId.prefix(8)) needs \(Int(remainingCooldown * 1000))ms more")
                return false
            }
        }
        
        print("🔍 startLikeOperation - Loop: \(loopId.prefix(8)), isPending: \(isPending), pendingCount: \(pendingLikeOperations.count)")
        
        guard !isPending else { 
            print("⛔️ BLOCKED - Operation already pending for \(loopId.prefix(8))")
            return false 
        }
        
        pendingLikeOperations.insert(loopId)
        print("🔒 LOCKED - Added \(loopId.prefix(8)) to pending set, new count: \(pendingLikeOperations.count)")
        return true
    }
    
    func toggleLike(for loop: Loop) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { 
            // Release lock if we can't proceed
            pendingLikeOperations.remove(loop.id)
            return 
        }
        
        let isCurrentlyLiked = loop.likes.contains(currentUserId)
        
        // OPTIMISTIC UPDATE: Update UI immediately
        if let index = loops.firstIndex(where: { $0.id == loop.id }) {
            var updatedLoop = loops[index]
            
            if isCurrentlyLiked {
                // Remove like optimistically
                var newLikes = updatedLoop.likes
                newLikes.removeAll { $0 == currentUserId }
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
            } else {
                // Add like optimistically
                var newLikes = updatedLoop.likes
                newLikes.append(currentUserId)
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
            }
            
            loops[index] = updatedLoop
        }
        
        // Perform backend operation
        do {
            if isCurrentlyLiked {
                try await FirebaseService.shared.unlikeLoop(loop.id)
            } else {
                try await FirebaseService.shared.likeLoop(loop.id)
            }
            
            // Success - remove from pending and start cooldown
            pendingLikeOperations.remove(loop.id)
            likeOperationCooldowns[loop.id] = Date()
            print("🔓 UNLOCKED - Removed \(loop.id.prefix(8)) from pending, count: \(pendingLikeOperations.count), cooldown active")
        } catch {
            // REVERT: Operation failed, revert the optimistic update
            if let index = loops.firstIndex(where: { $0.id == loop.id }) {
                var revertedLoop = loops[index]
                
                if isCurrentlyLiked {
                    // Restore the like
                    var restoredLikes = revertedLoop.likes
                    if !restoredLikes.contains(currentUserId) {
                        restoredLikes.append(currentUserId)
                    }
                    revertedLoop = Loop(
                        id: revertedLoop.id,
                        authorId: revertedLoop.authorId,
                        content: revertedLoop.content,
                        media: revertedLoop.media,
                        createdAt: revertedLoop.createdAt,
                        updatedAt: revertedLoop.updatedAt,
                        likes: restoredLikes,
                        replies: revertedLoop.replies,
                        isReply: revertedLoop.isReply,
                        parentLoopId: revertedLoop.parentLoopId,
                        authorDisplayName: revertedLoop.authorDisplayName,
                        authorUsername: revertedLoop.authorUsername,
                        authorAvatarURL: revertedLoop.authorAvatarURL,
                        authorBadgeType: revertedLoop.authorBadgeType
                    )
                } else {
                    // Remove the like
                    var restoredLikes = revertedLoop.likes
                    restoredLikes.removeAll { $0 == currentUserId }
                    revertedLoop = Loop(
                        id: revertedLoop.id,
                        authorId: revertedLoop.authorId,
                        content: revertedLoop.content,
                        media: revertedLoop.media,
                        createdAt: revertedLoop.createdAt,
                        updatedAt: revertedLoop.updatedAt,
                        likes: restoredLikes,
                        replies: revertedLoop.replies,
                        isReply: revertedLoop.isReply,
                        parentLoopId: revertedLoop.parentLoopId,
                        authorDisplayName: revertedLoop.authorDisplayName,
                        authorUsername: revertedLoop.authorUsername,
                        authorAvatarURL: revertedLoop.authorAvatarURL,
                        authorBadgeType: revertedLoop.authorBadgeType
                    )
                }
                
                loops[index] = revertedLoop
            }
            
            // Remove from pending and start cooldown even on error
            pendingLikeOperations.remove(loop.id)
            likeOperationCooldowns[loop.id] = Date()
            print("🔓 UNLOCKED (error) - Removed \(loop.id.prefix(8)) from pending, count: \(pendingLikeOperations.count), cooldown active")
            
            // Show error message
            errorMessage = "Couldn't update like. Please try again."
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
