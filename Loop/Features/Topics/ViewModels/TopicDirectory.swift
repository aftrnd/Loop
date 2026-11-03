import Foundation
import FirebaseAuth
import os

/// The topics in the directory and the ones you follow, shared by Discover, topic pages and Home, so a follow made in
/// one shows in the others at once.
///
/// What you follow is `followedTopics` on your own profile. An account that has never chosen has no list and follows
/// every topic, new ones included; its first unfollow saves the whole directory but that topic.
@MainActor
@Observable
final class TopicDirectory {
    static let shared = TopicDirectory()

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    enum FollowsState {
        case unread
        case read
        /// The read failed; you're shown following every topic, and a change reads them again before it saves
        case failed
    }

    /// Every topic, in the directory's order
    private(set) var topics: [TopicEntry] = []
    private(set) var state: LoadState = .idle
    private(set) var followsState: FollowsState = .unread
    /// The topics you follow, or nil for every topic: you haven't chosen, or they couldn't be read
    private(set) var followedIds: Set<String>?

    private let logger = Logger(subsystem: "com.nejack.Loop", category: "TopicDirectory")
    /// The account the follows were read for
    @ObservationIgnored private var userId: String?
    @ObservationIgnored private var directoryTask: Task<Void, Never>?
    @ObservationIgnored private var followsTask: Task<Void, Never>?

    private init() {}

    func isFollowing(_ topicId: String) -> Bool {
        followedIds?.contains(topicId) ?? true
    }

    // MARK: - Loading

    /// Reads the directory once, or again after a failure or with `refresh`, for the latest briefs.
    func loadDirectory(refresh: Bool = false) async {
        guard refresh || state != .loaded else { return }
        if directoryTask == nil {
            directoryTask = Task { await readDirectory() }
        }
        await directoryTask?.value
        directoryTask = nil
    }

    private func readDirectory() async {
        if topics.isEmpty {
            state = .loading
        }
        do {
            let read = try await FirebaseService.shared.topicDirectory()
            if read != topics {
                topics = read
            }
            state = .loaded
        } catch {
            logger.error("Topic directory read failed: \(error.localizedDescription, privacy: .public)")
            // A refresh that fails keeps the topics already listed
            if topics.isEmpty {
                state = .failed("Check your connection and try again.")
            }
        }
    }

    /// The topics you follow, or nil for every topic, read once for each account.
    func follows() async -> Set<String>? {
        resetIfAccountChanged()
        if followsState != .read {
            if followsTask == nil {
                followsTask = Task { await readFollows() }
            }
            await followsTask?.value
            followsTask = nil
        }
        return followedIds
    }

    private func readFollows() async {
        let readFor = userId
        do {
            let ids = try await FirebaseService.shared.followedTopics()
            guard readFor == userId else { return }
            followedIds = ids
            followsState = .read
        } catch {
            logger.error("Followed topics read failed: \(error.localizedDescription, privacy: .public)")
            guard readFor == userId else { return }
            followsState = .failed
        }
    }

    /// Forgets the last account's follows when someone else has signed in.
    private func resetIfAccountChanged() {
        let currentUserId = Auth.auth().currentUser?.uid
        guard currentUserId != userId else { return }
        userId = currentUserId
        followedIds = nil
        followsState = .unread
    }

    // MARK: - Following

    /// Follows or unfollows a topic at once, then saves it; if the save fails, it changes back and throws.
    func setFollowing(_ following: Bool, topicId: String) async throws {
        _ = await follows()
        guard followsState == .read else { throw TopicDirectoryError.followsUnread }

        let base: Set<String>
        if let followedIds {
            base = followedIds
        } else {
            // Following every topic already
            guard !following else { return }
            // The first choice: every topic so far but this one
            await loadDirectory()
            guard state == .loaded, !topics.isEmpty else { throw TopicDirectoryError.directoryUnread }
            base = Set(topics.map(\.id))
        }

        var updated = base
        if following {
            updated.insert(topicId)
        } else {
            updated.remove(topicId)
        }
        let previous = followedIds
        guard updated != previous else { return }

        followedIds = updated
        do {
            try await FirebaseService.shared.setFollowedTopics(updated)
        } catch {
            // Unless a later change has replaced it meanwhile
            if followedIds == updated {
                followedIds = previous
            }
            throw error
        }
    }
}

enum TopicDirectoryError: LocalizedError {
    case followsUnread
    case directoryUnread

    var errorDescription: String? {
        switch self {
        case .followsUnread: "The topics you follow couldn't be read."
        case .directoryUnread: "The list of topics couldn't be read."
        }
    }
}
