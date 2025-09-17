import Foundation

struct Message: Identifiable, Hashable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isFromUser: Bool
    let senderName: String?
    
    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), isFromUser: Bool, senderName: String? = nil) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isFromUser = isFromUser
        self.senderName = senderName
    }
}