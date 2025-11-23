import Foundation
import SwiftUI
import FirebaseFirestore

@MainActor
@Observable
final class ConversationViewModel {
    private(set) var messages: [Message] = []
    private(set) var isLoading = true // Start as loading to prevent empty state flash
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
    
    func toggleLike(for message: Message) {
        Task { [weak self] in
            guard let self = self else { return }
            guard let currentUserId = firebaseService.getCurrentUser()?.id else { return }
            
            let isCurrentlyLiked = message.isLikedBy(userId: currentUserId)
            let messageId = message.id.uuidString
            
            // Optimistic update
            if let index = messages.firstIndex(where: { $0.id == message.id }) {
                var updatedMessage = messages[index]
                var newLikedBy = updatedMessage.likedBy
                
                if isCurrentlyLiked {
                    newLikedBy.removeAll { $0 == currentUserId }
                } else {
                    newLikedBy.append(currentUserId)
                }
                
                updatedMessage = Message(
                    id: updatedMessage.id,
                    content: updatedMessage.content,
                    timestamp: updatedMessage.timestamp,
                    isFromUser: updatedMessage.isFromUser,
                    senderName: updatedMessage.senderName,
                    senderId: updatedMessage.senderId,
                    likedBy: newLikedBy
                )
                
                await MainActor.run {
                    messages[index] = updatedMessage
                }
            }
            
            // Perform backend operation
            do {
                if isCurrentlyLiked {
                    try await firebaseService.unlikeMessage(chatId: chatId, messageId: messageId)
                } else {
                    try await firebaseService.likeMessage(chatId: chatId, messageId: messageId)
                }
            } catch {
                print("❌ Error toggling like: \(error.localizedDescription)")
                
                // Revert optimistic update on error
                if let index = messages.firstIndex(where: { $0.id == message.id }) {
                    var revertedMessage = messages[index]
                    var revertedLikedBy = revertedMessage.likedBy
                    
                    if isCurrentlyLiked {
                        revertedLikedBy.append(currentUserId)
                    } else {
                        revertedLikedBy.removeAll { $0 == currentUserId }
                    }
                    
                    revertedMessage = Message(
                        id: revertedMessage.id,
                        content: revertedMessage.content,
                        timestamp: revertedMessage.timestamp,
                        isFromUser: revertedMessage.isFromUser,
                        senderName: revertedMessage.senderName,
                        senderId: revertedMessage.senderId,
                        likedBy: revertedLikedBy
                    )
                    
                    await MainActor.run {
                        messages[index] = revertedMessage
                    }
                }
            }
        }
    }
}
