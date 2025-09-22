import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
final class ConversationViewModel {
    private(set) var messages: [Message] = []
    private(set) var isLoading = false
    var messageText = ""

    private var messageListener: ListenerRegistration?
    private let chatId: String
    private let firebaseService = FirebaseService.shared

    init(chatId: String) {
        self.chatId = chatId
        loadMessages()
        setupMessageListener()
    }

    @MainActor
    deinit {
        messageListener?.remove()
    }

    private func loadMessages() {
        Task {
            do {
                isLoading = true
                let messages = try await firebaseService.getMessages(forChatId: chatId)
                self.messages = messages
                isLoading = false
            } catch {
                print("Error loading messages: \(error)")
                isLoading = false
            }
        }
    }

    private func setupMessageListener() {
        messageListener = firebaseService.listenForMessages(chatId: chatId) { [weak self] messages in
            self?.messages = messages
        }
    }

    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let content = messageText
        messageText = ""

        Task {
            do {
                try await firebaseService.sendMessage(chatId: chatId, content: content, isFromUser: true)
            } catch {
                print("Error sending message: \(error)")
                // Restore message text on error
                self.messageText = content
            }
        }
    }
}
