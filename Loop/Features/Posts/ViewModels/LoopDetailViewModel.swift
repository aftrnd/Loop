import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import os

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
    private(set) var loop: Loop
    private(set) var replies: [Loop] = [] // Raw replies from Firebase
    private(set) var threadedReplies: [ThreadedReply] = [] // Organized threaded structure
    /// True until the first snapshot of replies arrives.
    private(set) var isLoading = true
    var errorMessage: String?

    // Compose state for replies
    var showingCompose = false
    var composeDraft = LoopDraft()
    private(set) var isPosting = false

    // Callback for when replies change (to notify parent feed)
    @ObservationIgnored var onRepliesChanged: (() -> Void)?

    private let currentUserId = Auth.auth().currentUser?.uid
    private let logger = Logger(subsystem: "com.nejack.Loop", category: "LoopDetailViewModel")

    @ObservationIgnored private var listener: ListenerRegistration?
    /// Keeps the main post's likes and reply count current, including this device's own writes.
    @ObservationIgnored private var loopListener: ListenerRegistration?
    @ObservationIgnored private var snapshotTask: Task<Void, Never>?
    /// The documents from the latest snapshot, so a refresh can rebuild replies without another query.
    @ObservationIgnored private var latestDocuments: [QueryDocumentSnapshot] = []
    /// Top-level replies whose nested replies are showing, kept across rebuilds of the thread list.
    @ObservationIgnored private var expandedReplyIds: Set<String> = []

    init(loop: Loop, onRepliesChanged: (() -> Void)? = nil) {
        self.loop = loop
        self.onRepliesChanged = onRepliesChanged
    }

    deinit {
        listener?.remove()
        loopListener?.remove()
        snapshotTask?.cancel()
    }

    // MARK: - Data Loading

    /// Starts the live listeners on the main post and its replies. Safe to call again; each only starts once.
    func start() {
        startRepliesListener()
        startLoopListener()
    }

    /// The replies listener is the only source of replies: its first snapshot loads them, and later snapshots
    /// carry new replies, likes and deletions, including this device's own.
    private func startRepliesListener() {
        guard listener == nil else { return }

        listener = Firestore.firestore()
            .collection("loops")
            .whereField("parentLoopId", isEqualTo: loop.id)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    // A listener stops after an error, so drop it and let a refresh start a new one
                    self.listener?.remove()
                    self.listener = nil
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let documents = snapshot?.documents else { return }

                self.latestDocuments = documents
                self.processReplyDocuments(documents)
            }
    }

    private func startLoopListener() {
        guard loopListener == nil else { return }

        loopListener = Firestore.firestore()
            .collection("loops")
            .document(loop.id)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    // A listener stops after an error; the post keeps its last known state until a refresh
                    self.loopListener?.remove()
                    self.loopListener = nil
                    self.logger.error("Post listener failed: \(error.localizedDescription, privacy: .public)")
                    return
                }

                guard let snapshot, let data = snapshot.data(),
                      let fresh = FirebaseService.parseLoop(id: snapshot.documentID, data: data) else { return }
                self.applyMainLoop(fresh)
            }
    }

    private func applyMainLoop(_ fresh: Loop) {
        // The document has no author details, so the ones already shown are kept
        var updated = fresh
        updated.authorDisplayName = loop.authorDisplayName
        updated.authorUsername = loop.authorUsername
        updated.authorAvatarURL = loop.authorAvatarURL
        updated.authorBadgeType = loop.authorBadgeType
        guard updated != loop else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            loop = updated
        }
    }

    /// Pull to refresh. Replies are already live, so this re-reads author profiles, or restarts a listener
    /// that stopped after an error.
    func refresh() async {
        startLoopListener()
        guard listener != nil else {
            startRepliesListener()
            return
        }
        // Before the first snapshot there is nothing to rebuild, and an empty rebuild would end the loading state
        guard !isLoading else { return }

        FirebaseService.shared.invalidateUserCache()
        processReplyDocuments(latestDocuments)
        await snapshotTask?.value
    }

    /// Builds replies from `documents`. A newer snapshot cancels one that is still being processed.
    private func processReplyDocuments(_ documents: [QueryDocumentSnapshot]) {
        snapshotTask?.cancel()
        snapshotTask = Task {
            // Taken as is: snapshots already include this device's pending writes, such as a like in flight
            let newReplies = await FirebaseService.shared.loops(from: documents)
            guard !Task.isCancelled else { return }

            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if newReplies != replies {
                    replies = newReplies
                    rebuildThreads()
                }
            }
            isLoading = false
        }
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

    /// Posts the draft as a reply. Throws instead of setting `errorMessage`, because the compose sheet is still
    /// open and shows the failure itself.
    func postReply() async throws {
        guard composeDraft.isValid, composeDraft.isWithinCharacterLimit, !isPosting else { return }

        isPosting = true
        defer { isPosting = false }

        try await FirebaseService.shared.createLoop(
            content: composeDraft.content,
            media: composeDraft.media,
            isReply: composeDraft.isReply,
            parentLoopId: composeDraft.parentLoopId,
            replyToReplyId: composeDraft.replyToReplyId
        )

        // Success - clear the compose state. The listener shows the new reply as soon as it is written.
        hideCompose()

        // Notify parent that replies changed
        onRepliesChanged?()
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
