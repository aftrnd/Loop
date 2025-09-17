import Foundation

struct Chat: Identifiable, Hashable {
    let id: UUID
    var title: String
    var lastMessagePreview: String
    var unreadCount: Int
    var messages: [Message]
    var lastMessageTime: Date

    init(id: UUID = UUID(), title: String, lastMessagePreview: String, unreadCount: Int = 0, messages: [Message] = [], lastMessageTime: Date = Date()) {
        self.id = id
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.unreadCount = unreadCount
        self.messages = messages
        self.lastMessageTime = lastMessageTime
    }
}