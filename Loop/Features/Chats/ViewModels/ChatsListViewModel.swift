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
                self.recent = chats
                self.pinned = Array(chats.prefix(3)) // First 3 become pinned
            } catch {
                print("Error loading chats: \(error)")
            }
        }
    }

    func setupRealTimeUpdates() {
        chatListener = FirebaseService.shared.listenForChats { [weak self] chats in
            self?.recent = chats
            self?.pinned = Array(chats.prefix(3))
        }
    }

    // MARK: - Public Methods

    func createChat(with phoneNumber: String, displayName: String) async throws {
        guard let currentUserId = FirebaseService.shared.getCurrentUser()?.id else {
            throw NSError(domain: "ChatsListViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }

        // Create the chat in Firestore
        let chat = try await FirebaseService.shared.createChat(withUserId: currentUserId, title: displayName)

        // Update local state
        self.recent.append(chat)
        if self.pinned.isEmpty {
            self.pinned.append(chat)
        }
    }

    func refreshChats() {
        Task {
            do {
                let chats = try await FirebaseService.shared.getChats()
                self.recent = chats
                self.pinned = Array(chats.prefix(3))
            } catch {
                print("Error refreshing chats: \(error)")
            }
        }
    }
    
    func deleteChat(withId id: UUID) {
        pinned.removeAll { $0.id == id }
        recent.removeAll { $0.id == id }
    }
    
    func deletePinnedChats(at offsets: IndexSet) {
        pinned.remove(atOffsets: offsets)
    }
    
    func deleteRecentChats(at offsets: IndexSet) {
        recent.remove(atOffsets: offsets)
    }
}
