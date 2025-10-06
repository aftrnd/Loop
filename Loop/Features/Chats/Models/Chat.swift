import Foundation

struct Chat: Identifiable, Hashable {
    let id: UUID
    var title: String // For group chats only
    var lastMessagePreview: String
    var unreadCount: Int
    var messages: [Message]
    var lastMessageTime: Date
    var participants: [String] // Array of user IDs
    var otherParticipantId: String? // For 1-on-1 chats, the other user's ID
    var otherParticipantDisplayName: String? // For 1-on-1 chats, the other user's current display name
    var otherParticipantAvatarURL: String? // For 1-on-1 chats, the other user's avatar URL

    init(id: UUID = UUID(), title: String, lastMessagePreview: String, unreadCount: Int = 0, messages: [Message] = [], lastMessageTime: Date = Date(), participants: [String] = [], otherParticipantId: String? = nil, otherParticipantDisplayName: String? = nil, otherParticipantAvatarURL: String? = nil) {
        self.id = id
        self.title = title
        self.lastMessagePreview = lastMessagePreview
        self.unreadCount = unreadCount
        self.messages = messages
        self.lastMessageTime = lastMessageTime
        self.participants = participants
        self.otherParticipantId = otherParticipantId
        self.otherParticipantDisplayName = otherParticipantDisplayName
        self.otherParticipantAvatarURL = otherParticipantAvatarURL
    }
    
    // MARK: - Computed Properties
    
    /// Determines if this is a group chat (more than 2 participants)
    var isGroupChat: Bool {
        return participants.count > 2
    }
    
    /// Returns the appropriate display title for this chat
    /// - For 1:1 chats: Returns the other participant's display name (always current)
    /// - For group chats: Returns the static group title
    var displayTitle: String {
        if isGroupChat {
            return title
        } else {
            return otherParticipantDisplayName ?? title
        }
    }
}