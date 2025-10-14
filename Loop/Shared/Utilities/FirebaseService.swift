import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import FirebaseFunctions
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
            guard let title = data["title"] as? String else {
                continue
            }
            
            // Skip chats that are hidden for this user
            let hiddenFor = data["hiddenFor"] as? [String] ?? []
            if hiddenFor.contains(currentUserId) {
                continue
            }

            // Read per-user unread count
            let unreadFieldName = "unreadCount_\(currentUserId)"
            let unreadCount = data[unreadFieldName] as? Int ?? 0
            let chatId = data["id"] as? String ?? doc.documentID
            let participants = data["participants"] as? [String] ?? []
            let otherParticipantId = participants.first { $0 != currentUserId }
            
            if unreadCount > 0 {
                print("📩 Chat \(title) has \(unreadCount) unread messages")
            }
            
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

            chats.append(Chat(
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
            ))
        }
        
        return chats
    }

    // MARK: - Message Operations

    func sendMessage(chatId: String, content: String) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let now = Date()
        
        // Check if this is a self-chat (messaging yourself)
        let chatDoc = try await db.collection("chats").document(chatId).getDocument()
        guard let chatData = chatDoc.data(),
              let participants = chatData["participants"] as? [String] else {
            throw NSError(domain: "FirebaseService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid chat data"])
        }
        
        let isSelfChat = participants.count == 2 && Set(participants).count == 1 && participants[0] == currentUserId
        
        print("🔍 DEBUG: isSelfChat = \(isSelfChat), participants = \(participants), currentUserId = \(currentUserId)")
        
        if isSelfChat {
            // For self-chats, create two messages - one as sent, one as received
            print("📨 Creating self-chat messages...")
            
            // First message - sent by you (appears on right)
            let sentMessageId = UUID().uuidString
            let sentMessageRef = db.collection("chats").document(chatId).collection("messages").document(sentMessageId)
            let sentTimestamp = Date()
            try await sentMessageRef.setData([
                "id": sentMessageId,
                "content": content,
                "timestamp": Timestamp(date: sentTimestamp),
                "senderId": currentUserId,
                "isFromUser": true,
                "isSelfChatSent": true // Marker for sent message in self-chat
            ])
            
            print("✅ SENT message created: id=\(sentMessageId), isFromUser=true")
            
            // Second message - received by you (appears on left)
            // Add a tiny offset so it appears after the sent message
            let receivedTimestamp = sentTimestamp.addingTimeInterval(0.001)
            let receivedMessageId = UUID().uuidString
            let receivedMessageRef = db.collection("chats").document(chatId).collection("messages").document(receivedMessageId)
            try await receivedMessageRef.setData([
                "id": receivedMessageId,
                "content": content,
                "timestamp": Timestamp(date: receivedTimestamp),
                "senderId": "self_received", // Different sender ID to mark as received
                "isFromUser": false,
                "isSelfChatReceived": true // Marker for received message in self-chat
            ])
            
            print("✅ RECEIVED message created: id=\(receivedMessageId), isFromUser=false, senderId=self_received")
        } else {
            // Normal chat - create single message
            print("📨 Creating normal chat message...")
            let messageId = UUID().uuidString
            let messageRef = db.collection("chats").document(chatId).collection("messages").document(messageId)
            try await messageRef.setData([
                "id": messageId,
                "content": content,
                "timestamp": Timestamp(date: now),
                "senderId": currentUserId
                // Note: isFromUser is NOT stored - it's computed client-side by comparing senderId with current user
            ])
            
            print("✅ Message created: id=\(messageId), senderId=\(currentUserId)")
        }

        // Update chat's last message and unhide for sender
        let chatRef = db.collection("chats").document(chatId)
        try await chatRef.updateData([
            "lastMessage": content,
            "lastMessageTime": Timestamp(date: now),
            "hiddenFor": FieldValue.arrayRemove([currentUserId]) // Unhide for sender
        ])
        
        // For self-chats: still increment unread count (but don't send push notification)
        if isSelfChat {
            print("📬 Self-chat: Incrementing unread count without sending notification")
            try? await incrementUnreadCount(chatId: chatId, userId: currentUserId)
        } else {
            // For normal chats: send push notifications which also increments unread counts
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
            
            // Increment unread count for this participant
            try? await incrementUnreadCount(chatId: chatId, userId: participantId)
            
            // Send push notification via Firebase Cloud Function
            do {
                let functions = Functions.functions()
                let sendNotification = functions.httpsCallable("sendNotification")
                
                let result = try await sendNotification.call([
                    "fcmToken": fcmToken,
                    "title": senderName,
                    "body": content,
                    "chatId": chatId,
                    "senderId": senderId
                ])
                
                print("✅ Push notification sent to \(participantId)")
                print("📬 Message: \(senderName): \(content)")
            } catch {
                print("❌ Failed to send push notification to \(participantId): \(error.localizedDescription)")
                // Continue to next participant even if one fails
            }
        }
    }
    
    private func incrementUnreadCount(chatId: String, userId: String) async throws {
        // Store unread count per user in the chat document
        let chatRef = db.collection("chats").document(chatId)
        let unreadFieldName = "unreadCount_\(userId)"
        
        print("📊 Incrementing \(unreadFieldName) in chat \(chatId)")
        try await chatRef.updateData([
            unreadFieldName: FieldValue.increment(Int64(1))
        ])
        print("✅ Unread count incremented successfully")
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
        guard let userId = Auth.auth().currentUser?.uid else {
            print("⚠️ Cannot set typing status - no user ID")
            return
        }
        
        let chatRef = db.collection("chats").document(chatId)
        let typingFieldName = "typing_\(userId)"
        
        if isTyping {
            // Set typing status with timestamp
            print("📝 Setting typing_\(userId) = \(Date()) in chat \(chatId)")
            try await chatRef.updateData([
                typingFieldName: Timestamp(date: Date())
            ])
            print("✅ Typing status set successfully")
        } else {
            // Remove typing status
            print("📝 Deleting typing_\(userId) from chat \(chatId)")
            try await chatRef.updateData([
                typingFieldName: FieldValue.delete()
            ])
            print("✅ Typing status deleted successfully")
        }
    }
    
    func listenForTypingStatus(chatId: String, completion: @escaping ([String: Date]) -> Void) -> ListenerRegistration {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return db.collection("chats").document(chatId).addSnapshotListener { _, _ in }
        }
        
        return db.collection("chats").document(chatId)
            .addSnapshotListener { snapshot, error in
                guard let data = snapshot?.data() else {
                    print("🔍 Typing listener: No data in snapshot")
                    completion([:])
                    return
                }
                
                // Check if this is a self-chat
                let participants = data["participants"] as? [String] ?? []
                let isSelfChat = participants.count == 2 && Set(participants).count == 1 && participants.first == currentUserId
                
                print("🔍 Typing listener: isSelfChat=\(isSelfChat), participants=\(participants)")
                
                var typingUsers: [String: Date] = [:]
                
                // Look for typing_<userId> fields
                for (key, value) in data {
                    if key.hasPrefix("typing_") {
                        let userId = String(key.dropFirst("typing_".count))
                        
                        // For self-chats: show typing indicator even if it's your own
                        // For normal chats: skip current user's typing status
                        if isSelfChat || userId != currentUserId {
                            if let timestamp = value as? Timestamp {
                                typingUsers[userId] = timestamp.dateValue()
                                print("🔍 Found typing user: \(userId) at \(timestamp.dateValue())")
                            }
                        } else {
                            print("🔍 Skipping own typing status (not self-chat)")
                        }
                    }
                }
                
                print("🔍 Typing listener returning \(typingUsers.count) typing users")
                completion(typingUsers)
            }
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
            
            // For self-chat messages, use the stored isFromUser value
            // Otherwise, determine by comparing sender ID
            let isFromUser: Bool
            if let storedIsFromUser = data["isFromUser"] as? Bool {
                // Use stored value (important for self-chat messages)
                isFromUser = storedIsFromUser
            } else {
                // Fallback: compare sender ID
                isFromUser = senderId == currentUserId
            }

            let likedBy = data["likedBy"] as? [String] ?? []
            
            return Message(
                id: UUID(uuidString: messageId) ?? UUID(),
                content: content,
                timestamp: timestamp.dateValue(),
                isFromUser: isFromUser,
                senderName: nil,
                senderId: senderId,
                likedBy: likedBy
            )
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
              let participants = chatData["participants"] as? [String] else {
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
            
            let result = try await sendNotification.call([
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
                    guard data["title"] != nil else {
                        return nil
                    }
                    return (data: data, doc: doc)
                }
                
                // Fetch user data and latest message asynchronously for each chat
                Task {
                    var chats: [Chat] = []
                    
                    for (data, doc) in chatData {
                        guard let title = data["title"] as? String else {
                            continue
                        }
                        
                        // Skip chats that are hidden for this user
                        let hiddenFor = data["hiddenFor"] as? [String] ?? []
                        if hiddenFor.contains(currentUserId) {
                            continue
                        }
                        
                        // Read per-user unread count
                        let unreadFieldName = "unreadCount_\(currentUserId)"
                        let unreadCount = data[unreadFieldName] as? Int ?? 0
                        let chatId = data["id"] as? String ?? doc.documentID
                        let participants = data["participants"] as? [String] ?? []
                        let otherParticipantId = participants.first { $0 != currentUserId }
                        
                        // Fetch the actual most recent message from messages subcollection
                        let messagesSnapshot = try? await self.db.collection("chats")
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
                            if let otherUser = try? await self.getUser(withId: otherUserId) {
                                otherParticipantDisplayName = otherUser.displayName
                                otherParticipantAvatarURL = otherUser.avatarURL
                                otherParticipantBadgeType = otherUser.badgeType
                            }
                        }
                        
                        chats.append(Chat(
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
                    
                    // For self-chat messages, use the stored isFromUser value
                    // Otherwise, determine by comparing sender ID
                    let isFromUser: Bool
                    if let storedIsFromUser = data["isFromUser"] as? Bool {
                        // Use stored value (important for self-chat messages)
                        isFromUser = storedIsFromUser
                        print("🔍 Message listener: Using stored isFromUser=\(isFromUser) for message \(messageId)")
                    } else {
                        // Fallback: compare sender ID
                        isFromUser = senderId == currentUserId
                        print("🔍 Message listener: Calculated isFromUser=\(isFromUser) for message \(messageId) (senderId=\(senderId), currentUserId=\(currentUserId))")
                    }

                    let likedBy = data["likedBy"] as? [String] ?? []
                    
                    let message = Message(
                        id: UUID(uuidString: messageId) ?? UUID(),
                        content: content,
                        timestamp: timestamp.dateValue(),
                        isFromUser: isFromUser,
                        senderName: nil,
                        senderId: senderId,
                        likedBy: likedBy
                    )
                    
                    print("✅ Message retrieved: id=\(messageId), content='\(content)', isFromUser=\(isFromUser), likes=\(likedBy.count)")
                    return message
                }
                
                print("📥 Total messages retrieved: \(messages.count)")

                completion(messages)
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
        
        // Delete all replies to this loop
        let repliesSnapshot = try await db.collection("loops")
            .whereField("parentLoopId", isEqualTo: loopId)
            .getDocuments()
        
        let batch = db.batch()
        for replyDoc in repliesSnapshot.documents {
            batch.deleteDocument(replyDoc.reference)
        }
        
        // Delete the loop itself
        batch.deleteDocument(db.collection("loops").document(loopId))
        
        // If this is a reply, remove it from parent's replies array
        if let parentLoopId = data["parentLoopId"] as? String {
            let parentLoopRef = db.collection("loops").document(parentLoopId)
            batch.updateData([
                "replies": FieldValue.arrayRemove([loopId])
            ], forDocument: parentLoopRef)
        }
        
        try await batch.commit()
        print("✅ Successfully deleted loop: \(loopId)")
    }
    
    func getLoop(withId loopId: String) async throws -> Loop? {
        let doc = try await db.collection("loops").document(loopId).getDocument()
        guard let data = doc.data() else { return nil }
        
        guard let authorId = data["authorId"] as? String,
              let content = data["content"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        // Parse media
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
        
        // Fetch author information
        let author = try? await getUser(withId: authorId)
        
        return Loop(
            id: doc.documentID,
            authorId: authorId,
            content: content,
            media: media,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAtTimestamp.dateValue(),
            likes: data["likes"] as? [String] ?? [],
            replies: data["replies"] as? [String] ?? [],
            isReply: data["isReply"] as? Bool ?? false,
            parentLoopId: data["parentLoopId"] as? String,
            replyToReplyId: data["replyToReplyId"] as? String,
            authorDisplayName: author?.displayName,
            authorUsername: author?.username,
            authorAvatarURL: author?.avatarURL,
            authorBadgeType: author?.badgeType
        )
    }
    
    func getReplies(for loopId: String) async throws -> [Loop] {
        let snapshot = try await db.collection("loops")
            .whereField("parentLoopId", isEqualTo: loopId)
            .order(by: "createdAt", descending: true) // Newest first (Reddit-style)
            .getDocuments()
        
        var replies: [Loop] = []
        for doc in snapshot.documents {
            if let loop = try? await parseLoopFromDocument(doc) {
                replies.append(loop)
            }
        }
        
        return replies
    }
    
    private func parseLoopFromDocument(_ doc: QueryDocumentSnapshot) async throws -> Loop? {
        let data = doc.data()
        
        guard let authorId = data["authorId"] as? String,
              let content = data["content"] as? String,
              let createdAtTimestamp = data["createdAt"] as? Timestamp else {
            return nil
        }
        
        // Parse media
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
        
        // Fetch author information
        let author = try? await getUser(withId: authorId)
        
        return Loop(
            id: doc.documentID,
            authorId: authorId,
            content: content,
            media: media,
            createdAt: createdAtTimestamp.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? createdAtTimestamp.dateValue(),
            likes: data["likes"] as? [String] ?? [],
            replies: data["replies"] as? [String] ?? [],
            isReply: data["isReply"] as? Bool ?? false,
            parentLoopId: data["parentLoopId"] as? String,
            replyToReplyId: data["replyToReplyId"] as? String,
            authorDisplayName: author?.displayName,
            authorUsername: author?.username,
            authorAvatarURL: author?.avatarURL,
            authorBadgeType: author?.badgeType
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
}
