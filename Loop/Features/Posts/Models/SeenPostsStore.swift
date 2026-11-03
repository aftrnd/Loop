import Foundation
import os

/// The posts the signed-in user has seen in the Home feed and when they first saw each, kept on the device in
/// Application Support, one file per account. The feed ranks posts you haven't seen first. Everything here runs off
/// the main actor, and saves wait a few seconds so scrolling past many posts writes once. Posts seen more than a week
/// ago, and any past the newest 3000, are forgotten.
actor SeenPostsStore {
    static let shared = SeenPostsStore()

    private static let maxAge: TimeInterval = 7 * 24 * 60 * 60
    private static let maxCount = 3000
    private static let saveDelay: Duration = .seconds(3)

    private let logger = Logger(subsystem: "com.nejack.Loop", category: "SeenPostsStore")
    /// The account whose seen posts are loaded
    private var userId: String?
    private var seen: [String: Date] = [:]
    private var hasUnsavedChanges = false
    private var saveTask: Task<Void, Never>?

    /// The posts `userId` has seen, reading their file the first time.
    func seenIds(userId: String) -> Set<String> {
        load(userId)
        return Set(seen.keys)
    }

    func markSeen(_ postId: String, userId: String) {
        load(userId)
        guard seen[postId] == nil else { return }
        seen[postId] = Date()
        hasUnsavedChanges = true
        scheduleSave()
    }

    /// Forgets every post `userId` has seen, so the feed treats them all as new.
    func reset(userId: String) {
        load(userId)
        seen = [:]
        hasUnsavedChanges = true
        flush()
    }

    /// Writes any unsaved changes now, as the app goes to the background.
    func flush() {
        saveTask?.cancel()
        saveTask = nil
        save()
    }

    // MARK: - File

    private func load(_ userId: String) {
        guard userId != self.userId else { return }
        // Another account signed in: the previous one's changes go to its own file first
        flush()
        self.userId = userId
        seen = [:]
        hasUnsavedChanges = false
        guard let url = Self.fileURL(for: userId), FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let stored = try JSONDecoder().decode([String: Date].self, from: Data(contentsOf: url))
            seen = Self.pruned(stored, now: Date())
        } catch {
            logger.error("Seen posts read failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func scheduleSave() {
        guard saveTask == nil else { return }
        saveTask = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            saveTask = nil
            save()
        }
    }

    private func save() {
        guard hasUnsavedChanges, let userId, let url = Self.fileURL(for: userId) else { return }
        seen = Self.pruned(seen, now: Date())
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(seen).write(to: url, options: .atomic)
            hasUnsavedChanges = false
        } catch {
            logger.error("Seen posts save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func fileURL(for userId: String) -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("SeenPosts", isDirectory: true)
            .appendingPathComponent("\(userId).json")
    }

    /// Drops posts seen before the cutoff, then all but the newest `maxCount`
    private static func pruned(_ seen: [String: Date], now: Date) -> [String: Date] {
        let recent = seen.filter { now.timeIntervalSince($0.value) < maxAge }
        guard recent.count > maxCount else { return recent }
        return Dictionary(uniqueKeysWithValues: recent.sorted { $0.value > $1.value }.prefix(maxCount).map { ($0.key, $0.value) })
    }
}
