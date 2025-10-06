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
        
        isLoading = true
        
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
                    self.isRefreshing = false
                }
            }
    }
    
    func refreshFeed() async {
        isRefreshing = true
        lastDocument = nil
        hasMoreContent = true
        
        // Restart the listener to get fresh data
        listener?.remove()
        startListening()
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
    
    func toggleLike(for loop: Loop) async {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        do {
            let isCurrentlyLiked = loop.likes.contains(currentUserId)
            
            if isCurrentlyLiked {
                try await FirebaseService.shared.unlikeLoop(loop.id)
            } else {
                try await FirebaseService.shared.likeLoop(loop.id)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func replyToLoop(_ loop: Loop) {
        composeDraft = LoopDraft()
        composeDraft.isReply = true
        composeDraft.parentLoopId = loop.id
        showingCompose = true
    }
    
    func shareLoop(_ loop: Loop) {
        // TODO: Implement sharing functionality
        // This could include native iOS sharing sheet
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
