import Foundation

// Helper struct for presenting user profiles
struct ProfileUser: Identifiable {
    let id: String
    let userId: String
    
    init(userId: String) {
        self.id = userId
        self.userId = userId
    }
}
