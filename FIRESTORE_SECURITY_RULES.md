# Firestore Security Rules for Loop

## Overview
These security rules ensure that users can only access their own data and chats they participate in.

## Rules to Add in Firebase Console

Go to Firebase Console → Firestore Database → Rules and paste this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user is the owner
    function isOwner(userId) {
      return isAuthenticated() && request.auth.uid == userId;
    }
    
    // Users Collection
    match /users/{userId} {
      // Users can read any user profile (for looking up contacts)
      allow read: if isAuthenticated();
      
      // Users can only create/update their own profile
      allow create, update: if isOwner(userId);
      
      // Users can only delete their own profile
      allow delete: if isOwner(userId);
    }
    
    // Chats Collection
    match /chats/{chatId} {
      // Users can only read chats they are a participant in
      allow read: if isAuthenticated() && 
                     request.auth.uid in resource.data.participants;
      
      // Users can create chats if they are in the participants list
      allow create: if isAuthenticated() && 
                       request.auth.uid in request.resource.data.participants;
      
      // Users can update chats they participate in
      allow update: if isAuthenticated() && 
                       request.auth.uid in resource.data.participants;
      
      // Users can delete chats they participate in
      allow delete: if isAuthenticated() && 
                       request.auth.uid in resource.data.participants;
      
      // Messages subcollection
      match /messages/{messageId} {
        // Users can read messages in chats they participate in
        allow read: if isAuthenticated() && 
                       request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        
        // Users can create messages in chats they participate in
        allow create: if isAuthenticated() && 
                         request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants &&
                         request.resource.data.senderId == request.auth.uid;
        
        // No one can update or delete messages (optional, you can allow this if needed)
        allow update, delete: if false;
      }
    }
  }
}
```

## What These Rules Do

### 1. **User Profiles** (`/users/{userId}`)
- ✅ Any authenticated user can **read** any profile (needed to look up contacts by phone)
- ✅ Users can only **create/update/delete** their own profile
- ❌ Users cannot modify other users' profiles

### 2. **Chats** (`/chats/{chatId}`)
- ✅ Users can only see chats where they are in the `participants` array
- ✅ Users can create chats if they include themselves in `participants`
- ✅ Users can update/delete chats they participate in
- ❌ Users cannot see or access chats they're not part of

### 3. **Messages** (`/chats/{chatId}/messages/{messageId}`)
- ✅ Users can read messages in chats they participate in
- ✅ Users can send messages (with their own `senderId`)
- ❌ Users cannot send messages as someone else
- ❌ Messages cannot be edited or deleted (optional - change if needed)

## How to Apply

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to **Firestore Database** → **Rules**
4. Replace the existing rules with the rules above
5. Click **Publish**

## Testing Rules

After publishing, test in Firebase Console:

```javascript
// Test 1: User can read their own chats
match /chats/test-chat-id
allow read: if auth.uid in resource.data.participants

// Test 2: User cannot read other users' chats
match /chats/test-chat-id
allow read: if auth.uid NOT in resource.data.participants
// Should fail
```

## Important Notes

⚠️ **Without these rules, your database is currently open to anyone!**

✅ After applying these rules:
- Users can only see their own chats
- Users can only see chats they're invited to
- Phone number lookup still works (users can read profiles)
- Message security is enforced

## Optional Enhancements

### Allow Message Editing/Deletion
Change the messages rules to:
```javascript
allow update, delete: if isAuthenticated() && 
                         resource.data.senderId == request.auth.uid;
```

### Prevent Duplicate User Phone Numbers
Add this to user creation:
```javascript
allow create: if isOwner(userId) && 
                 !exists(/databases/$(database)/documents/users/$(request.resource.data.phoneNumber));
```

### Add Chat Size Limits
```javascript
allow create: if request.resource.data.participants.size() <= 10;
```

