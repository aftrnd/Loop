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

    private func mergeChats(_ newChats: [Chat]) {
        // Create a dictionary of existing chats by ID for quick lookup
        var existingChatDict = Dictionary(uniqueKeysWithValues: recent.map { ($0.id, $0) })

        // Merge new chats, updating existing ones and adding new ones
        for chat in newChats {
            existingChatDict[chat.id] = chat
        }

        // Update the recent array with merged chats
        recent = Array(existingChatDict.values)

        // Also update pinned chats if they exist in the new data
        var pinnedChatDict = Dictionary(uniqueKeysWithValues: pinned.map { ($0.id, $0) })
        for chat in newChats where pinnedChatDict[chat.id] != nil {
            pinnedChatDict[chat.id] = chat
        }
        pinned = Array(pinnedChatDict.values)
    }

    // MARK: - Public Methods

    func createChat(with phoneNumber: String, displayName: String) async throws {
        guard let currentUserId = FirebaseService.shared.getCurrentUser()?.id else {
            throw NSError(domain: "ChatsListViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Create the chat in Firestore - for now, just use current user as the only participant
        // In a real app, this would be the other user's ID
        let chat = try await FirebaseService.shared.createChat(withUserId: currentUserId, title: displayName)

        // Update local state - new chats go to recents by default
        self.recent.append(chat)
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
