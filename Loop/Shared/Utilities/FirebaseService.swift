import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import Foundation
import UIKit

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    private init() {}

    // MARK: - User Operations

    func getCurrentUser() -> User? {
        guard let firebaseUser = Auth.auth().currentUser else { return nil }
        return User(from: firebaseUser)
    }

    func getUser(withId userId: String, forceRefresh: Bool = false) async throws -> User? {
        let doc: DocumentSnapshot
        
        if forceRefresh {
            // Force fetch from server, bypassing cache
            doc = try await db.collection("users").document(userId).getDocument(source: .server)
        } else {
            // Default: try cache first, then server
            doc = try await db.collection("users").document(userId).getDocument()
        }
        
        guard let data = doc.data() else { return nil }
        
        // Parse badge type from string
        let badgeType: BadgeType?
        if let badgeString = data["badgeType"] as? String {
            badgeType = BadgeType(rawValue: badgeString)
        } else {
            badgeType = nil
        }

        return User(
            id: userId,
            phoneNumber: data["phoneNumber"] as? String ?? "",
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            bio: data["bio"] as? String,
            location: data["location"] as? String,
            avatarURL: data["avatarURL"] as? String,
            bannerURL: data["bannerURL"] as? String,
            badgeType: badgeType
        )
    }
    
    func getUserByPhoneNumber(_ phoneNumber: String) async throws -> User? {
        let snapshot = try await db.collection("users")
            .whereField("phoneNumber", isEqualTo: phoneNumber)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else { return nil }
        let data = doc.data()
        
        // Parse badge type from string
        let badgeType: BadgeType?
        if let badgeString = data["badgeType"] as? String {
            badgeType = BadgeType(rawValue: badgeString)
        } else {
            badgeType = nil
        }
        
        return User(
            id: doc.documentID,
            phoneNumber: data["phoneNumber"] as? String ?? "",
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            bio: data["bio"] as? String,
            location: data["location"] as? String,
            avatarURL: data["avatarURL"] as? String,
            bannerURL: data["bannerURL"] as? String,
            badgeType: badgeType
        )
    }

    func createUserIfNotExists(phoneNumber: String, displayName: String?) async throws -> User {
        let userId = Auth.auth().currentUser?.uid ?? UUID().uuidString

        let userRef = db.collection("users").document(userId)
        let doc = try await userRef.getDocument()

        if doc.exists {
            // User exists, return existing user
            guard let data = doc.data() else {
                throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to load user data"])
            }
            
            // Parse badge type from string
            let badgeType: BadgeType?
            if let badgeString = data["badgeType"] as? String {
                badgeType = BadgeType(rawValue: badgeString)
            } else {
                badgeType = nil
            }

            return User(
                id: userId,
                phoneNumber: data["phoneNumber"] as? String ?? "",
                displayName: data["displayName"] as? String,
                username: data["username"] as? String,
                bio: data["bio"] as? String,
                location: data["location"] as? String,
                avatarURL: data["avatarURL"] as? String,
                bannerURL: data["bannerURL"] as? String,
                badgeType: badgeType
            )
        } else {
            // Create new user
            let user = User(id: userId, phoneNumber: phoneNumber, displayName: displayName)
            try await userRef.setData([
                "phoneNumber": user.phoneNumber,
                "displayName": user.displayName ?? "",
                "username": user.username ?? "",
                "bio": user.bio ?? "",
                "location": user.location ?? "",
                "createdAt": Timestamp(date: user.createdAt),
                "lastSeen": Timestamp(date: user.lastSeen)
            ])

            return user
        }
    }
    
    func updateUserProfile(displayName: String?, username: String?, bio: String?, location: String? = nil) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let userRef = db.collection("users").document(userId)
        var updateData: [String: Any] = [:]
        
        if let displayName = displayName {
            updateData["displayName"] = displayName
        }
        
        if let username = username {
            updateData["username"] = username
        }
        
        if let bio = bio {
            updateData["bio"] = bio
        }
        
        if let location = location {
            updateData["location"] = location
        }
        
        if !updateData.isEmpty {
            try await userRef.updateData(updateData)
        }
    }
    
    // MARK: - Image Upload Operations
    
    /// Uploads an avatar image and returns the download URL
    func uploadAvatarImage(_ image: UIImage) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Compress image to JPEG (0.7 quality for good balance)
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "FirebaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        // Create storage reference
        let storageRef = storage.reference()
        let avatarRef = storageRef.child("users/\(userId)/avatar.jpg")
        
        // Upload image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await avatarRef.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await avatarRef.downloadURL()
        
        // Update user document with avatar URL
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData(["avatarURL": downloadURL.absoluteString])
        
        return downloadURL.absoluteString
    }
    
    /// Uploads a banner image and returns the download URL
    func uploadBannerImage(_ image: UIImage) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Compress image to JPEG (0.8 quality for banners)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "FirebaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        // Create storage reference
        let storageRef = storage.reference()
        let bannerRef = storageRef.child("users/\(userId)/banner.jpg")
        
        // Upload image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await bannerRef.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await bannerRef.downloadURL()
        
        // Update user document with banner URL
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData(["bannerURL": downloadURL.absoluteString])
        
        return downloadURL.absoluteString
    }

    // MARK: - Chat Operations
    
    func findExistingChat(withParticipants participantIds: [String]) async throws -> Chat? {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }
        
        // Query for chats where current user is a participant
        let snapshot = try await db.collection("chats")
            .whereField("participants", arrayContains: currentUserId)
            .getDocuments()
        
        // Filter to find exact match (both users, no more, no less)
        for doc in snapshot.documents {
            let data = doc.data()
            guard let participants = data["participants"] as? [String] else { continue }
            
            // Check if this chat has exactly the same participants
            if Set(participants) == Set(participantIds) {
                // Found existing chat
                guard let title = data["title"] as? String,
                      let lastMessage = data["lastMessage"] as? String,
                      let timestamp = data["lastMessageTime"] as? Timestamp else {
                    continue
                }
                
                let unreadCount = data["unreadCount"] as? Int ?? 0
                let chatId = data["id"] as? String ?? doc.documentID
                let otherParticipantId = participants.first { $0 != currentUserId }
                
                // For 1:1 chats, fetch the other user's current display name and avatar
                var otherParticipantDisplayName: String?
                var otherParticipantAvatarURL: String?
                if participants.count == 2, let otherUserId = otherParticipantId {
                    if let otherUser = try? await getUser(withId: otherUserId) {
                        otherParticipantDisplayName = otherUser.displayName
                        otherParticipantAvatarURL = otherUser.avatarURL
                    }
                }
                
                return Chat(
                    id: UUID(uuidString: chatId) ?? UUID(),
                    title: title,
                    lastMessagePreview: lastMessage,
                    unreadCount: unreadCount,
                    messages: [],
                    lastMessageTime: timestamp.dateValue(),
                    participants: participants,
                    otherParticipantId: otherParticipantId,
                    otherParticipantDisplayName: otherParticipantDisplayName,
                    otherParticipantAvatarURL: otherParticipantAvatarURL
                )
            }
        }
        
        return nil
    }

    func createChat(withUserId userId: String, title: String) async throws -> Chat {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let participants = [currentUserId, userId]
        
        // Check if chat already exists between these users
        if let existingChat = try await findExistingChat(withParticipants: participants) {
            return existingChat
        }
        
        // Create new chat
        let chatId = UUID().uuidString
        let now = Date()

        let chatRef = db.collection("chats").document(chatId)
        try await chatRef.setData([
            "id": chatId,
            "title": title,
            "participants": participants,
            "lastMessage": "Start a conversation...",
            "lastMessageTime": Timestamp(date: now),
            "createdAt": Timestamp(date: now)
        ])

        return Chat(
            id: UUID(uuidString: chatId)!,
            title: title,
            lastMessagePreview: "Start a conversation...",
            unreadCount: 0,
            messages: [],
            lastMessageTime: now,
            participants: participants,
            otherParticipantId: userId
        )
    }

    func getChat(withId chatId: String) async throws -> Chat? {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }
        
        let doc = try await db.collection("chats").document(chatId).getDocument()
        guard let data = doc.data() else { return nil }

        guard let title = data["title"] as? String,
              let lastMessage = data["lastMessage"] as? String,
              let timestamp = data["lastMessageTime"] as? Timestamp else {
            return nil
        }

        let unreadCount = data["unreadCount"] as? Int ?? 0
        let participants = data["participants"] as? [String] ?? []
        let otherParticipantId = participants.first { $0 != currentUserId }
        
        // For 1:1 chats, fetch the other user's current display name and avatar
        var otherParticipantDisplayName: String?
        var otherParticipantAvatarURL: String?
        if participants.count == 2, let otherUserId = otherParticipantId {
            if let otherUser = try? await getUser(withId: otherUserId) {
                otherParticipantDisplayName = otherUser.displayName
                otherParticipantAvatarURL = otherUser.avatarURL
            }
        }

        return Chat(
            id: UUID(uuidString: chatId) ?? UUID(),
            title: title,
            lastMessagePreview: lastMessage,
            unreadCount: unreadCount,
            messages: [],
            lastMessageTime: timestamp.dateValue(),
            participants: participants,
            otherParticipantId: otherParticipantId,
            otherParticipantDisplayName: otherParticipantDisplayName,
            otherParticipantAvatarURL: otherParticipantAvatarURL
        )
    }

    func deleteChat(withId chatId: String) async throws {
        // Delete all messages in the chat
        let messagesRef = db.collection("chats").document(chatId).collection("messages")
        let messages = try await messagesRef.getDocuments()
        for message in messages.documents {
            try await message.reference.delete()
        }

        // Delete the chat document itself
        try await db.collection("chats").document(chatId).delete()
    }

    func getChats() async throws -> [Chat] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }

        let snapshot = try await db.collection("chats")
            .whereField("participants", arrayContains: currentUserId)
            .order(by: "lastMessageTime", descending: true)
            .getDocuments()

        // Use async map to fetch user data for 1:1 chats
        var chats: [Chat] = []
        for doc in snapshot.documents {
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let lastMessage = data["lastMessage"] as? String,
                  let timestamp = data["lastMessageTime"] as? Timestamp else {
                continue
            }

            let unreadCount = data["unreadCount"] as? Int ?? 0
            let chatId = data["id"] as? String ?? doc.documentID
            let participants = data["participants"] as? [String] ?? []
            let otherParticipantId = participants.first { $0 != currentUserId }
            
            // For 1:1 chats, fetch the other user's current display name and avatar
            var otherParticipantDisplayName: String?
            var otherParticipantAvatarURL: String?
            if participants.count == 2, let otherUserId = otherParticipantId {
                if let otherUser = try? await getUser(withId: otherUserId) {
                    otherParticipantDisplayName = otherUser.displayName
                    otherParticipantAvatarURL = otherUser.avatarURL
                }
            }

            chats.append(Chat(
                id: UUID(uuidString: chatId) ?? UUID(),
                title: title,
                lastMessagePreview: lastMessage,
                unreadCount: unreadCount,
                messages: [],
                lastMessageTime: timestamp.dateValue(),
                participants: participants,
                otherParticipantId: otherParticipantId,
                otherParticipantDisplayName: otherParticipantDisplayName,
                otherParticipantAvatarURL: otherParticipantAvatarURL
            ))
        }
        
        return chats
    }

    // MARK: - Message Operations

    func sendMessage(chatId: String, content: String, isFromUser: Bool = true) async throws {
        let messageId = UUID().uuidString
        let now = Date()

        let messageRef = db.collection("chats").document(chatId).collection("messages").document(messageId)
        try await messageRef.setData([
            "id": messageId,
            "content": content,
            "timestamp": Timestamp(date: now),
            "senderId": Auth.auth().currentUser?.uid ?? "",
            "isFromUser": isFromUser
        ])

        // Update chat's last message
        let chatRef = db.collection("chats").document(chatId)
        try await chatRef.updateData([
            "lastMessage": content,
            "lastMessageTime": Timestamp(date: now)
        ])
    }

    func getMessages(forChatId chatId: String) async throws -> [Message] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }
        
        let snapshot = try await db.collection("chats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let content = data["content"] as? String,
                  let timestamp = data["timestamp"] as? Timestamp else {
                return nil
            }

            let messageId = data["id"] as? String ?? doc.documentID
            let senderId = data["senderId"] as? String ?? ""
            
            // Determine if message is from current user by comparing sender ID
            let isFromUser = senderId == currentUserId

            return Message(
                id: UUID(uuidString: messageId) ?? UUID(),
                content: content,
                timestamp: timestamp.dateValue(),
                isFromUser: isFromUser,
                senderName: nil
            )
        }
    }

    // MARK: - Real-time Listeners

    func listenForChats(completion: @escaping ([Chat]) -> Void) -> ListenerRegistration {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return db.collection("chats").addSnapshotListener { _, _ in }
        }

        return db.collection("chats")
            .whereField("participants", arrayContains: currentUserId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                guard let documents = snapshot?.documents else {
                    print("Error fetching chats: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                // Parse basic chat data first
                let chatData: [(data: [String: Any], doc: QueryDocumentSnapshot)] = documents.compactMap { doc in
                    let data = doc.data()
                    guard data["title"] != nil,
                          data["lastMessage"] != nil,
                          data["lastMessageTime"] != nil else {
                        return nil
                    }
                    return (data: data, doc: doc)
                }
                
                // Fetch user data asynchronously for 1:1 chats
                Task {
                    var chats: [Chat] = []
                    
                    for (data, doc) in chatData {
                        guard let title = data["title"] as? String,
                              let lastMessage = data["lastMessage"] as? String,
                              let timestamp = data["lastMessageTime"] as? Timestamp else {
                            continue
                        }
                        
                        let unreadCount = data["unreadCount"] as? Int ?? 0
                        let chatId = data["id"] as? String ?? doc.documentID
                        let participants = data["participants"] as? [String] ?? []
                        let otherParticipantId = participants.first { $0 != currentUserId }
                        
                        // For 1:1 chats, fetch the other user's current display name and avatar
                        var otherParticipantDisplayName: String?
                        var otherParticipantAvatarURL: String?
                        if participants.count == 2, let otherUserId = otherParticipantId {
                            if let otherUser = try? await self.getUser(withId: otherUserId) {
                                otherParticipantDisplayName = otherUser.displayName
                                otherParticipantAvatarURL = otherUser.avatarURL
                            }
                        }
                        
                        chats.append(Chat(
                            id: UUID(uuidString: chatId) ?? UUID(),
                            title: title,
                            lastMessagePreview: lastMessage,
                            unreadCount: unreadCount,
                            messages: [],
                            lastMessageTime: timestamp.dateValue(),
                            participants: participants,
                            otherParticipantId: otherParticipantId,
                            otherParticipantDisplayName: otherParticipantDisplayName,
                            otherParticipantAvatarURL: otherParticipantAvatarURL
                        ))
                    }
                    
                    completion(chats)
                }
            }
    }

    func listenForMessages(chatId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return db.collection("chats").document(chatId).collection("messages").addSnapshotListener { _, _ in }
        }
        
        return db.collection("chats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching messages: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                let messages = documents.compactMap { doc -> Message? in
                    let data = doc.data()
                    guard let content = data["content"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }

                    let messageId = data["id"] as? String ?? doc.documentID
                    let senderId = data["senderId"] as? String ?? ""
                    
                    // Determine if message is from current user by comparing sender ID
                    let isFromUser = senderId == currentUserId

                    return Message(
                        id: UUID(uuidString: messageId) ?? UUID(),
                        content: content,
                        timestamp: timestamp.dateValue(),
                        isFromUser: isFromUser,
                        senderName: nil
                    )
                }

                completion(messages)
            }
    }
}
