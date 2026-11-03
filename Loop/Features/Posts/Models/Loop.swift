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

/// The topic account a post comes from. Loop writes these posts from the news, so the account has no profile: its
/// posts carry its name and look, a squircle with its symbol, in a team's own colors and in ink for everything else.
struct LoopTopic: Codable, Hashable {
    let id: String
    /// An SF Symbol name
    let symbol: String
    /// A team's squircle color and its symbol's, as `#RRGGBB`
    let color: String
    let ink: String
    /// "article" for news topics, whose posts read as a newspaper article; nil for the photo cards
    var layout: String? = nil
    /// "team" for a team, whose squircle wears its colors; nil for every other topic, drawn in ink
    var style: String? = nil

    var isArticle: Bool {
        layout == "article"
    }

    var isTeam: Bool {
        style == "team"
    }
}

/// The news story a topic post is about, shown as a card under its text
struct LoopLink: Codable, Hashable {
    let url: String
    /// The publisher's own headline
    let title: String
    /// The publisher's name, such as ESPN
    let source: String
    /// The story's own preview image, as link previews show it
    let imageURL: String?
    /// A big story, shown with a taller photo
    let isLead: Bool
}

struct Loop: Identifiable, Codable, Hashable {
    let id: String
    let authorId: String
    let content: String
    let media: [LoopMedia]
    let createdAt: Date
    let updatedAt: Date
    var likes: [String] // Array of user IDs who liked this loop
    let replies: [String] // Array of reply loop IDs
    let isReply: Bool
    let parentLoopId: String? // If this is a reply, the parent loop ID (root post)
    let replyToReplyId: String? // If this is a reply to another reply
    
    // Cached author info for performance
    var authorDisplayName: String?
    var authorUsername: String?
    var authorAvatarURL: String?
    var authorBadgeType: BadgeType?
    
    /// Set on posts from topic accounts
    var topic: LoopTopic?
    /// The story a topic post links to
    var link: LoopLink?
    /// Claude's 1 to 5 rating of how big a topic post's story is for the topic's followers; the feed ranks by it
    var significance: Int?
    
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
        authorBadgeType: BadgeType? = nil,
        topic: LoopTopic? = nil,
        link: LoopLink? = nil,
        significance: Int? = nil
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
        self.topic = topic
        self.link = link
        self.significance = significance
    }
    
    // MARK: - Computed Properties
    
    var isTopicPost: Bool {
        topic != nil
    }
    
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
    
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
    
    /// Returns a formatted time string for display
    var timeAgoString: String {
        Self.relativeFormatter.localizedString(for: createdAt, relativeTo: Date())
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
    
    /// Returns a copy with the author details filled in from their profile. Topic posts keep their own: topic
    /// accounts have no profile
    func withAuthor(_ author: User?) -> Loop {
        guard !isTopicPost else { return self }
        var loop = self
        loop.authorDisplayName = author?.displayName
        loop.authorUsername = author?.username
        loop.authorAvatarURL = author?.avatarURL
        loop.authorBadgeType = author?.badgeType
        return loop
    }
}

// MARK: - Loop Creation Helper

struct LoopDraft {
    var content: String = ""
    var media: [LoopMedia] = []
    var isReply: Bool = false
    var parentLoopId: String?
    var replyToReplyId: String? // If replying to another reply
    
    init() {}
    
    /// A reply to a loop, or to one of its replies
    init(replyingTo parentLoopId: String, replyToReplyId: String? = nil) {
        isReply = true
        self.parentLoopId = parentLoopId
        self.replyToReplyId = replyToReplyId
    }
    
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
