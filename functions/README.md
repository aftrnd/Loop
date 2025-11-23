# Firebase Cloud Functions for Loop

## Setup

1. Install dependencies:
```bash
cd functions
npm install
```

2. Deploy functions:
```bash
firebase deploy --only functions
```

Or deploy a specific function:
```bash
firebase deploy --only functions:sendNotification
```

## Functions

### sendNotification
Sends a push notification to a specific device token.

**Parameters:**
- `fcmToken` (string): The FCM device token
- `title` (string): Notification title (sender name)
- `body` (string): Notification body (message content)
- `chatId` (string): The chat ID to open when notification is tapped
- `senderId` (string, optional): The sender's user ID

**Usage from Swift:**
```swift
let functions = Functions.functions()
let sendNotification = functions.httpsCallable("sendNotification")

try? await sendNotification.call([
    "fcmToken": recipientToken,
    "title": senderName,
    "body": messageContent,
    "chatId": chatId,
    "senderId": currentUserId
])
```

## Testing Locally

Run the Firebase emulator:
```bash
npm run serve
```

This will start the functions emulator on http://localhost:5001

## Logs

View function logs:
```bash
npm run logs
```

Or in Firebase Console → Functions → Logs

