import Foundation
import Combine
import SwiftUI

@MainActor
final class ChatsListViewModel: ObservableObject {
    @Published private(set) var pinned: [Chat] = []
    @Published private(set) var recent: [Chat] = []

    init() {
        // Seed with a richer set of sample data. In a real app, this would
        // load from persistence or a service.
        let now = Date()
        let sample: [Chat] = [
            Chat(title: "Design Team",
                 lastMessagePreview: "Pushing the latest glass tokens",
                 unreadCount: 3,
                 lastMessageTime: now.addingTimeInterval(-60 * 4)),
            Chat(title: "Family",
                 lastMessagePreview: "Dinner at 7?",
                 unreadCount: 0,
                 lastMessageTime: now.addingTimeInterval(-60 * 60)),
            Chat(title: "Alex",
                 lastMessagePreview: "Sending the files now.",
                 unreadCount: 5,
                 lastMessageTime: now.addingTimeInterval(-60 * 30)),
            Chat(title: "Jordan",
                 lastMessagePreview: "This weekend works for me",
                 unreadCount: 0,
                 lastMessageTime: now.addingTimeInterval(-60 * 90)),
            Chat(title: "Product Squad",
                 lastMessagePreview: "Spec v2: add carousel interactions",
                 unreadCount: 1,
                 lastMessageTime: now.addingTimeInterval(-60 * 10)),
            Chat(title: "Casey",
                 lastMessagePreview: "Love the new message bubbles!",
                 unreadCount: 0,
                 lastMessageTime: now.addingTimeInterval(-60 * 200)),
            Chat(title: "Priya",
                 lastMessagePreview: "Got it, thanks!",
                 unreadCount: 2,
                 lastMessageTime: now.addingTimeInterval(-60 * 8)),
            Chat(title: "Marketing",
                 lastMessagePreview: "Campaign goes live Monday",
                 unreadCount: 0,
                 lastMessageTime: now.addingTimeInterval(-60 * 240)),
            Chat(title: "Mom",
                 lastMessagePreview: "Call me when you can",
                 unreadCount: 1,
                 lastMessageTime: now.addingTimeInterval(-60 * 15)),
            Chat(title: "Taylor",
                 lastMessagePreview: "Let's climb Saturday",
                 unreadCount: 0,
                 lastMessageTime: now.addingTimeInterval(-60 * 300)),
            Chat(title: "Finance",
                 lastMessagePreview: "Invoice approved",
                 unreadCount: 0,
                 lastMessageTime: now.addingTimeInterval(-60 * 120)),
            Chat(title: "Joe Monaco",
                 lastMessagePreview: "Let's sync at 2pm",
                 unreadCount: 2,
                 lastMessageTime: now.addingTimeInterval(-60 * 5)),
            Chat(title: "Support",
                 lastMessagePreview: "Issue #453 resolved",
                 unreadCount: 0,
                 lastMessageTime: now.addingTimeInterval(-60 * 55)),
            Chat(title: "Sam",
                 lastMessagePreview: "On my way",
                 unreadCount: 0,
                 lastMessageTime: now.addingTimeInterval(-60 * 12)),
            Chat(title: "Engineering",
                 lastMessagePreview: "CI green on main",
                 unreadCount: 4,
                 lastMessageTime: now.addingTimeInterval(-60 * 3))
        ]
        self.pinned = Array(sample.prefix(3))
        self.recent = Array(sample.dropFirst(3))
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
