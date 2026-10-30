import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions
import Foundation
import UIKit
import os

class FirebaseService {
    static let shared = FirebaseService()
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private let logger = Logger(subsystem: "com.nejack.Loop", category: "FirebaseService")

    /// Author profiles fetched this session, keyed by user ID. Shared by every feed so a profile is read once.
    private var userCache: [String: User] = [:]

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
        
        let user = Self.makeUser(id: userId, data: data)
        userCache[userId] = user
        return user
    }
    
    /// Returns profiles for `ids`, reading from the session cache and fetching the rest in batched queries.
    func users(withIds ids: [String]) async -> [String: User] {
        let uniqueIds = Array(Set(ids))
        let missingIds = uniqueIds.filter { userCache[$0] == nil }
        
        // Firestore allows up to 30 values in an `in` filter
        for start in stride(from: 0, to: missingIds.count, by: 30) {
            let batch = Array(missingIds[start..<min(start + 30, missingIds.count)])
            do {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: batch)
                    .getDocuments()
                for document in snapshot.documents {
                    userCache[document.documentID] = Self.makeUser(id: document.documentID, data: document.data())
                }
            } catch {
                logger.error("Author profile fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        
        return uniqueIds.reduce(into: [:]) { result, id in
            result[id] = userCache[id]
        }
    }
    
    /// Drops cached author profiles so the next fetch reads fresh names and avatars.
    func invalidateUserCache() {
        userCache.removeAll()
    }
    
    private static func makeUser(id: String, data: [String: Any]) -> User {
        let badgeType = (data["badgeType"] as? String).flatMap(BadgeType.init(rawValue:))
        
        return User(
            id: id,
            phoneNumber: data["phoneNumber"] as? String ?? "",
            displayName: data["displayName"] as? String,
            username: data["username"] as? String,
            bio: data["bio"] as? String,
            location: data["location"] as? String,
            avatarURL: data["avatarURL"] as? String,
            bannerURL: data["bannerURL"] as? String,
            badgeType: badgeType,
            followers: data["followers"] as? [String] ?? [],
            following: data["following"] as? [String] ?? [],
            fcmToken: data["fcmToken"] as? String
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
            badgeType: badgeType,
            followers: data["followers"] as? [String] ?? [],
            following: data["following"] as? [String] ?? [],
            fcmToken: data["fcmToken"] as? String
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
                badgeType: badgeType,
                followers: data["followers"] as? [String] ?? [],
                following: data["following"] as? [String] ?? [],
                fcmToken: data["fcmToken"] as? String
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
                "followers": user.followers,
                "following": user.following,
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
            userCache[userId] = nil
        }
    }
    
    func updateFCMToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        let userRef = db.collection("users").document(userId)
        try await userRef.updateData([
            "fcmToken": token,
            "lastTokenUpdate": Timestamp(date: Date())
        ])
        
        print("✅ FCM token updated in Firestore")
    }
    
    // MARK: - Image Upload Operations
    
    /// Uploads an avatar image and returns the download URL
    func uploadAvatarImage(_ image: UIImage) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Resize image to max 512x512 for avatars (maintains aspect ratio)
        guard let resizedImage = image.resizedForAvatar() else {
            throw NSError(domain: "FirebaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to resize image"])
        }
        
        // Compress resized image to JPEG (0.8 quality for crisp results)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.8) else {
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
        userCache[userId] = nil
        
        return downloadURL.absoluteString
    }
    
    /// Uploads a banner image and returns the download URL
    func uploadBannerImage(_ image: UIImage) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Resize image to max 1920x1080 for banners (maintains aspect ratio)
        guard let resizedImage = image.resizedForBanner() else {
            throw NSError(domain: "FirebaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to resize image"])
        }
        
        // Compress resized image to JPEG (0.85 quality for banners)
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.85) else {
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
        userCache[userId] = nil
        
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
                guard let title = data["title"] as? String else {
                    continue
                }
                
                // Read per-user unread count
                let unreadFieldName = "unreadCount_\(currentUserId)"
                let unreadCount = data[unreadFieldName] as? Int ?? 0
                let chatId = data["id"] as? String ?? doc.documentID
                let otherParticipantId = participants.first { $0 != currentUserId }
                
                // Fetch the actual most recent message from messages subcollection
                let messagesSnapshot = try? await db.collection("chats")
                    .document(chatId)
                    .collection("messages")
                    .order(by: "timestamp", descending: true)
                    .limit(to: 1)
                    .getDocuments()
                
                let lastMessage = messagesSnapshot?.documents.first?.data()["content"] as? String ?? ""
                let timestamp = (messagesSnapshot?.documents.first?.data()["timestamp"] as? Timestamp)?.dateValue() ?? (data["lastMessageTime"] as? Timestamp)?.dateValue() ?? Date()
                
                // For 1:1 chats, fetch the other user's current display name and avatar
                var otherParticipantDisplayName: String?
                var otherParticipantAvatarURL: String?
                var otherParticipantBadgeType: BadgeType?
                if participants.count == 2, let otherUserId = otherParticipantId {
                    if let otherUser = try? await getUser(withId: otherUserId) {
                        otherParticipantDisplayName = otherUser.displayName
                        otherParticipantAvatarURL = otherUser.avatarURL
                        otherParticipantBadgeType = otherUser.badgeType
                    }
                }
                
                return Chat(
                    id: UUID(uuidString: chatId) ?? UUID(),
                    title: title,
                    lastMessagePreview: lastMessage,
                    unreadCount: unreadCount,
                    messages: [],
                    lastMessageTime: timestamp,
                    participants: participants,
                    otherParticipantId: otherParticipantId,
                    otherParticipantDisplayName: otherParticipantDisplayName,
                    otherParticipantAvatarURL: otherParticipantAvatarURL,
                    otherParticipantBadgeType: otherParticipantBadgeType
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
        
        // Check if chat already exists between these users (even if hidden)
        if let existingChat = try await findExistingChat(withParticipants: participants) {
            // Unhide the chat for the current user so it appears in their list
            let chatRef = db.collection("chats").document(existingChat.id.uuidString)
            try await chatRef.updateData([
                "hiddenFor": FieldValue.arrayRemove([currentUserId])
            ])
            print("✅ Unhidden existing chat for user: \(currentUserId)")
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

        // Read per-user unread count
        let unreadFieldName = "unreadCount_\(currentUserId)"
        let unreadCount = data[unreadFieldName] as? Int ?? 0
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
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Instead of deleting, hide the chat for this user
        // Messages and conversation persist for when they message again
        let chatRef = db.collection("chats").document(chatId)
        try await chatRef.updateData([
            "hiddenFor": FieldValue.arrayUnion([currentUserId])
        ])
        
        print("✅ Chat hidden for user: \(currentUserId)")
    }

    // MARK: - Chat Parsing

    /// Builds a chat from its document. Returns nil for malformed chats and for chats the current user has hidden.
    /// The other participant's profile fields are filled in by `chats(from:)`.
    static func parseChat(id documentID: String, data: [String: Any], currentUserId: String) -> Chat? {
        guard let title = data["title"] as? String else { return nil }

        // Deleting a chat hides it for that user; the conversation stays in Firestore
        let hiddenFor = data["hiddenFor"] as? [String] ?? []
        guard !hiddenFor.contains(currentUserId) else { return nil }

        let chatId = data["id"] as? String ?? documentID
        let participants = data["participants"] as? [String] ?? []
        let lastMessageTime = data["lastMessageTime"] as? Timestamp

        // `createChat` stores a placeholder preview. Until the first message, lastMessageTime still equals
        // createdAt, and the list shows no preview for those chats.
        let hasMessages = lastMessageTime != (data["createdAt"] as? Timestamp)
        let lastMessage = hasMessages ? (data["lastMessage"] as? String ?? "") : ""

        return Chat(
            id: UUID(uuidString: chatId) ?? UUID(),
            title: title,
            lastMessagePreview: lastMessage,
            unreadCount: data["unreadCount_\(currentUserId)"] as? Int ?? 0,
            messages: [],
            lastMessageTime: lastMessageTime?.dateValue() ?? Date(),
            participants: participants,
            otherParticipantId: participants.first { $0 != currentUserId }
        )
    }

    /// Parses chat documents and attaches each 1:1 partner's profile, read through the batched user cache.
    func chats(from documents: [QueryDocumentSnapshot]) async -> [Chat] {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return [] }

        let parsed = documents.compactMap {
            Self.parseChat(id: $0.documentID, data: $0.data(), currentUserId: currentUserId)
        }
        let partnerIds = parsed.compactMap { $0.participants.count == 2 ? $0.otherParticipantId : nil }
        let partners = await users(withIds: partnerIds)

        return parsed.map { chat in
            guard chat.participants.count == 2,
                  let partnerId = chat.otherParticipantId,
                  let partner = partners[partnerId] else {
                return chat
            }
            var chat = chat
            chat.otherParticipantDisplayName = partner.displayName
            chat.otherParticipantAvatarURL = partner.avatarURL
            chat.otherParticipantBadgeType = partner.badgeType
            return chat
        }
    }

    // MARK: - Message Operations

    /// Writes a message together with the chat's preview, unread counts and the sender's typing state in one batch.
    /// Firestore applies the batch to local listeners right away, so the message shows before the server confirms it.
    func sendMessage(chatId: String, content: String, participants: [String]) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        guard !participants.isEmpty else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid chat data"])
        }

        let now = Date()
        let chatRef = db.collection("chats").document(chatId)
        let messagesRef = chatRef.collection("messages")
        let isSelfChat = participants.count == 2 && Set(participants) == [currentUserId]
        let batch = db.batch()

        var chatUpdate: [String: Any] = [
            "lastMessage": content,
            "lastMessageTime": Timestamp(date: now),
            "hiddenFor": FieldValue.arrayRemove([currentUserId]), // Unhide for sender
            "typing_\(currentUserId)": FieldValue.delete()
        ]

        if isSelfChat {
            // A chat with yourself stores each message twice: sent (right side) and received (left side)
            let sentMessageId = UUID().uuidString
            batch.setData([
                "id": sentMessageId,
                "content": content,
                "timestamp": Timestamp(date: now),
                "senderId": currentUserId,
                "isFromUser": true,
                "isSelfChatSent": true
            ], forDocument: messagesRef.document(sentMessageId))

            // A tiny offset keeps the received copy after the sent one
            let receivedMessageId = UUID().uuidString
            batch.setData([
                "id": receivedMessageId,
                "content": content,
                "timestamp": Timestamp(date: now.addingTimeInterval(0.001)),
                "senderId": "self_received",
                "isFromUser": false,
                "isSelfChatReceived": true
            ], forDocument: messagesRef.document(receivedMessageId))

            // Self-chats still count as unread, but send no push notification
            chatUpdate["unreadCount_\(currentUserId)"] = FieldValue.increment(Int64(1))
        } else {
            // isFromUser is not stored; readers compare senderId with their own ID
            let messageId = UUID().uuidString
            batch.setData([
                "id": messageId,
                "content": content,
                "timestamp": Timestamp(date: now),
                "senderId": currentUserId
            ], forDocument: messagesRef.document(messageId))

            for participantId in participants where participantId != currentUserId {
                chatUpdate["unreadCount_\(participantId)"] = FieldValue.increment(Int64(1))
            }
        }

        batch.updateData(chatUpdate, forDocument: chatRef)
        try await batch.commit()

        if !isSelfChat {
            await sendMessageNotifications(chatId: chatId, participants: participants, content: content, senderId: currentUserId)
        }
    }
    
    // MARK: - Push Notifications
    
    private func sendMessageNotifications(chatId: String, participants: [String], content: String, senderId: String) async {
        // Get sender's display name
        guard let sender = try? await getUser(withId: senderId) else { return }
        let senderName = sender.displayName ?? "Someone"
        
        // Send notification to all participants except the sender
        for participantId in participants where participantId != senderId {
            // Get participant's FCM token
            guard let participant = try? await getUser(withId: participantId),
                  let fcmToken = participant.fcmToken else {
                print("⚠️ No FCM token for participant \(participantId)")
                continue
            }

            // Send push notification via Firebase Cloud Function
            do {
                let functions = Functions.functions()
                let sendNotification = functions.httpsCallable("sendNotification")
                
                _ = try await sendNotification.call([
                    "fcmToken": fcmToken,
                    "title": senderName,
                    "body": content,
                    "chatId": chatId,
                    "senderId": senderId
                ])
                
                print("✅ Push notification sent to \(participantId)")
            } catch {
                print("❌ Failed to send push notification to \(participantId): \(error.localizedDescription)")
                // Continue to next participant even if one fails
            }
        }
    }
    
    func markChatAsRead(chatId: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        let chatRef = db.collection("chats").document(chatId)
        let unreadFieldName = "unreadCount_\(userId)"
        
        try await chatRef.updateData([
            unreadFieldName: 0
        ])
    }
    
    // MARK: - Typing Indicators
    
    func setTypingStatus(chatId: String, isTyping: Bool) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        // A timestamp while typing, so readers can ignore indicators that went stale
        let value: Any = isTyping ? Timestamp(date: Date()) : FieldValue.delete()
        try await db.collection("chats").document(chatId).updateData([
            "typing_\(userId)": value
        ])
    }

    /// Listens to one chat document for who else is typing and for the current user's unread count.
    /// Returns nil when nobody is signed in.
    func listenForChatActivity(chatId: String, onChange: @escaping (ChatActivity) -> Void) -> ListenerRegistration? {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }

        return db.collection("chats").document(chatId)
            .addSnapshotListener { snapshot, error in
                if let error {
                    self.logger.error("Chat activity listener failed: \(error.localizedDescription, privacy: .public)")
                }
                guard let data = snapshot?.data() else {
                    onChange(ChatActivity())
                    return
                }

                let participants = data["participants"] as? [String] ?? []
                let isSelfChat = participants.count == 2 && Set(participants) == [currentUserId]

                var typingUsers: [String: Date] = [:]
                for (key, value) in data where key.hasPrefix("typing_") {
                    let userId = String(key.dropFirst("typing_".count))
                    // In a chat with yourself your own typing shows; elsewhere only other people's does
                    guard isSelfChat || userId != currentUserId, let timestamp = value as? Timestamp else { continue }
                    typingUsers[userId] = timestamp.dateValue()
                }

                onChange(ChatActivity(
                    typingUsers: typingUsers,
                    unreadCount: data["unreadCount_\(currentUserId)"] as? Int ?? 0
                ))
            }
    }

    func likeMessage(chatId: String, messageId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let messageRef = db.collection("chats").document(chatId).collection("messages").document(messageId)
        
        // Add current user to likedBy array
        try await messageRef.updateData([
            "likedBy": FieldValue.arrayUnion([currentUserId])
        ])
        
        print("✅ Successfully liked message: \(messageId)")
        
        // Get message data to send notification
        let messageDoc = try await messageRef.getDocument()
        guard let messageData = messageDoc.data(),
              let senderId = messageData["senderId"] as? String,
              let content = messageData["content"] as? String,
              senderId != currentUserId else { // Don't notify yourself
            return
        }
        
        // Get chat participants to determine who to notify
        let chatDoc = try await db.collection("chats").document(chatId).getDocument()
        guard let chatData = chatDoc.data(),
              let _ = chatData["participants"] as? [String] else {
            return
        }
        
        // Send notification to message sender
        await sendLikeNotification(chatId: chatId, messageId: messageId, messageSenderId: senderId, messageContent: content)
    }
    
    func unlikeMessage(chatId: String, messageId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let messageRef = db.collection("chats").document(chatId).collection("messages").document(messageId)
        
        // Remove current user from likedBy array
        try await messageRef.updateData([
            "likedBy": FieldValue.arrayRemove([currentUserId])
        ])
        
        print("✅ Successfully unliked message: \(messageId)")
    }
    
    private func sendLikeNotification(chatId: String, messageId: String, messageSenderId: String, messageContent: String) async {
        guard let currentUser = try? await getUser(withId: Auth.auth().currentUser?.uid ?? "") else { return }
        let likerName = currentUser.displayName ?? "Someone"
        
        // Get the message sender's FCM token
        guard let messageSender = try? await getUser(withId: messageSenderId),
              let fcmToken = messageSender.fcmToken else {
            print("⚠️ Could not get FCM token for message sender")
            return
        }
        
        do {
            let functions = Functions.functions()
            let sendNotification = functions.httpsCallable("sendNotification")
            
            // Truncate message content for notification
            let truncatedContent = messageContent.prefix(50) + (messageContent.count > 50 ? "..." : "")
            
            _ = try await sendNotification.call([
                "fcmToken": fcmToken,
                "title": "\(likerName) liked your message",
                "body": "\"\(truncatedContent)\"",
                "chatId": chatId,
                "senderId": Auth.auth().currentUser?.uid ?? "",
                "type": "message_like"
            ])
            print("✅ Like notification sent to \(messageSenderId)")
        } catch {
            print("❌ Failed to send like notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Real-time Listeners

    /// Listens to the current user's chats, newest first, and hands over the raw documents.
    /// Resolve them with `chats(from:)`. Returns nil when nobody is signed in.
    func listenForChats(onSnapshot: @escaping (Result<[QueryDocumentSnapshot], Error>) -> Void) -> ListenerRegistration? {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }

        return db.collection("chats")
            .whereField("participants", arrayContains: currentUserId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onSnapshot(.failure(error))
                } else {
                    onSnapshot(.success(snapshot?.documents ?? []))
                }
            }
    }

    /// Listens to a chat's messages, oldest first. The first snapshot carries the full history.
    /// Returns nil when nobody is signed in.
    func listenForMessages(chatId: String, onChange: @escaping (Result<[Message], Error>) -> Void) -> ListenerRegistration? {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return nil }

        return db.collection("chats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                if let error {
                    onChange(.failure(error))
                    return
                }

                let messages = (snapshot?.documents ?? []).compactMap { doc -> Message? in
                    let data = doc.data()
                    guard let content = data["content"] as? String,
                          let timestamp = data["timestamp"] as? Timestamp else {
                        return nil
                    }

                    let messageId = data["id"] as? String ?? doc.documentID
                    let senderId = data["senderId"] as? String ?? ""

                    // Self-chat messages store isFromUser; everything else is decided by the sender ID
                    let isFromUser = data["isFromUser"] as? Bool ?? (senderId == currentUserId)

                    return Message(
                        id: UUID(uuidString: messageId) ?? UUID(),
                        content: content,
                        timestamp: timestamp.dateValue(),
                        isFromUser: isFromUser,
                        senderName: nil,
                        senderId: senderId,
                        likedBy: data["likedBy"] as? [String] ?? []
                    )
                }

                onChange(.success(messages))
            }
    }
    
    // MARK: - Follow System
    
    func followUser(_ targetUserId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Can't follow yourself
        guard currentUserId != targetUserId else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot follow yourself"])
        }
        
        let batch = db.batch()
        
        // Add targetUserId to current user's following list
        let currentUserRef = db.collection("users").document(currentUserId)
        batch.updateData([
            "following": FieldValue.arrayUnion([targetUserId])
        ], forDocument: currentUserRef)
        
        // Add currentUserId to target user's followers list
        let targetUserRef = db.collection("users").document(targetUserId)
        batch.updateData([
            "followers": FieldValue.arrayUnion([currentUserId])
        ], forDocument: targetUserRef)
        
        try await batch.commit()
        print("✅ Successfully followed user: \(targetUserId)")
    }
    
    func unfollowUser(_ targetUserId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let batch = db.batch()
        
        // Remove targetUserId from current user's following list
        let currentUserRef = db.collection("users").document(currentUserId)
        batch.updateData([
            "following": FieldValue.arrayRemove([targetUserId])
        ], forDocument: currentUserRef)
        
        // Remove currentUserId from target user's followers list
        let targetUserRef = db.collection("users").document(targetUserId)
        batch.updateData([
            "followers": FieldValue.arrayRemove([currentUserId])
        ], forDocument: targetUserRef)
        
        try await batch.commit()
        print("✅ Successfully unfollowed user: \(targetUserId)")
    }
    
    func isFollowing(_ targetUserId: String) async throws -> Bool {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return false }
        guard let currentUser = try await getUser(withId: currentUserId) else { return false }
        return currentUser.following.contains(targetUserId)
    }
    
    // MARK: - Loop Operations
    
    func createLoop(content: String, media: [LoopMedia] = [], isReply: Bool = false, parentLoopId: String? = nil, replyToReplyId: String? = nil) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let loopId = UUID().uuidString
        let now = Date()
        
        // Convert media to dictionary format
        let mediaData = media.map { media in
            var dict: [String: Any] = [
                "id": media.id,
                "type": media.type.rawValue,
                "url": media.url
            ]
            
            if let thumbnailURL = media.thumbnailURL {
                dict["thumbnailURL"] = thumbnailURL
            }
            if let width = media.width {
                dict["width"] = width
            }
            if let height = media.height {
                dict["height"] = height
            }
            
            return dict
        }
        
        let loopRef = db.collection("loops").document(loopId)
        
        var loopData: [String: Any] = [
            "id": loopId,
            "authorId": currentUserId,
            "content": content,
            "media": mediaData,
            "createdAt": Timestamp(date: now),
            "updatedAt": Timestamp(date: now),
            "likes": [],
            "replies": [],
            "isReply": isReply
        ]
        
        if let parentLoopId = parentLoopId {
            loopData["parentLoopId"] = parentLoopId
        }
        
        if let replyToReplyId = replyToReplyId {
            loopData["replyToReplyId"] = replyToReplyId
        }
        
        try await loopRef.setData(loopData)
        
        // If this is a reply, update the parent loop's replies array
        if isReply, let parentLoopId = parentLoopId {
            let parentLoopRef = db.collection("loops").document(parentLoopId)
            try await parentLoopRef.updateData([
                "replies": FieldValue.arrayUnion([loopId])
            ])
        }
        
        print("✅ Successfully created loop: \(loopId)")
    }
    
    func likeLoop(_ loopId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let loopRef = db.collection("loops").document(loopId)
        try await loopRef.updateData([
            "likes": FieldValue.arrayUnion([currentUserId])
        ])
        
        print("✅ Successfully liked loop: \(loopId)")
    }
    
    func unlikeLoop(_ loopId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let loopRef = db.collection("loops").document(loopId)
        try await loopRef.updateData([
            "likes": FieldValue.arrayRemove([currentUserId])
        ])
        
        print("✅ Successfully unliked loop: \(loopId)")
    }
    
    func deleteLoop(_ loopId: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // First, verify the user owns this loop
        let loopDoc = try await db.collection("loops").document(loopId).getDocument()
        guard let data = loopDoc.data(),
              let authorId = data["authorId"] as? String,
              authorId == currentUserId else {
            throw NSError(domain: "FirebaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unauthorized to delete this loop"])
        }
        
        let batch = db.batch()
        
        // Delete the loop itself
        // Note: The Cloud Function 'onLoopDelete' will automatically handle:
        // - Deleting nested replies (where replyToReplyId == loopId)
        // - Cleaning up parent's replies arrays
        // This is necessary because nested replies may be from other users,
        // which we can't delete due to security rules
        batch.deleteDocument(db.collection("loops").document(loopId))
        
        // If this is a reply, remove it from parent's replies array
        if let parentLoopId = data["parentLoopId"] as? String {
            let parentLoopRef = db.collection("loops").document(parentLoopId)
            batch.updateData([
                "replies": FieldValue.arrayRemove([loopId])
            ], forDocument: parentLoopRef)
        }
        
        try await batch.commit()
        
        print("✅ Successfully deleted loop: \(loopId) - nested replies will be cleaned up by Cloud Function")
    }
    
    func getLoop(withId loopId: String) async throws -> Loop? {
        let doc = try await db.collection("loops").document(loopId).getDocument()
        guard let data = doc.data(), let loop = Self.parseLoop(id: doc.documentID, data: data) else { return nil }
        
        let authors = await users(withIds: [loop.authorId])
        return loop.withAuthor(authors[loop.authorId])
    }
    
    func getReplies(for loopId: String) async throws -> [Loop] {
        let snapshot = try await db.collection("loops")
            .whereField("parentLoopId", isEqualTo: loopId)
            .order(by: "createdAt", descending: true) // Newest first (Reddit-style)
            .getDocuments()
        
        return await loops(from: snapshot.documents)
    }
    
    // MARK: - Loop Parsing
    
    /// Builds loops from query documents and attaches author profiles fetched in one batch.
    func loops(from documents: [QueryDocumentSnapshot]) async -> [Loop] {
        let parsed = documents.compactMap { Self.parseLoop(id: $0.documentID, data: $0.data()) }
        let authors = await users(withIds: parsed.map(\.authorId))
        return parsed.map { $0.withAuthor(authors[$0.authorId]) }
    }
    
    /// Parses a loop document without author details. Returns nil when required fields are missing.
    static func parseLoop(id: String, data: [String: Any]) -> Loop? {
        guard let authorId = data["authorId"] as? String,
              let content = data["content"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        let mediaArray = data["media"] as? [[String: Any]] ?? []
        let media = mediaArray.compactMap { mediaData -> LoopMedia? in
            guard let id = mediaData["id"] as? String,
                  let typeString = mediaData["type"] as? String,
                  let type = LoopMediaType(rawValue: typeString),
                  let url = mediaData["url"] as? String else {
                return nil
            }
            
            return LoopMedia(
                id: id,
                type: type,
                url: url,
                thumbnailURL: mediaData["thumbnailURL"] as? String,
                width: mediaData["width"] as? Double,
                height: mediaData["height"] as? Double
            )
        }
        
        return Loop(
            id: id,
            authorId: authorId,
            content: content,
            media: media,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAtTimestamp.dateValue(),
            likes: data["likes"] as? [String] ?? [],
            replies: data["replies"] as? [String] ?? [],
            isReply: data["isReply"] as? Bool ?? false,
            parentLoopId: data["parentLoopId"] as? String,
            replyToReplyId: data["replyToReplyId"] as? String
        )
    }
    
    /// Uploads a loop media file and returns the download URL
    func uploadLoopMedia(_ image: UIImage, type: LoopMediaType) async throws -> LoopMedia {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        
        // Compress image to JPEG (0.8 quality for posts)
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "FirebaseService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        // Create storage reference
        let storageRef = storage.reference()
        let mediaId = UUID().uuidString
        let mediaRef = storageRef.child("loops/\(userId)/\(mediaId).jpg")
        
        // Upload image
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await mediaRef.putDataAsync(imageData, metadata: metadata)
        
        // Get download URL
        let downloadURL = try await mediaRef.downloadURL()
        
        return LoopMedia(
            id: mediaId,
            type: type,
            url: downloadURL.absoluteString,
            width: Double(image.size.width),
            height: Double(image.size.height)
        )
    }
    
    // MARK: - Profile Feed Operations
    
    /// Fetches all loops (posts and replies) created by a specific user
    func getUserLoops(userId: String) async throws -> [Loop] {
        let snapshot = try await db.collection("loops")
            .whereField("authorId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        
        return await loops(from: snapshot.documents)
    }
    
    /// Fetches all loops liked by a specific user, newest first
    func getUserLikedLoops(userId: String) async throws -> [Loop] {
        // Sorted on the device rather than with `order(by:)`, which would need a composite index
        let snapshot = try await db.collection("loops")
            .whereField("likes", arrayContains: userId)
            .getDocuments()
        
        return await loops(from: snapshot.documents).sorted { $0.createdAt > $1.createdAt }
    }
}
