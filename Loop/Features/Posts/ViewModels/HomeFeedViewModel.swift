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
    /// Changes when the feed ranks again for a new visit after the app was away, which starts the list back at the top
    private(set) var visitID = UUID()

    // Reply previews for each loop
    private(set) var replyPreviews: [String: [Loop]] = [:] // loopId -> reply previews

    // Compose state
    private(set) var isPosting = false

    private let currentUserId = Auth.auth().currentUser?.uid
    /// How many of the newest posts are ranked for each visit. Topics post about ten an hour between them, so this
    /// reaches back most of a working day
    private let windowSize = 80
    /// Older posts, below the ranked window, load in time order this many at a time
    private let pageSize = 20
    private let logger = Logger(subsystem: "com.nejack.Loop", category: "HomeFeedViewModel")
    /// Away this long, the feed ranks again when the app comes back, as if it had just been opened
    private static let rerankAfterAway: TimeInterval = 30 * 60
    /// How long a first snapshot from the device's cache waits for the server's before it is ranked anyway (offline)
    private static let cacheFallbackDelay: Duration = .seconds(2)
    /// How long a post stays at least half on screen before it counts as seen, so posts flicked past don't
    private static let seenDwell: Duration = .seconds(1)

    @ObservationIgnored private var listener: ListenerRegistration?
    @ObservationIgnored private var windowTask: Task<Void, Never>?
    /// Cursor for the next page: the oldest post of the ranked window, then the last page loaded.
    @ObservationIgnored private var lastDocument: DocumentSnapshot?
    /// Whether the feed has been ranked since it started; until then live snapshots rank rather than update
    @ObservationIgnored private var isRanked = false
    /// Bumped by every ranking, so a slower, older one doesn't overwrite a newer one
    @ObservationIgnored private var rankGeneration = 0
    /// When the first snapshot from the cache arrived, which the wait for the server's counts from
    @ObservationIgnored private var firstCachedSnapshotAt: Date?
    /// New posts from others that arrived after the feed was ranked; they show at the next ranking
    @ObservationIgnored private var heldPostIds: Set<String> = []
    @ObservationIgnored private var seenIds: Set<String> = []
    @ObservationIgnored private var seenTimers: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var backgroundedAt: Date?
    /// Fixes the ranking's jitter for this session
    @ObservationIgnored private let rankingSeed = UInt64.random(in: 0...UInt64.max)
    /// People the current user follows, read once per load.
    @ObservationIgnored private var followingIds: Set<String>?
    /// Reply IDs each preview was built from, so a post's preview is only refetched when its replies change.
    @ObservationIgnored private var previewSources: [String: [String]] = [:]

    deinit {
        listener?.remove()
    }

    // MARK: - Feed Management

    /// The newest public posts, newest first: the window ranked for each visit, then the pages below it.
    private var feedQuery: Query {
        Firestore.firestore()
            .collection("loops")
            .whereField("isReply", isEqualTo: false) // Only show main loops, not replies
            .order(by: "createdAt", descending: true)
    }

    /// Starts the live listener on the ranked window. Safe to call again; it only starts once. The first snapshot
    /// with server data is ranked; later ones update the feed in place (see `applyLiveUpdate`). Metadata changes are
    /// included so a first snapshot from the cache can be told apart from the server's, even when they match.
    func start() {
        guard listener == nil, currentUserId != nil else { return }

        if loops.isEmpty {
            isLoading = true
        }

        listener = feedQuery
            .limit(to: windowSize)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                guard let snapshot else {
                    self.isLoading = false
                    return
                }

                // A newer snapshot supersedes one that is still being processed
                self.windowTask?.cancel()
                self.windowTask = Task {
                    await self.applyWindowSnapshot(snapshot)
                }
            }
    }

    func refreshFeed() async {
        // Pull to refresh re-reads profiles and the following list, then ranks the newest posts again
        FirebaseService.shared.invalidateUserCache()
        followingIds = nil
        previewSources = [:]
        windowTask?.cancel()

        do {
            let snapshot = try await feedQuery.limit(to: windowSize).getDocuments()
            await rank(snapshot.documents)
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

    /// The first snapshot often comes from the device's cache, from whenever the app last ran; ranking it would show
    /// old posts and hold back everything newer. So the feed ranks the server's, or the cache's if the server's doesn't
    /// come in time.
    private func applyWindowSnapshot(_ snapshot: QuerySnapshot) async {
        if isRanked {
            await applyLiveUpdate(snapshot.documents)
        } else if snapshot.metadata.isFromCache {
            // A later cache snapshot cancels this one's wait and carries on with what is left of it
            let firstAt = firstCachedSnapshotAt ?? Date()
            firstCachedSnapshotAt = firstAt
            let waited = Date().timeIntervalSince(firstAt)
            try? await Task.sleep(for: max(Self.cacheFallbackDelay - .seconds(waited), .zero))
            guard !Task.isCancelled, !isRanked else { return }
            await rank(snapshot.documents)
        } else {
            await rank(snapshot.documents)
        }
    }

    /// Orders the window's posts for this visit and shows them in place of the whole feed, older pages included.
    private func rank(_ documents: [QueryDocumentSnapshot], resettingScroll: Bool = false) async {
        rankGeneration += 1
        let generation = rankGeneration

        let window = await FirebaseService.shared.loops(from: documents)
        let context = await rankingContext()
        // Previews load before the feed is shown so cards don't shift once they appear
        let previewUpdates = await previewUpdates(for: window)
        guard generation == rankGeneration else { return }

        let candidates = window.map {
            FeedRanker.Candidate(
                id: $0.id,
                authorId: $0.authorId,
                topicId: $0.topic?.id,
                createdAt: $0.createdAt,
                likeCount: $0.likeCount,
                replyCount: $0.replyCount,
                significance: $0.significance
            )
        }
        let windowById = Dictionary(window.map { ($0.id, $0) }) { first, _ in first }
        let ranked = FeedRanker.rank(candidates, context: context).compactMap { windowById[$0] }

        // Disable animations to prevent flickering during state updates
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            applyPreviewUpdates(previewUpdates, from: window)
            if ranked != loops {
                loops = ranked
            }
            if resettingScroll {
                visitID = UUID()
            }
        }

        isRanked = true
        firstCachedSnapshotAt = nil
        heldPostIds = []
        lastDocument = documents.last
        hasMoreContent = documents.count == windowSize
        isLoading = false
    }

    /// Applies a live snapshot of the window without reordering the feed, so nothing moves under the finger: posts
    /// already showing update in place (likes, replies), posts deleted from the window disappear, and new posts from
    /// others wait for the next ranking. Your own new posts show at the top straight away.
    private func applyLiveUpdate(_ documents: [QueryDocumentSnapshot]) async {
        let window = await FirebaseService.shared.loops(from: documents)
        let previewUpdates = await previewUpdates(for: window)
        guard !Task.isCancelled else { return }

        // Read after the last await, so a ranking that landed meanwhile is what gets updated
        let windowById = Dictionary(window.map { ($0.id, $0) }) { first, _ in first }
        let shownIds = Set(loops.map(\.id))
        let oldestInWindow = window.last?.createdAt
        let ownNewPosts = window.filter { !shownIds.contains($0.id) && $0.authorId == currentUserId }
        heldPostIds.formUnion(window.filter { !shownIds.contains($0.id) && $0.authorId != currentUserId }.map(\.id))

        let updated = ownNewPosts + loops.compactMap { loop -> Loop? in
            if let fresh = windowById[loop.id] {
                return fresh
            }
            // Missing from the window: deleted if it is newer than the window's oldest post; older ones were pushed
            // out by newer posts, or loaded with a page below it, and stay
            if let oldestInWindow, loop.createdAt > oldestInWindow {
                return nil
            }
            return loop
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            applyPreviewUpdates(previewUpdates, from: window)
            if updated != loops {
                loops = updated
            }
        }
    }

    /// What the ranking needs to know about you: the posts you've seen, and the people and topics you follow.
    private func rankingContext() async -> FeedRanker.Context {
        var seen: Set<String> = []
        var followedTopics: Set<String> = []
        if let currentUserId {
            seen = await SeenPostsStore.shared.seenIds(userId: currentUserId)
            do {
                followedTopics = try await FirebaseService.shared.followedTopics()
            } catch {
                logger.error("Followed topics read failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        seenIds = seen
        return FeedRanker.Context(
            now: Date(),
            currentUserId: currentUserId,
            seenIds: seen,
            followedAuthorIds: await loadFollowingIds(),
            followedTopicIds: followedTopics,
            seed: rankingSeed
        )
    }

    // MARK: - Seen Posts

    /// Counts a post as seen once it has stayed at least half on screen for a second.
    func postVisibilityChanged(_ loopId: String, isVisible: Bool) {
        seenTimers[loopId]?.cancel()
        seenTimers[loopId] = nil
        guard isVisible, !seenIds.contains(loopId), let currentUserId else { return }

        seenTimers[loopId] = Task { [weak self] in
            try? await Task.sleep(for: Self.seenDwell)
            guard !Task.isCancelled, let self else { return }
            self.seenTimers[loopId] = nil
            self.seenIds.insert(loopId)
            await SeenPostsStore.shared.markSeen(loopId, userId: currentUserId)
        }
    }

    // MARK: - App Lifecycle

    func appDidEnterBackground() {
        backgroundedAt = Date()
        Task {
            await SeenPostsStore.shared.flush()
        }
    }

    /// Ranks the feed again if the app was away long enough, and starts the list back at the top.
    func appDidBecomeActive() async {
        guard let backgroundedAt else { return }
        self.backgroundedAt = nil
        guard isRanked, Date().timeIntervalSince(backgroundedAt) >= Self.rerankAfterAway else { return }

        do {
            let snapshot = try await feedQuery.limit(to: windowSize).getDocuments()
            await rank(snapshot.documents, resettingScroll: true)
        } catch {
            logger.error("Ranking on return failed: \(error.localizedDescription, privacy: .public)")
        }
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

    /// Creates a loop or a reply from the composer. It throws, so a failed post keeps the composer open with the draft.
    func postLoop(_ draft: LoopDraft) async throws {
        guard draft.isValid, draft.isWithinCharacterLimit else { return }

        isPosting = true
        defer { isPosting = false }

        try await FirebaseService.shared.createLoop(
            content: draft.content,
            media: draft.media,
            isReply: draft.isReply,
            parentLoopId: draft.parentLoopId,
            replyToReplyId: draft.replyToReplyId
        )

        // If this was a reply, refresh the reply preview for that loop
        if draft.isReply, let parentId = draft.parentLoopId {
            await refreshReplyPreviewForLoop(parentId)
        }
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

    func canDeleteLoop(_ loop: Loop) -> Bool {
        loop.authorId == currentUserId
    }

    func deleteLoop(_ loop: Loop) async {
        guard canDeleteLoop(loop) else { return }

        // A reply shows in the feed only as its post's preview
        if let parentId = loop.parentLoopId {
            await deleteReply(loop, parentId: parentId)
            return
        }

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

    /// Removes a reply from its post's preview right away, then deletes it. The post's reply count comes with the
    /// listener's next snapshot, and its next preview, if another reply qualifies, is fetched once the delete lands.
    private func deleteReply(_ reply: Loop, parentId: String) async {
        guard let preview = replyPreviews[parentId], preview.contains(where: { $0.id == reply.id }) else { return }
        let remaining = preview.filter { $0.id != reply.id }

        // previewSources stays as it is: until the delete lands the post's replies are unchanged, so a snapshot in
        // the meantime doesn't refetch the preview with the reply still in it
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            replyPreviews[parentId] = remaining.isEmpty ? nil : remaining
        }

        do {
            try await FirebaseService.shared.deleteLoop(reply.id)
            await refreshReplyPreviewForLoop(parentId)
        } catch {
            // Put the reply back, unless a newer preview has replaced it meanwhile
            if (replyPreviews[parentId] ?? []) == remaining {
                withTransaction(transaction) {
                    replyPreviews[parentId] = preview
                }
            }
            errorMessage = "Couldn't delete comment. Please try again."
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
