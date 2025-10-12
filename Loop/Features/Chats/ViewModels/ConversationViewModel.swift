import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
final class ConversationViewModel {
    private(set) var messages: [Message] = []
    private(set) var isLoading = false
    var messageText = ""
    private(set) var isOtherUserTyping = false

    private var messageListener: ListenerRegistration?
    private var typingListener: ListenerRegistration?
    private var typingDebounceTask: Task<Void, Never>?
    private let chatId: String
    private let firebaseService = FirebaseService.shared

    init(chatId: String) {
        self.chatId = chatId
        loadMessages()
        setupMessageListener()
        setupTypingListener()
    }

    @MainActor
    deinit {
        print("🗑️ ConversationViewModel deinit called for chat: \(chatId)")
        
        // Cancel tasks first
        typingDebounceTask?.cancel()
        
        // Remove listeners
        messageListener?.remove()
        typingListener?.remove()
        
        // Clear typing status synchronously without creating new Task
        // We can't use async/await in deinit, so we'll let it clean up naturally via timeout
        // or do it synchronously
        let chatId = self.chatId
        let firebaseService = self.firebaseService
        
        // Fire and forget - don't capture self
        Task.detached {
            try? await firebaseService.setTypingStatus(chatId: chatId, isTyping: false)
            print("🗑️ Cleared typing status on deinit")
        }
    }

    private func loadMessages() {
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                await MainActor.run { self.isLoading = true }
                let messages = try await self.firebaseService.getMessages(forChatId: self.chatId)
                await MainActor.run {
                    self.messages = messages
                    self.isLoading = false
                }
            } catch {
                print("Error loading messages: \(error)")
                await MainActor.run { self.isLoading = false }
            }
        }
    }

    private func setupMessageListener() {
        messageListener = firebaseService.listenForMessages(chatId: chatId) { [weak self] messages in
            guard let self = self else { return }
            
            self.messages = messages
            
            // Mark chat as read IMMEDIATELY when new messages arrive while viewing
            // Use Task with high priority to minimize delay
            Task(priority: .userInitiated) { [weak self] in
                guard let self = self else { return }
                try? await self.firebaseService.markChatAsRead(chatId: self.chatId)
            }
        }
    }
    
    private func setupTypingListener() {
        print("🔍 Setting up typing listener for chat: \(chatId)")
        typingListener = firebaseService.listenForTypingStatus(chatId: chatId) { [weak self] typingUsers in
            guard let self = self else { return }
            
            print("🔍 Typing status update received: \(typingUsers.count) users")
            for (userId, timestamp) in typingUsers {
                print("   - User \(userId) typing at \(timestamp)")
            }
            
            // Filter out stale typing indicators (older than 5 seconds)
            let fiveSecondsAgo = Date().addingTimeInterval(-5)
            let activeTypingUsers = typingUsers.filter { $0.value > fiveSecondsAgo }
            
            let wasTyping = self.isOtherUserTyping
            let shouldBeTyping = !activeTypingUsers.isEmpty
            
            if shouldBeTyping != wasTyping {
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isOtherUserTyping = shouldBeTyping
                }
                
                if shouldBeTyping {
                    print("💬 Someone is typing... (showing indicator)")
                } else {
                    print("💬 Typing stopped (hiding indicator)")
                }
            }
        }
    }
    
    func onTextChanged() {
        print("⌨️ Text changed: '\(messageText)'")
        
        // Cancel previous debounce task
        typingDebounceTask?.cancel()
        
        // Set typing status immediately when user starts typing
        if !messageText.isEmpty {
            print("⌨️ Setting typing status to TRUE")
            Task { [weak self] in
                guard let self = self else { return }
                try? await self.firebaseService.setTypingStatus(chatId: self.chatId, isTyping: true)
            }
        } else {
            print("⌨️ Text is empty, clearing typing status")
            Task { [weak self] in
                guard let self = self else { return }
                try? await self.firebaseService.setTypingStatus(chatId: self.chatId, isTyping: false)
            }
        }
        
        // Debounce: Clear typing status after 2 seconds of no typing
        typingDebounceTask = Task { [weak self] in
            guard let self = self else { return }
            
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            if !Task.isCancelled {
                await MainActor.run {
                    print("⌨️ 2 seconds passed, clearing typing status")
                }
                try? await self.firebaseService.setTypingStatus(chatId: self.chatId, isTyping: false)
            }
        }
    }

    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let content = messageText
        messageText = ""
        
        // Cancel any pending typing debounce
        typingDebounceTask?.cancel()

        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                // Clear typing status before sending
                try? await self.firebaseService.setTypingStatus(chatId: self.chatId, isTyping: false)
                
                try await self.firebaseService.sendMessage(chatId: self.chatId, content: content)
            } catch {
                print("Error sending message: \(error)")
                // Restore message text on error
                await MainActor.run {
                    self.messageText = content
                }
            }
        }
    }
}
