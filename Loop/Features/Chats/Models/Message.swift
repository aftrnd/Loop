import Foundation

struct Message: Identifiable, Hashable {
    let id: UUID
    let content: String
    let timestamp: Date
    let isFromUser: Bool
    let senderName: String?
    let senderId: String?
    var likedBy: [String] // Array of user IDs who liked this message
    
    init(id: UUID = UUID(), content: String, timestamp: Date = Date(), isFromUser: Bool, senderName: String? = nil, senderId: String? = nil, likedBy: [String] = []) {
        self.id = id
        self.content = content
        self.timestamp = timestamp
        self.isFromUser = isFromUser
        self.senderName = senderName
        self.senderId = senderId
        self.likedBy = likedBy
    }
    
    var likeCount: Int {
        return likedBy.count
    }
    
    func isLikedBy(userId: String) -> Bool {
        return likedBy.contains(userId)
    }
}