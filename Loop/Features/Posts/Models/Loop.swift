import Foundation
import SwiftUI

enum LoopMediaType: String, Codable, CaseIterable {
    case text = "text"
    case image = "image"
    case video = "video"
    
    var iconName: String {
        switch self {
        case .text:
            return "text.alignleft"
        case .image:
            return "photo"
        case .video:
            return "video"
        }
    }
}

struct LoopMedia: Identifiable, Codable, Hashable {
    let id: String
    let type: LoopMediaType
    let url: String
    let thumbnailURL: String?
    let width: Double?
    let height: Double?
    
    init(id: String = UUID().uuidString, type: LoopMediaType, url: String, thumbnailURL: String? = nil, width: Double? = nil, height: Double? = nil) {
        self.id = id
        self.type = type
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.width = width
        self.height = height
    }
}

struct Loop: Identifiable, Codable, Hashable {
    let id: String
    let authorId: String
    let content: String
    let media: [LoopMedia]
    let createdAt: Date
    let updatedAt: Date
    let likes: [String] // Array of user IDs who liked this loop
    let replies: [String] // Array of reply loop IDs
    let isReply: Bool
    let parentLoopId: String? // If this is a reply, the parent loop ID (root post)
    let replyToReplyId: String? // If this is a reply to another reply
    
    // Cached author info for performance
    var authorDisplayName: String?
    var authorUsername: String?
    var authorAvatarURL: String?
    var authorBadgeType: BadgeType?
    
    init(
        id: String = UUID().uuidString,
        authorId: String,
        content: String,
        media: [LoopMedia] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        likes: [String] = [],
        replies: [String] = [],
        isReply: Bool = false,
        parentLoopId: String? = nil,
        replyToReplyId: String? = nil,
        authorDisplayName: String? = nil,
        authorUsername: String? = nil,
        authorAvatarURL: String? = nil,
        authorBadgeType: BadgeType? = nil
    ) {
        self.id = id
        self.authorId = authorId
        self.content = content
        self.media = media
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.likes = likes
        self.replies = replies
        self.isReply = isReply
        self.parentLoopId = parentLoopId
        self.replyToReplyId = replyToReplyId
        self.authorDisplayName = authorDisplayName
        self.authorUsername = authorUsername
        self.authorAvatarURL = authorAvatarURL
        self.authorBadgeType = authorBadgeType
    }
    
    // MARK: - Computed Properties
    
    var likeCount: Int {
        return likes.count
    }
    
    var replyCount: Int {
        return replies.count
    }
    
    var hasMedia: Bool {
        return !media.isEmpty
    }
    
    var primaryMediaType: LoopMediaType? {
        return media.first?.type
    }
    
    /// Returns a formatted time string for display
    var timeAgoString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    /// Returns the display name to show for the author
    var displayAuthorName: String {
        if let displayName = authorDisplayName, !displayName.isEmpty {
            return displayName
        } else if let username = authorUsername, !username.isEmpty {
            return "@\(username)"
        } else {
            return "Unknown User"
        }
    }
    
    /// Returns the username with @ prefix if available
    var formattedUsername: String? {
        guard let username = authorUsername, !username.isEmpty else { return nil }
        return "@\(username)"
    }
}

// MARK: - Loop Creation Helper

struct LoopDraft {
    var content: String = ""
    var media: [LoopMedia] = []
    var isReply: Bool = false
    var parentLoopId: String?
    var replyToReplyId: String? // If replying to another reply
    
    var isValid: Bool {
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !media.isEmpty
    }
    
    var characterCount: Int {
        return content.count
    }
    
    static let maxCharacterCount = 280 // Twitter-like limit
    
    var isWithinCharacterLimit: Bool {
        return characterCount <= Self.maxCharacterCount
    }
    
    var remainingCharacters: Int {
        return Self.maxCharacterCount - characterCount
    }
}
