import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import os

@MainActor
@Observable
final class HomeFeedViewModel {
    private(set) var loops: [Loop] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var errorMessage: String?
    private(set) var hasMoreContent = true

    // Reply previews for each loop
    private(set) var replyPreviews: [String: [Loop]] = [:] // loopId -> reply previews

    // Compose state
    var showingCompose = false
    var composeDraft = LoopDraft()
    private(set) var isPosting = false

    private let currentUserId = Auth.auth().currentUser?.uid
    private let pageSize = 20
    private let logger = Logger(subsystem: "com.nejack.Loop", category: "HomeFeedViewModel")

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var firstPageTask: Task<Void, Never>?
    /// Cursor for the next page: the last document currently loaded.
    @ObservationIgnored private var lastDocument: DocumentSnapshot?
    /// People the current user follows, read once per load.
    @ObservationIgnored private var followingIds: Set<String>?
    /// Reply IDs each preview was built from, so a post's preview is only refetched when its replies change.
    @ObservationIgnored private var previewSources: [String: [String]] = [:]

    deinit {
        listener?.remove()
    }

    // MARK: - Feed Management

    /// All public loops, newest first. Filtering by following comes later.
    private var feedQuery: Query {
        Firestore.firestore()
            .collection("loops")
            .whereField("isReply", isEqualTo: false) // Only show main loops, not replies
            .order(by: "createdAt", descending: true)
    }

    /// Starts the live listener on the first page. Safe to call again; it only starts once.
    func start() {
        guard listener == nil, currentUserId != nil else { return }

        if loops.isEmpty {
            isLoading = true
        }

        listener = feedQuery
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

                // A newer snapshot supersedes one that is still being processed
                self.firstPageTask?.cancel()
                self.firstPageTask = Task {
                    await self.applyFirstPage(documents, keepingOlderPages: true)
                }
            }
    }

    func refreshFeed() async {
        // Pull to refresh re-reads profiles and the following list, then resets to the first page
        FirebaseService.shared.invalidateUserCache()
        followingIds = nil
        previewSources = [:]
        firstPageTask?.cancel()

        do {
            let snapshot = try await feedQuery.limit(to: pageSize).getDocuments()
            await applyFirstPage(snapshot.documents, keepingOlderPages: false)
        } catch {
            errorMessage = error.localizedDescription
        }

        start()
    }

    func loadMoreContent() async {
        guard !isLoading, !isLoadingMore, hasMoreContent, let cursor = lastDocument else { return }

        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let snapshot = try await feedQuery
                .start(afterDocument: cursor)
                .limit(to: pageSize)
                .getDocuments()

            let page = await FirebaseService.shared.loops(from: snapshot.documents)
            let previewUpdates = await previewUpdates(for: page)
            let loadedIds = Set(loops.map(\.id))

            // No animation needed for loading more
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                applyPreviewUpdates(previewUpdates, from: page)
                loops.append(contentsOf: page.filter { !loadedIds.contains($0.id) })
            }

            if let last = snapshot.documents.last {
                lastDocument = last
            }
            hasMoreContent = snapshot.documents.count == pageSize
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Replaces the first page with `documents`. When `keepingOlderPages` is set, loops loaded further down
    /// stay in place, so a live update (a like, a new post) doesn't reset scrolling.
    private func applyFirstPage(_ documents: [QueryDocumentSnapshot], keepingOlderPages: Bool) async {
        let page = await FirebaseService.shared.loops(from: documents)
        // Previews load before the page is shown so cards don't shift once they appear
        let previewUpdates = await previewUpdates(for: page)
        guard !Task.isCancelled else { return }

        var olderLoops: [Loop] = []
        if keepingOlderPages, let oldestOnPage = page.last {
            let pageIds = Set(page.map(\.id))
            olderLoops = loops.filter { !pageIds.contains($0.id) && $0.createdAt <= oldestOnPage.createdAt }
        }
        let mergedLoops = page + olderLoops

        // Disable animations to prevent flickering during state updates
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            applyPreviewUpdates(previewUpdates, from: page)
            if mergedLoops != loops {
                loops = mergedLoops
            }
        }

        // With older pages loaded, the cursor already points past them
        if olderLoops.isEmpty {
            lastDocument = documents.last
            hasMoreContent = documents.count == pageSize
        }
        isLoading = false
    }

    // MARK: - Reply Previews

    /// Works out which posts on `page` need a new preview and fetches them. An empty array means no preview.
    private func previewUpdates(for page: [Loop]) async -> [String: [Loop]] {
        var updates: [String: [Loop]] = [:]
        var staleIds: [String] = []

        for loop in page {
            if loop.replyCount == 0 {
                updates[loop.id] = []
            } else if previewSources[loop.id] != loop.replies {
                staleIds.append(loop.id)
            }
        }

        if let fetched = await fetchReplyPreviews(forParentIds: staleIds) {
            updates.merge(fetched) { _, fetched in fetched }
        }
        return updates
    }

    private func applyPreviewUpdates(_ updates: [String: [Loop]], from page: [Loop]) {
        var previews = replyPreviews
        for loop in page {
            guard let update = updates[loop.id] else { continue }
            previews[loop.id] = update.isEmpty ? nil : update
            previewSources[loop.id] = loop.replies
        }
        if previews != replyPreviews {
            replyPreviews = previews
        }
    }

    /// Fetches, for each parent, the newest top-level reply written by the current user or someone they follow.
    /// Returns nil if the query fails. A parent without a matching reply maps to an empty array.
    private func fetchReplyPreviews(forParentIds parentIds: [String]) async -> [String: [Loop]]? {
        guard let currentUserId, !parentIds.isEmpty else { return [:] }

        let followingIds = await loadFollowingIds()
        var newestReplies: [String: Loop] = [:]

        // Firestore allows up to 30 values in an `in` filter
        for start in stride(from: 0, to: parentIds.count, by: 30) {
            let batch = Array(parentIds[start..<min(start + 30, parentIds.count)])
            do {
                let snapshot = try await Firestore.firestore()
                    .collection("loops")
                    .whereField("parentLoopId", in: batch)
                    .getDocuments()

                for document in snapshot.documents {
                    guard let reply = FirebaseService.parseLoop(id: document.documentID, data: document.data()),
                          let parentId = reply.parentLoopId,
                          reply.replyToReplyId == nil,
                          reply.authorId == currentUserId || followingIds.contains(reply.authorId) else {
                        continue
                    }
                    if let newest = newestReplies[parentId], newest.createdAt >= reply.createdAt {
                        continue
                    }
                    newestReplies[parentId] = reply
                }
            } catch {
                logger.error("Reply preview fetch failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        let authors = await FirebaseService.shared.users(withIds: newestReplies.values.map(\.authorId))
        return parentIds.reduce(into: [:]) { result, parentId in
            result[parentId] = newestReplies[parentId].map { [$0.withAuthor(authors[$0.authorId])] } ?? []
        }
    }

    private func loadFollowingIds() async -> Set<String> {
        if let followingIds {
            return followingIds
        }
        guard let currentUserId else { return [] }

        do {
            let ids = Set(try await FirebaseService.shared.getUser(withId: currentUserId)?.following ?? [])
            followingIds = ids
            return ids
        } catch {
            logger.error("Following list fetch failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    func refreshReplyPreviewForLoop(_ loopId: String) async {
        guard let previews = await fetchReplyPreviews(forParentIds: [loopId]) else { return }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let update = previews[loopId] ?? []
            replyPreviews[loopId] = update.isEmpty ? nil : update
        }
        // The local copy of the post may not list the new reply yet, so recheck on the next snapshot
        previewSources[loopId] = nil
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

    // MARK: - Loop Actions

    /// Flips the like locally, then writes it. Firestore applies the write to the live listener right away,
    /// so snapshots that arrive while the write is in flight already agree with the local state.
    func toggleLike(for loop: Loop) async {
        guard let currentUserId else { return }

        // Read the current state rather than the row's captured copy, so quick repeat taps alternate
        let wasLiked = loops.first(where: { $0.id == loop.id })?.likes.contains(currentUserId)
            ?? loop.likes.contains(currentUserId)
        setLiked(!wasLiked, loopId: loop.id, userId: currentUserId)

        do {
            if wasLiked {
                try await FirebaseService.shared.unlikeLoop(loop.id)
            } else {
                try await FirebaseService.shared.likeLoop(loop.id)
            }
        } catch {
            setLiked(wasLiked, loopId: loop.id, userId: currentUserId)
            errorMessage = "Couldn't update like. Please try again."
        }
    }

    private func setLiked(_ liked: Bool, loopId: String, userId: String) {
        guard let index = loops.firstIndex(where: { $0.id == loopId }),
              loops[index].likes.contains(userId) != liked else { return }

        // Animated so the heart morphs and the count rolls; only this row's content changes
        withAnimation(.snappy(duration: 0.3)) {
            if liked {
                loops[index].likes.append(userId)
            } else {
                loops[index].likes.removeAll { $0 == userId }
            }
        }
    }

    func replyToLoop(_ loop: Loop) {
        composeDraft = LoopDraft()
        composeDraft.isReply = true
        composeDraft.parentLoopId = loop.id
        showingCompose = true
    }

    func canDeleteLoop(_ loop: Loop) -> Bool {
        loop.authorId == currentUserId
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
        previewSources[loop.id] = nil

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
                await refreshReplyPreviewForLoop(deletedLoop.id)
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
        guard let currentUserId else { return false }
        return loop.likes.contains(currentUserId)
    }
}
