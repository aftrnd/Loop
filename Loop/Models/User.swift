import Foundation
import FirebaseAuth
import SwiftUI

// Badge system for verified users
enum BadgeType: String, Codable, Equatable {
    case verified = "verified"  // Blue checkmark
    case premium = "premium"     // Gold checkmark
    
    var color: Color {
        switch self {
        case .verified:
            return .blue
        case .premium:
            return Color(red: 1.0, green: 0.84, blue: 0.0) // Gold
        }
    }
    
    var iconName: String {
        return "checkmark.seal.fill"
    }
}

struct User: Identifiable, Codable, Equatable {
    let id: String
    let phoneNumber: String
    let displayName: String?
    let username: String?
    let bio: String?
    let location: String?
    let avatarURL: String?
    let bannerURL: String?
    let badgeType: BadgeType?
    let followers: [String] // Array of user IDs who follow this user
    let following: [String] // Array of user IDs this user follows
    let createdAt: Date
    let lastSeen: Date
    
    // Computed properties for counts
    var followerCount: Int { followers.count }
    var followingCount: Int { following.count }
    
    init(from firebaseUser: FirebaseAuth.User) {
        self.id = firebaseUser.uid
        self.phoneNumber = firebaseUser.phoneNumber ?? ""
        self.displayName = firebaseUser.displayName
        self.username = nil // Will be loaded from Firestore
        self.bio = nil // Will be loaded from Firestore
        self.location = nil // Will be loaded from Firestore
        self.avatarURL = nil // Will be loaded from Firestore
        self.bannerURL = nil // Will be loaded from Firestore
        self.badgeType = nil // Will be loaded from Firestore
        self.followers = [] // Will be loaded from Firestore
        self.following = [] // Will be loaded from Firestore
        self.createdAt = Date()
        self.lastSeen = Date()
    }
    
    init(id: String, phoneNumber: String, displayName: String? = nil, username: String? = nil, bio: String? = nil, location: String? = nil, avatarURL: String? = nil, bannerURL: String? = nil, badgeType: BadgeType? = nil, followers: [String] = [], following: [String] = []) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.username = username
        self.bio = bio
        self.location = location
        self.avatarURL = avatarURL
        self.bannerURL = bannerURL
        self.badgeType = badgeType
        self.followers = followers
        self.following = following
        self.createdAt = Date()
        self.lastSeen = Date()
    }
}

enum AuthState: Equatable {
    case loading
    case unauthenticated
    case authenticated(User)
    case error(String)
    
    // Add computed property for animation identity
    var id: String {
        switch self {
        case .loading:
            return "loading"
        case .unauthenticated:
            return "unauthenticated"
        case .authenticated(let user):
            return "authenticated_\(user.id)"
        case .error(let message):
            return "error_\(message.hashValue)"
        }
    }
    
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let lhsUser), .authenticated(let rhsUser)):
            return lhsUser.id == rhsUser.id
        case (.error(let lhsMessage), .error(let rhsMessage)):
            return lhsMessage == rhsMessage
        default:
            return false
        }
    }
}

enum AuthError: LocalizedError {
    case invalidPhoneNumber
    case invalidVerificationCode
    case networkError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "Please enter a valid phone number"
        case .invalidVerificationCode:
            return "Invalid verification code. Please try again."
        case .networkError:
            return "Network error. Please check your connection."
        case .unknown:
            return "An unexpected error occurred. Please try again."
        }
    }
}
