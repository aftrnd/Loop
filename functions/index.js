/**
 * Firebase Cloud Functions for Loop App
 * Handles push notifications for messages
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send push notification when a new message is received
 * @param {Object} data - Contains fcmToken, title, body, chatId
 * @param {Object} context - Authentication context
 * @returns {Object} Success status
 */
exports.sendNotification = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'The function must be called while authenticated.'
    );
  }

  const { fcmToken, title, body, chatId, senderId, type } = data;
  
  // Validate required parameters
  if (!fcmToken || !title || !body || !chatId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required parameters: fcmToken, title, body, or chatId'
    );
  }
  
  // Construct the message
  const message = {
    notification: {
      title: title,
      body: body,
    },
    data: {
      chatId: chatId,
      senderId: senderId || '',
      type: type || 'message', // Use provided type or default to 'message'
    },
    apns: {
      payload: {
        aps: {
          sound: 'default',
          'content-available': 1,
        },
      },
    },
    token: fcmToken,
  };
  
  try {
    const response = await admin.messaging().send(message);
    console.log('Successfully sent message:', response);
    return { success: true, messageId: response };
  } catch (error) {
    console.error('Error sending message:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

/**
 * Alternative: Firestore trigger to send notifications automatically
 * Uncomment this if you want automatic notifications without manual calls
 */
/*
exports.sendMessageNotificationOnCreate = functions.firestore
  .document('chats/{chatId}/messages/{messageId}')
  .onCreate(async (snap, context) => {
    const message = snap.data();
    const chatId = context.params.chatId;
    
    // Get chat document to find participants
    const chatDoc = await admin.firestore().collection('chats').doc(chatId).get();
    const chatData = chatDoc.data();
    
    if (!chatData || !chatData.participants) {
      return null;
    }
    
    // Send notification to all participants except the sender
    const notifications = chatData.participants
      .filter(participantId => participantId !== message.senderId)
      .map(async (participantId) => {
        // Get participant's user document for FCM token
        const userDoc = await admin.firestore().collection('users').doc(participantId).get();
        const userData = userDoc.data();
        
        if (!userData || !userData.fcmToken) {
          console.log(`No FCM token for user ${participantId}`);
          return null;
        }
        
        // Get sender's name
        const senderDoc = await admin.firestore().collection('users').doc(message.senderId).get();
        const senderName = senderDoc.data()?.displayName || 'Someone';
        
        const notificationMessage = {
          notification: {
            title: senderName,
            body: message.content,
            sound: 'default',
          },
          data: {
            chatId: chatId,
            senderId: message.senderId,
            type: 'message',
          },
          apns: {
            payload: {
              aps: {
                sound: 'default',
                'content-available': 1,
              },
            },
          },
          token: userData.fcmToken,
        };
        
        try {
          const response = await admin.messaging().send(notificationMessage);
          console.log(`Notification sent to ${participantId}:`, response);
          return response;
        } catch (error) {
          console.error(`Error sending notification to ${participantId}:`, error);
          return null;
        }
      });
    
    return Promise.all(notifications);
  });
*/

