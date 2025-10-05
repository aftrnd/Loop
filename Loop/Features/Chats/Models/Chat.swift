import Foundation

struct Chat: Identifiable, Hashable {
    let id: UUID
    var title: String
    var lastMessagePreview: String
    var unreadCount: Int
    var messages: [Message]
    var lastMessageTime: Date
    var participants: [String] // Array of user IDs
    var otherParticipantId: String? // For 1-on-1 chats, the other user's ID

    init(id: UUID = UUID(), title: String, lastMessagePreview: String, unreadCount: Int = 0, messages: [Message] = [], lastMessageTime: Date = Date(), participants: [String] = [], otherParticipantId: String? = nil) {
        self.id = id
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.unreadCount = unreadCount
        self.messages = messages
        self.lastMessageTime = lastMessageTime
        self.participants = participants
        self.otherParticipantId = otherParticipantId
    }
}