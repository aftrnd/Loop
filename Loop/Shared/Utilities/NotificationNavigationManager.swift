import Foundation
import SwiftUI
import Combine

/// Manages navigation from push notifications to specific chats
@MainActor
class NotificationNavigationManager: ObservableObject {
    static let shared = NotificationNavigationManager()
    
    @Published var chatToOpen: String?
    
    private init() {
        // Listen for notification taps
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenChat),
            name: NSNotification.Name("OpenChat"),
            object: nil
        )
    }
    
    @objc private func handleOpenChat(_ notification: Notification) {
        guard let chatId = notification.object as? String else { return }
        print("📱 Opening chat from notification: \(chatId)")
        chatToOpen = chatId
    }
    
    func clearNavigation() {
        chatToOpen = nil
    }
}

