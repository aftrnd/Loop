import FirebaseFirestore
import FirebaseAuth
import Foundation

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - User Operations

    func getCurrentUser() -> User? {
        guard let firebaseUser = Auth.auth().currentUser else { return nil }
        return User(from: firebaseUser)
    }

    func getUser(withId userId: String) async throws -> User? {
        let doc = try await db.collection("users").document(userId).getDocument()
        guard let data = doc.data() else { return nil }

        return User(
            id: userId,
            phoneNumber: data["phoneNumber"] as? String ?? "",
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            bio: data["bio"] as? String,
            location: data["location"] as? String
        )
    }
    
    func getUserByPhoneNumber(_ phoneNumber: String) async throws -> User? {
        let snapshot = try await db.collection("users")
            .whereField("phoneNumber", isEqualTo: phoneNumber)
            .limit(to: 1)
            .getDocuments()
        
        guard let doc = snapshot.documents.first else { return nil }
        let data = doc.data()
        
        return User(
            id: doc.documentID,
            phoneNumber: data["phoneNumber"] as? String ?? "",
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            bio: data["bio"] as? String,
            location: data["location"] as? String
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

            return User(
                id: userId,
                phoneNumber: data["phoneNumber"] as? String ?? "",
                displayName: data["displayName"] as? String,
                username: data["username"] as? String,
                bio: data["bio"] as? String,
                location: data["location"] as? String
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
                
                return Chat(
                    id: UUID(uuidString: chatId) ?? UUID(),
                    title: title,
                    lastMessagePreview: lastMessage,
                    unreadCount: unreadCount,
                    messages: [],
                    lastMessageTime: timestamp.dateValue(),
                    participants: participants,
                    otherParticipantId: otherParticipantId
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

        return Chat(
            id: UUID(uuidString: chatId) ?? UUID(),
            title: title,
            lastMessagePreview: lastMessage,
            unreadCount: unreadCount,
            messages: [],
            lastMessageTime: timestamp.dateValue(),
            participants: participants,
            otherParticipantId: otherParticipantId
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

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let title = data["title"] as? String,
                  let lastMessage = data["lastMessage"] as? String,
                  let timestamp = data["lastMessageTime"] as? Timestamp else {
                return nil
            }

            let unreadCount = data["unreadCount"] as? Int ?? 0
            let chatId = data["id"] as? String ?? doc.documentID
            let participants = data["participants"] as? [String] ?? []
            let otherParticipantId = participants.first { $0 != currentUserId }

            return Chat(
                id: UUID(uuidString: chatId) ?? UUID(),
                title: title,
                lastMessagePreview: lastMessage,
                unreadCount: unreadCount,
                messages: [],
                lastMessageTime: timestamp.dateValue(),
                participants: participants,
                otherParticipantId: otherParticipantId
            )
        }
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
        let snapshot = try await db.collection("chats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .getDocuments()

        return snapshot.documents.compactMap { doc in
            let data = doc.data()
            guard let content = data["content"] as? String,
                  let timestamp = data["timestamp"] as? Timestamp,
                  let isFromUser = data["isFromUser"] as? Bool else {
                return nil
            }

            let messageId = data["id"] as? String ?? doc.documentID

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
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else {
                    print("Error fetching chats: \(error?.localizedDescription ?? "Unknown error")")
                    return
                }

                let chats = documents.compactMap { doc -> Chat? in
                    let data = doc.data()
                    guard let title = data["title"] as? String,
                          let lastMessage = data["lastMessage"] as? String,
                          let timestamp = data["lastMessageTime"] as? Timestamp else {
                        return nil
                    }

                    let unreadCount = data["unreadCount"] as? Int ?? 0
                    let chatId = data["id"] as? String ?? doc.documentID
                    let participants = data["participants"] as? [String] ?? []
                    let otherParticipantId = participants.first { $0 != currentUserId }

                    return Chat(
                        id: UUID(uuidString: chatId) ?? UUID(),
                        title: title,
                        lastMessagePreview: lastMessage,
                        unreadCount: unreadCount,
                        messages: [],
                        lastMessageTime: timestamp.dateValue(),
                        participants: participants,
                        otherParticipantId: otherParticipantId
                    )
                }

                completion(chats)
            }
    }

    func listenForMessages(chatId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
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
                          let timestamp = data["timestamp"] as? Timestamp,
                          let isFromUser = data["isFromUser"] as? Bool else {
                        return nil
                    }

                    let messageId = data["id"] as? String ?? doc.documentID

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
