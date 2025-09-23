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
            displayName: data["displayName"] as? String
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
                displayName: data["displayName"] as? String
            )
        } else {
            // Create new user
            let user = User(id: userId, phoneNumber: phoneNumber, displayName: displayName)
            try await userRef.setData([
                "phoneNumber": user.phoneNumber,
                "displayName": user.displayName ?? "",
                "createdAt": Timestamp(date: user.createdAt),
                "lastSeen": Timestamp(date: user.lastSeen)
            ])

            return user
        }
    }

    // MARK: - Chat Operations

    func createChat(withUserId userId: String, title: String) async throws -> Chat {
        let chatId = UUID().uuidString
        let now = Date()

        let chatRef = db.collection("chats").document(chatId)
        try await chatRef.setData([
            "id": chatId,
            "title": title,
            "participants": [Auth.auth().currentUser?.uid ?? "", userId],
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
            lastMessageTime: now
        )
    }

    func getChat(withId chatId: String) async throws -> Chat? {
        let doc = try await db.collection("chats").document(chatId).getDocument()
        guard let data = doc.data() else { return nil }

        guard let title = data["title"] as? String,
              let lastMessage = data["lastMessage"] as? String,
              let timestamp = data["lastMessageTime"] as? Timestamp else {
            return nil
        }

        let unreadCount = data["unreadCount"] as? Int ?? 0

        return Chat(
            id: UUID(uuidString: chatId) ?? UUID(),
            title: title,
            lastMessagePreview: lastMessage,
            unreadCount: unreadCount,
            messages: [],
            lastMessageTime: timestamp.dateValue()
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

            return Chat(
                id: UUID(uuidString: chatId) ?? UUID(),
                title: title,
                lastMessagePreview: lastMessage,
                unreadCount: unreadCount,
                messages: [],
                lastMessageTime: timestamp.dateValue()
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

                    return Chat(
                        id: UUID(uuidString: chatId) ?? UUID(),
                        title: title,
                        lastMessagePreview: lastMessage,
                        unreadCount: unreadCount,
                        messages: [],
                        lastMessageTime: timestamp.dateValue()
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
