import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

// MARK: - Threaded Reply Structure
struct ThreadedReply: Identifiable {
    let id: String
    let reply: Loop
    let nestedReplies: [Loop] // Replies to this reply, sorted oldest first
    var isExpanded: Bool // For collapsing/expanding nested replies

    init(reply: Loop, nestedReplies: [Loop] = [], isExpanded: Bool = false) {
        self.id = reply.id
        self.reply = reply
        self.nestedReplies = nestedReplies
        self.isExpanded = isExpanded
    }
}

@MainActor
@Observable
final class LoopDetailViewModel {
    var loop: Loop
    var replies: [Loop] = [] // Raw replies from Firebase
    var threadedReplies: [ThreadedReply] = [] // Organized threaded structure
    var isLoading = false
    var isRefreshing = false
    var errorMessage: String?

    // Compose state for replies
    var showingCompose = false
    var composeDraft = LoopDraft()
    var isPosting = false

    // Callback for when replies change (to notify parent feed)
    @ObservationIgnored var onRepliesChanged: (() -> Void)?

    private let currentUserId = Auth.auth().currentUser?.uid

    @ObservationIgnored private var listener: ListenerRegistration?
    /// Top-level replies whose nested replies are showing, kept across rebuilds of the thread list.
    @ObservationIgnored private var expandedReplyIds: Set<String> = []

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
            let fetched = try await FirebaseService.shared.getReplies(for: loop.id)

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                replies = fetched
                rebuildThreads()
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Groups `replies` into threads: top-level replies newest first, each with its nested replies oldest first.
    /// Always built from `replies`, so a reply's place in the thread comes from its current data.
    /// Callers choose the animation.
    private func rebuildThreads() {
        var nestedByParent: [String: [Loop]] = [:]
        for reply in replies {
            if let parentId = reply.replyToReplyId {
                nestedByParent[parentId, default: []].append(reply)
            }
        }

        threadedReplies = replies
            .filter { $0.replyToReplyId == nil }
            .sorted { $0.createdAt > $1.createdAt }
            .map { topLevelReply in
                ThreadedReply(
                    reply: topLevelReply,
                    nestedReplies: (nestedByParent[topLevelReply.id] ?? []).sorted { $0.createdAt < $1.createdAt },
                    isExpanded: expandedReplyIds.contains(topLevelReply.id)
                )
            }
    }

    func toggleReplyExpansion(_ replyId: String) {
        guard let index = threadedReplies.firstIndex(where: { $0.id == replyId }) else { return }

        threadedReplies[index].isExpanded.toggle()
        if threadedReplies[index].isExpanded {
            expandedReplyIds.insert(replyId)
        } else {
            expandedReplyIds.remove(replyId)
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
        // Taken as is: snapshots already include this device's pending writes, such as a like in flight
        let newReplies = await FirebaseService.shared.loops(from: documents)

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            replies = newReplies
            rebuildThreads()
        }
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

    /// Flips the like locally, then writes it. Firestore applies the write to the live listener right away,
    /// so snapshots that arrive while the write is in flight already agree with the local state.
    func toggleLike(for targetLoop: Loop) async {
        guard let currentUserId else { return }

        // Read the current state rather than the row's captured copy, so quick repeat taps alternate
        let wasLiked = currentLikes(of: targetLoop.id)?.contains(currentUserId)
            ?? targetLoop.likes.contains(currentUserId)
        setLiked(!wasLiked, loopId: targetLoop.id, userId: currentUserId)

        do {
            if wasLiked {
                try await FirebaseService.shared.unlikeLoop(targetLoop.id)
            } else {
                try await FirebaseService.shared.likeLoop(targetLoop.id)
            }
        } catch {
            setLiked(wasLiked, loopId: targetLoop.id, userId: currentUserId)
            errorMessage = "Couldn't update like. Please try again."
        }
    }

    private func currentLikes(of loopId: String) -> [String]? {
        if loopId == loop.id {
            return loop.likes
        }
        return replies.first(where: { $0.id == loopId })?.likes
    }

    private func setLiked(_ liked: Bool, loopId: String, userId: String) {
        // Animated so the heart morphs and the count rolls; only the liked card's content changes
        if loopId == loop.id {
            guard loop.likes.contains(userId) != liked else { return }
            withAnimation(.snappy(duration: 0.3)) {
                if liked {
                    loop.likes.append(userId)
                } else {
                    loop.likes.removeAll { $0 == userId }
                }
            }
        } else if let index = replies.firstIndex(where: { $0.id == loopId }) {
            guard replies[index].likes.contains(userId) != liked else { return }
            withAnimation(.snappy(duration: 0.3)) {
                if liked {
                    replies[index].likes.append(userId)
                } else {
                    replies[index].likes.removeAll { $0 == userId }
                }
                // The cards render from the threads, so they are rebuilt from the updated reply
                rebuildThreads()
            }
        }
    }

    // MARK: - Delete Actions

    func canDeleteLoop(_ targetLoop: Loop) -> Bool {
        targetLoop.authorId == currentUserId
    }

    func deleteLoop(_ targetLoop: Loop) async {
        // The main loop can't be deleted from the detail view
        guard canDeleteLoop(targetLoop), targetLoop.id != loop.id,
              replies.contains(where: { $0.id == targetLoop.id }) else { return }

        // Optimistically remove the reply and the replies nested under it, and drop them from the count
        let removedIds = Set([targetLoop.id] + replies.filter { $0.replyToReplyId == targetLoop.id }.map(\.id))
        let removedReplies = replies.filter { removedIds.contains($0.id) }
        let removedCountIds = loop.replies.filter { removedIds.contains($0) }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            loop = loop.withReplies(loop.replies.filter { !removedIds.contains($0) })
            replies.removeAll { removedIds.contains($0.id) }
            rebuildThreads()
        }

        do {
            try await FirebaseService.shared.deleteLoop(targetLoop.id)
            // Notify parent that replies changed
            onRepliesChanged?()
        } catch {
            // Restore whatever a newer snapshot hasn't already brought back
            withTransaction(transaction) {
                let missingCountIds = removedCountIds.filter { !loop.replies.contains($0) }
                loop = loop.withReplies(loop.replies + missingCountIds)
                let presentIds = Set(replies.map(\.id))
                replies.append(contentsOf: removedReplies.filter { !presentIds.contains($0.id) })
                rebuildThreads()
            }

            errorMessage = "Couldn't delete comment. Please try again."
        }
    }

    // MARK: - Helpers

    func isLikedByCurrentUser(_ targetLoop: Loop) -> Bool {
        guard let currentUserId else { return false }
        return targetLoop.likes.contains(currentUserId)
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Loop Copy

private extension Loop {
    /// A copy with a different reply list. `replies` is a constant, so every other field is carried over by hand.
    func withReplies(_ replies: [String]) -> Loop {
        Loop(
            id: id,
            authorId: authorId,
            content: content,
            media: media,
            createdAt: createdAt,
            updatedAt: updatedAt,
            likes: likes,
            replies: replies,
            isReply: isReply,
            parentLoopId: parentLoopId,
            replyToReplyId: replyToReplyId,
            authorDisplayName: authorDisplayName,
            authorUsername: authorUsername,
            authorAvatarURL: authorAvatarURL,
            authorBadgeType: authorBadgeType
        )
    }
}
