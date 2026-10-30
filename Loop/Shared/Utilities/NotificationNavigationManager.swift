import Foundation
import Observation

extension Notification.Name {
    /// Posted when a chat notification is tapped. The object is the chat ID.
    static let openChat = Notification.Name("OpenChat")
}

/// Holds the chat a notification tap asked to open until the Messages tab can show it.
/// MainTabView switches to Messages when a request arrives; ChatsListView opens the chat once its list has loaded.
@MainActor
@Observable
final class NotificationNavigationManager {
    static let shared = NotificationNavigationManager()

    private(set) var pendingChatID: String?

    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    private init() {
        observer = NotificationCenter.default.addObserver(forName: .openChat, object: nil, queue: .main) { [weak self] notification in
            guard let chatID = notification.object as? String else { return }
            // Delivered on the main queue
            MainActor.assumeIsolated {
                self?.pendingChatID = chatID
            }
        }
    }

    /// Takes the pending request, so it is handled once.
    func consumePendingChat() -> String? {
        guard let chatID = pendingChatID else { return nil }
        pendingChatID = nil
        return chatID
    }
}
