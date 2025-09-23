import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
final class ChatsListViewModel {
    private(set) var pinned: [Chat] = []
    private(set) var recent: [Chat] = []
    private var chatListener: ListenerRegistration?

    init() {
        loadChats()
        setupRealTimeUpdates()
    }

    @MainActor
    deinit {
        chatListener?.remove()
    }

    private func loadChats() {
        Task {
            do {
                let chats = try await FirebaseService.shared.getChats()
                mergeChats(chats)
            } catch {
                print("Error loading chats: \(error)")
            }
        }
    }

    func setupRealTimeUpdates() {
        chatListener = FirebaseService.shared.listenForChats { [weak self] chats in
            self?.mergeChats(chats)
        }
    }

    private func removeDuplicates(_ chats: [Chat]) -> [Chat] {
        var seenIDs = Set<UUID>()
        return chats.filter { chat in
            if seenIDs.contains(chat.id) {
                return false
            } else {
                seenIDs.insert(chat.id)
                return true
            }
        }
    }

    private func mergeChats(_ newChats: [Chat]) {
        // Create a dictionary of new chats by ID for quick lookup
        let newChatDict = Dictionary(uniqueKeysWithValues: newChats.map { ($0.id, $0) })

        // Create a dictionary of existing chats by ID for quick lookup
        var existingChatDict = Dictionary(uniqueKeysWithValues: recent.map { ($0.id, $0) })

        // Merge new chats - only add if not already present
        for (id, chat) in newChatDict {
            if existingChatDict[id] == nil {
                existingChatDict[id] = chat
            }
        }

        // Update the recent array with merged chats (remove any duplicates just to be safe)
        let mergedRecent = Array(existingChatDict.values)
        recent = removeDuplicates(mergedRecent)

        // Also update pinned chats if they exist in the new data
        var pinnedChatDict = Dictionary(uniqueKeysWithValues: pinned.map { ($0.id, $0) })
        for (id, chat) in newChatDict where pinnedChatDict[id] != nil {
            pinnedChatDict[id] = chat
        }
        pinned = removeDuplicates(Array(pinnedChatDict.values))
    }

    // MARK: - Public Methods

    func createChat(with phoneNumber: String, displayName: String) async throws {
        guard let currentUserId = FirebaseService.shared.getCurrentUser()?.id else {
            throw NSError(domain: "ChatsListViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Create the chat in Firestore - for now, just use current user as the only participant
        // In a real app, this would be the other user's ID
        let chat = try await FirebaseService.shared.createChat(withUserId: currentUserId, title: displayName)

        // Don't immediately add to local state - let the real-time listener handle it
        // This prevents duplicates and ensures consistency with database state
    }

    func refreshChats() {
        Task {
            do {
                let chats = try await FirebaseService.shared.getChats()
                mergeChats(chats)
            } catch {
                print("Error refreshing chats: \(error)")
            }
        }
    }
    
    func deleteChat(withId id: UUID) async throws {
        // Find the chat to get its ID string for database deletion
        let chatToDelete = (pinned + recent).first { $0.id == id }
        guard let chatId = chatToDelete?.id.uuidString else { return }

        // Delete from database
        try await FirebaseService.shared.deleteChat(withId: chatId)

        // Remove from local state
        pinned.removeAll { $0.id == id }
        recent.removeAll { $0.id == id }
    }
    
    func deletePinnedChats(at offsets: IndexSet) {
        pinned.remove(atOffsets: offsets)
    }
    
    func deleteRecentChats(at offsets: IndexSet) {
        recent.remove(atOffsets: offsets)
    }

    func pinChat(_ chat: Chat) {
        // Remove from recent if it exists there
        recent.removeAll { $0.id == chat.id }

        // Add to pinned if not already there
        if !pinned.contains(where: { $0.id == chat.id }) {
            pinned.append(chat)
        }
    }

    func unpinChat(_ chat: Chat) {
        // Remove from pinned
        pinned.removeAll { $0.id == chat.id }

        // Add to recent at the top
        recent.removeAll { $0.id == chat.id } // Remove if it exists
        recent.insert(chat, at: 0)
    }

    func isChatPinned(_ chat: Chat) -> Bool {
        pinned.contains(where: { $0.id == chat.id })
    }
}
