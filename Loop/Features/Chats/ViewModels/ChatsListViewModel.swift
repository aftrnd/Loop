import Foundation
import SwiftUI
import FirebaseFirestore
import UIKit

@MainActor
@Observable
final class ChatsListViewModel {
    private(set) var pinned: [Chat] = []
    private(set) var recent: [Chat] = []
    private(set) var isLoadingInitialData = true
    private var chatListener: ListenerRegistration?
    private let pinnedChatsKey = "pinnedChatIDs"
    
    // Computed property for total unread message count
    var totalUnreadCount: Int {
        let allChats = pinned + recent
        let total = allChats.reduce(0) { $0 + $1.unreadCount }
        if total > 0 {
            print("🔴 Total unread count: \(total)")
            for chat in allChats where chat.unreadCount > 0 {
                print("   - Chat '\(chat.displayTitle)': \(chat.unreadCount) unread")
            }
        }
        
        // Update app icon badge
        updateAppBadge(count: total)
        
        return total
    }
    
    // Update app icon badge count
    private func updateAppBadge(count: Int) {
        Task { @MainActor in
            UNUserNotificationCenter.current().setBadgeCount(count)
            print("📱 App badge count updated to: \(count)")
        }
    }

    init() {
        Task {
            await loadInitialChats()
        }
        setupRealTimeUpdates()
    }

    // MARK: - Helper Methods

    @MainActor
    deinit {
        chatListener?.remove()
    }

    private func loadInitialChats() async {
        isLoadingInitialData = true
        print("🔵 Loading initial chat data...")
        do {
            let chats = try await FirebaseService.shared.getChats()
            print("✅ Loaded \(chats.count) chats with user data")
            mergeChats(chats)
            applyStoredPinnedState()
            isLoadingInitialData = false
        } catch {
            print("❌ Error loading initial chats: \(error)")
            isLoadingInitialData = false
        }
    }
    
    private func loadChats() {
        Task {
            do {
                let chats = try await FirebaseService.shared.getChats()
                mergeChats(chats)
                applyStoredPinnedState()
            } catch {
                print("Error loading chats: \(error)")
            }
        }
    }

    private func savePinnedChatsToStorage() {
        let pinnedIDs = pinned.map { $0.id.uuidString }
        UserDefaults.standard.set(pinnedIDs, forKey: pinnedChatsKey)
    }


    private func applyStoredPinnedState() {
        guard let pinnedIDs = UserDefaults.standard.stringArray(forKey: pinnedChatsKey) else {
            return
        }

        let uuids = pinnedIDs.compactMap { UUID(uuidString: $0) }

        // Only apply changes if there are actually stored pinned chats
        if uuids.isEmpty {
            return
        }

        // Create a set of all available chats for quick lookup
        let allChats = recent + pinned

        // Create dictionary with proper duplicate handling
        var allChatDict: [UUID: Chat] = [:]
        for chat in allChats {
            allChatDict[chat.id] = chat  // Last one wins in case of duplicates
        }

        // Determine which chats should be pinned vs recent
        var newPinned: [Chat] = []
        var newRecent: [Chat] = []

        for chat in allChats {
            if uuids.contains(chat.id) {
                // This chat should be pinned
                newPinned.append(chat)
            } else {
                // This chat should be in recents
                newRecent.append(chat)
            }
        }

        // Remove duplicates from the new arrays
        newPinned = removeDuplicates(newPinned)
        newRecent = removeDuplicates(newRecent)

        // Only update if there are actually changes needed
        let currentPinnedIDs = Set(pinned.map { $0.id })
        let targetPinnedIDs = Set(newPinned.map { $0.id })

        if currentPinnedIDs != targetPinnedIDs {
            // Apply the changes
            pinned = newPinned
            recent = newRecent

            print("🔄 DEBUG: Applied stored pinned state - Pinned: \(pinned.count), Recent: \(recent.count)")
        } else {
            print("🔄 DEBUG: Stored pinned state already correct - no changes needed")
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
        // Create dictionaries with proper duplicate handling
        var newChatDict: [UUID: Chat] = [:]
        for chat in newChats {
            newChatDict[chat.id] = chat  // Last one wins for duplicates
        }

        // Create a dictionary of existing chats by ID for quick lookup
        var existingChatDict: [UUID: Chat] = [:]
        for chat in recent {
            existingChatDict[chat.id] = chat  // Last one wins for duplicates
        }

        // Track if we actually made changes
        var changesMade = false

        // Merge new chats - update existing or add new
        for (id, chat) in newChatDict {
            existingChatDict[id] = chat
            changesMade = true
        }

        // Only update if we actually made changes
        if changesMade {
            // Update the recent array with merged chats
            recent = removeDuplicates(Array(existingChatDict.values))

            // Also update pinned chats if they exist in the new data
            var pinnedChatDict: [UUID: Chat] = [:]
            for chat in pinned {
                pinnedChatDict[chat.id] = chat
            }
            for (id, chat) in newChatDict where pinnedChatDict[id] != nil {
                pinnedChatDict[id] = chat
            }
            pinned = removeDuplicates(Array(pinnedChatDict.values))
        }
    }

    // MARK: - Public Methods

    func createChat(with phoneNumber: String, displayName: String) async throws {
        guard let currentUserId = FirebaseService.shared.getCurrentUser()?.id else {
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
        let chat = try await FirebaseService.shared.createChat(withUserId: otherUser.id, title: chatTitle)

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

    func refreshChats() async {
        do {
            print("🔄 Fetching fresh chat data from Firebase...")
            let chats = try await FirebaseService.shared.getChats()
            print("✅ Received \(chats.count) chats with fresh data")
            mergeChats(chats)
        } catch {
            print("❌ Error refreshing chats: \(error)")
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

        // Save pinned state to UserDefaults (removes deleted chat from stored pins)
        savePinnedChatsToStorage()
    }
    
    func deletePinnedChats(at offsets: IndexSet) {
        pinned.remove(atOffsets: offsets)
        savePinnedChatsToStorage()
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

        // Save pinned state to UserDefaults
        savePinnedChatsToStorage()
    }

    func unpinChat(_ chat: Chat) {
        // Remove from pinned
        pinned.removeAll { $0.id == chat.id }

        // Add to recent at the top
        recent.removeAll { $0.id == chat.id } // Remove if it exists
        recent.insert(chat, at: 0)

        // Save pinned state to UserDefaults
        savePinnedChatsToStorage()
    }

    func isChatPinned(_ chat: Chat) -> Bool {
        pinned.contains(where: { $0.id == chat.id })
    }
}

