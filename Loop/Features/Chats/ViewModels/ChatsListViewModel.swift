import Foundation
import SwiftUI
import FirebaseFirestore
import UserNotifications
import os

@MainActor
@Observable
final class ChatsListViewModel {
    /// The pinned grid has two rows of three.
    static let maxPinnedChats = 6

    private(set) var pinned: [Chat] = []
    private(set) var recent: [Chat] = []
    private(set) var isLoadingInitialData = true

    var totalUnreadCount: Int {
        pinned.reduce(0) { $0 + $1.unreadCount } + recent.reduce(0) { $0 + $1.unreadCount }
    }

    var canPinMoreChats: Bool {
        pinned.count < Self.maxPinnedChats
    }

    private let pinnedChatsKey = "pinnedChatIDs"
    private let logger = Logger(subsystem: "com.nejack.Loop", category: "ChatsListViewModel")

    @ObservationIgnored private var chatListener: ListenerRegistration?
    @ObservationIgnored private var snapshotTask: Task<Void, Never>?
    /// The latest snapshot from the listener, kept so pull to refresh can re-resolve profiles without a new read.
    @ObservationIgnored private var latestDocuments: [QueryDocumentSnapshot]?
    /// Every visible chat, newest first, as of the latest snapshot.
    @ObservationIgnored private var chats: [Chat] = []
    @ObservationIgnored private var pinnedIDs: Set<UUID> = []
    @ObservationIgnored private var appliedBadgeCount: Int?

    deinit {
        chatListener?.remove()
    }

    // MARK: - Loading

    /// Starts the live listener on the user's chats. Safe to call again; it only starts once.
    func start() {
        guard chatListener == nil else { return }

        pinnedIDs = loadPinnedIDs()
        chatListener = FirebaseService.shared.listenForChats { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let documents):
                self.resolve(documents)
            case .failure(let error):
                self.logger.error("Chat listener failed: \(error.localizedDescription, privacy: .public)")
                self.isLoadingInitialData = false
            }
        }

        if chatListener == nil {
            // Nobody is signed in, so there is nothing to load
            isLoadingInitialData = false
        }
    }

    /// Re-reads the chat partners' profiles. The chats themselves are already live through the listener.
    func refreshChats() async {
        FirebaseService.shared.invalidateUserCache()
        guard let latestDocuments else { return }
        await resolve(latestDocuments).value
    }

    /// Turns a snapshot into chats. A newer snapshot cancels one that is still waiting on profiles.
    @discardableResult
    private func resolve(_ documents: [QueryDocumentSnapshot]) -> Task<Void, Never> {
        latestDocuments = documents
        snapshotTask?.cancel()

        let task = Task {
            let chats = await FirebaseService.shared.chats(from: documents)
            guard !Task.isCancelled else { return }
            self.chats = chats
            self.applyPinnedState()
            if self.isLoadingInitialData {
                self.isLoadingInitialData = false
            }
        }
        snapshotTask = task
        return task
    }

    // MARK: - Pinning

    /// Splits `chats` into pinned and recent, both newest first, and assigns only what changed.
    private func applyPinnedState() {
        var newPinned: [Chat] = []
        var newRecent: [Chat] = []

        for chat in chats {
            if pinnedIDs.contains(chat.id) && newPinned.count < Self.maxPinnedChats {
                newPinned.append(chat)
            } else {
                newRecent.append(chat)
            }
        }

        if newPinned != pinned {
            pinned = newPinned
        }
        if newRecent != recent {
            recent = newRecent
        }
        updateAppBadge()
    }

    func pinChat(_ chat: Chat) {
        guard canPinMoreChats else { return }
        pinnedIDs.insert(chat.id)
        applyPinnedState()
        savePinnedChatsToStorage()
    }

    func unpinChat(_ chat: Chat) {
        pinnedIDs.remove(chat.id)
        applyPinnedState()
        savePinnedChatsToStorage()
    }

    private func loadPinnedIDs() -> Set<UUID> {
        let stored = UserDefaults.standard.stringArray(forKey: pinnedChatsKey) ?? []
        return Set(stored.compactMap(UUID.init(uuidString:)))
    }

    private func savePinnedChatsToStorage() {
        // Only chats the grid shows stay pinned
        pinnedIDs = Set(pinned.map(\.id))
        UserDefaults.standard.set(pinned.map(\.id.uuidString), forKey: pinnedChatsKey)
    }

    // MARK: - Badge

    private func updateAppBadge() {
        let count = totalUnreadCount
        guard count != appliedBadgeCount else { return }
        appliedBadgeCount = count
        UNUserNotificationCenter.current().setBadgeCount(count)
    }

    // MARK: - Chat Actions

    func chat(withId id: String) -> Chat? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return chats.first { $0.id == uuid }
    }

    func createChat(with phoneNumber: String, displayName: String) async throws {
        guard FirebaseService.shared.getCurrentUser()?.id != nil else {
            throw NSError(domain: "ChatsListViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Format phone number to match Firebase format (assuming US: +1XXXXXXXXXX)
        let formattedPhone = formatPhoneNumber(phoneNumber)

        // Look up user by phone number
        guard let otherUser = try await FirebaseService.shared.getUserByPhoneNumber(formattedPhone) else {
            throw NSError(domain: "ChatsListViewModel", code: 2, userInfo: [NSLocalizedDescriptionKey: "User with phone number \(phoneNumber) not found. They may need to sign up first."])
        }

        // Use the actual display name from their profile, or fall back to generated name
        let chatTitle = otherUser.displayName ?? displayName

        // Create the chat with the other user's ID
        _ = try await FirebaseService.shared.createChat(withUserId: otherUser.id, title: chatTitle)

        // Don't immediately add to local state - let the real-time listener handle it
        // This prevents duplicates and ensures consistency with database state
    }

    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-digit characters
        let digits = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)

        // Validate we have enough digits for a US phone number
        guard digits.count == 10 else {
            // If already formatted with country code, return as is
            if phoneNumber.hasPrefix("+") {
                return phoneNumber
            }
            return phoneNumber // Return original if can't format
        }

        // Format as +1XXXXXXXXXX for Firebase
        return "+1" + digits
    }

    func deleteChat(withId id: UUID) async throws {
        // Deleting hides the chat for this user; the listener then drops it as well
        try await FirebaseService.shared.deleteChat(withId: id.uuidString)

        chats.removeAll { $0.id == id }
        pinnedIDs.remove(id)
        applyPinnedState()
        savePinnedChatsToStorage()
    }
}
