import Foundation
import FirebaseAuth

struct User: Identifiable, Codable, Equatable {
    let id: String
    let phoneNumber: String
    let displayName: String?
    let createdAt: Date
    let lastSeen: Date
    
    init(from firebaseUser: FirebaseAuth.User) {
        self.id = firebaseUser.uid
        self.phoneNumber = firebaseUser.phoneNumber ?? ""
        self.displayName = firebaseUser.displayName
        self.createdAt = Date()
        self.lastSeen = Date()
    }
    
    init(id: String, phoneNumber: String, displayName: String? = nil) {
        self.id = id
        self.phoneNumber = phoneNumber
        self.displayName = displayName
        self.createdAt = Date()
        self.lastSeen = Date()
    }
}

enum AuthState: Equatable {
    case loading
    case unauthenticated
    case authenticated(User)
    case error(String)
    
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
