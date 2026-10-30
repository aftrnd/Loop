import Foundation
import SwiftUI
import FirebaseFirestore
import os

@MainActor
@Observable
final class ConversationViewModel {
    private(set) var messages: [Message] = []
    private(set) var isLoading = true // Start as loading to prevent empty state flash
    var messageText = ""
    private(set) var isOtherUserTyping = false
    /// Changes whenever any message's like count changes: a cheap value for the list's like animation.
    private(set) var likesRevision = 0

    /// Readers ignore typing timestamps older than this, left behind by an app that stopped before clearing them.
    private static let typingStaleInterval: TimeInterval = 5
    /// While the user keeps typing, the typing timestamp is rewritten at most this often.
    private static let typingRefreshInterval: TimeInterval = 3
    /// Typing is cleared after this long without a change to the text.
    private static let typingIdleTimeout: Duration = .seconds(2)

    private let chat: Chat
    private let firebaseService = FirebaseService.shared
    private let logger = Logger(subsystem: "com.nejack.Loop", category: "ConversationViewModel")

    @ObservationIgnored private var messageListener: ListenerRegistration?
    @ObservationIgnored private var activityListener: ListenerRegistration?
    @ObservationIgnored private var typingIdleTask: Task<Void, Never>?
    /// When the typing timestamp was last written. Nil while nobody sees this user as typing.
    @ObservationIgnored private var lastTypingWrite: Date?

    private var chatId: String {
        chat.id.uuidString
    }

    /// Does no work: call `start()` when the conversation appears and `stop()` when it goes away.
    init(chat: Chat) {
        self.chat = chat
    }

    deinit {
        messageListener?.remove()
        activityListener?.remove()
        typingIdleTask?.cancel()
    }

    // MARK: - Lifecycle

    /// Starts the message and chat activity listeners. Safe to call again; they only start once.
    func start() {
        guard messageListener == nil else { return }

        messageListener = firebaseService.listenForMessages(chatId: chatId) { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let messages):
                self.setMessages(messages)
            case .failure(let error):
                self.logger.error("Message listener failed: \(error.localizedDescription, privacy: .public)")
            }
            self.isLoading = false
        }

        activityListener = firebaseService.listenForChatActivity(chatId: chatId) { [weak self] activity in
            self?.apply(activity)
        }

        if messageListener == nil {
            // Nobody is signed in, so there is nothing to load
            isLoading = false
        }
    }

    /// Removes the listeners and clears this user's typing indicator if others can see it.
    func stop() {
        messageListener?.remove()
        messageListener = nil
        activityListener?.remove()
        activityListener = nil
        stopTyping()
    }

    private func setMessages(_ newMessages: [Message]) {
        guard newMessages != messages else { return }
        if newMessages.map(\.likeCount) != messages.map(\.likeCount) {
            likesRevision &+= 1
        }
        messages = newMessages
    }

    private func apply(_ activity: ChatActivity) {
        let staleCutoff = Date().addingTimeInterval(-Self.typingStaleInterval)
        let shouldShowTyping = activity.typingUsers.values.contains { $0 > staleCutoff }

        if shouldShowTyping != isOtherUserTyping {
            withAnimation(.easeInOut(duration: 0.2)) {
                isOtherUserTyping = shouldShowTyping
            }
        }

        // Messages that arrive while the conversation is open are read; reset the count only when there is one
        if activity.unreadCount > 0 {
            markAsRead()
        }
    }

    private func markAsRead() {
        Task {
            do {
                try await firebaseService.markChatAsRead(chatId: chatId)
            } catch {
                logger.error("Marking the chat as read failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Typing

    /// Shows this user as typing to the others, rewriting the timestamp at most every few seconds,
    /// and clears it after a pause.
    func onTextChanged() {
        typingIdleTask?.cancel()

        guard !messageText.isEmpty else {
            stopTyping()
            return
        }

        let now = Date()
        if lastTypingWrite.map({ now.timeIntervalSince($0) >= Self.typingRefreshInterval }) ?? true {
            lastTypingWrite = now
            writeTypingStatus(true)
        }

        typingIdleTask = Task {
            try? await Task.sleep(for: Self.typingIdleTimeout)
            guard !Task.isCancelled else { return }
            self.stopTyping()
        }
    }

    private func stopTyping() {
        typingIdleTask?.cancel()
        typingIdleTask = nil

        guard lastTypingWrite != nil else { return }
        lastTypingWrite = nil
        writeTypingStatus(false)
    }

    private func writeTypingStatus(_ isTyping: Bool) {
        // Captured up front so a write started by stop() doesn't keep the view model alive
        let chatId = chatId
        let firebaseService = firebaseService
        let logger = logger

        Task {
            do {
                try await firebaseService.setTypingStatus(chatId: chatId, isTyping: isTyping)
            } catch {
                logger.error("Updating typing status failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    // MARK: - Actions

    func sendMessage() {
        let content = messageText
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        messageText = ""

        // The send batch also clears the typing indicator, so no separate write is needed
        typingIdleTask?.cancel()
        typingIdleTask = nil
        lastTypingWrite = nil

        Task {
            do {
                try await firebaseService.sendMessage(chatId: chatId, content: content, participants: chat.participants)
            } catch {
                logger.error("Sending a message failed: \(error.localizedDescription, privacy: .public)")
                // Put the text back, unless the user has started typing something else since
                if messageText.isEmpty {
                    messageText = content
                }
            }
        }
    }

    /// Flips the like locally, then writes it. Firestore applies the write to the message listener right away,
    /// so snapshots that arrive while the write is in flight already agree with the local state.
    func toggleLike(for message: Message) {
        guard let currentUserId = firebaseService.getCurrentUser()?.id,
              let current = messages.first(where: { $0.id == message.id }) else {
            return
        }

        // Read the current state rather than the bubble's captured copy, so quick repeat taps alternate
        let wasLiked = current.isLikedBy(userId: currentUserId)
        setLiked(!wasLiked, messageId: message.id, userId: currentUserId)

        Task {
            do {
                if wasLiked {
                    try await firebaseService.unlikeMessage(chatId: chatId, messageId: message.id.uuidString)
                } else {
                    try await firebaseService.likeMessage(chatId: chatId, messageId: message.id.uuidString)
                }
            } catch {
                logger.error("Toggling a message like failed: \(error.localizedDescription, privacy: .public)")
                setLiked(wasLiked, messageId: message.id, userId: currentUserId)
            }
        }
    }

    private func setLiked(_ liked: Bool, messageId: UUID, userId: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }

        var likedBy = messages[index].likedBy
        likedBy.removeAll { $0 == userId }
        if liked {
            likedBy.append(userId)
        }
        messages[index].likedBy = likedBy
        likesRevision &+= 1
    }
}
