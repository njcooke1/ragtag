// ------------------------------------------
// 1) IMPORTS
// ------------------------------------------
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const admin = require('firebase-admin');

// Initialize the Firebase Admin SDK once
initializeApp();

// ------------------------------------------
// TAG NOTIFICATION FUNCTION
// Triggered when a new doc is created in:
//  clubs/{communityId}/tagNotifications/{tagId}
// ------------------------------------------
exports.sendTagNotification = onDocumentCreated(
  'clubs/{communityId}/tagNotifications/{tagId}',
  async (event) => {
    const newTag = event.data?.data();
    if (!newTag) {
      console.log('No data found in the created document.');
      return;
    }

    // Extract some info from the doc
    const tagTitle = newTag.title || 'New Tag';
    const tagMessage = newTag.message || '';
    const communityId = event.params.communityId;
    const tagId = event.params.tagId;

    console.log(
      `Tag created: Title=${tagTitle}, Message=${tagMessage}, ` +
      `CommunityID=${communityId}, TagID=${tagId}`
    );

    // Reference to the club
    const communityRef = admin.firestore().collection('clubs').doc(communityId);

    try {
      // Grab the club doc
      const communitySnap = await communityRef.get();
      if (!communitySnap.exists) {
        console.log(`Community with ID ${communityId} does not exist.`);
        return;
      }

      const communityData = communitySnap.data() || {};
      // Suppose "clubs" has a "members" object with userIds as keys
      const membersMap = communityData.members || {};
      const memberIds = Object.keys(membersMap);

      if (memberIds.length === 0) {
        console.log('No members found to send notifications.');
        return;
      }

      console.log(`Found ${memberIds.length} members in community ${communityId}.`);

      // Collect all FCM tokens
      const fcmTokens = [];
      for (const userId of memberIds) {
        const userRef = admin.firestore().collection('users').doc(userId);
        const userSnap = await userRef.get();
        if (!userSnap.exists) continue;

        const userData = userSnap.data();
        const token = userData?.fcmToken;
        if (token) {
          fcmTokens.push(token);
        }
      }

      if (fcmTokens.length === 0) {
        console.log('No valid FCM tokens found among members.');
        return;
      }

      // Build the push notification
      const message = {
        tokens: fcmTokens,
        notification: {
          title: tagTitle,
          body: tagMessage,
        },
        data: {
          communityId,
          tagId,
        },
      };

      // Send to multiple tokens at once
      const response = await admin.messaging().sendMulticast(message);
      console.log(
        `Tag notifications sent: ${response.successCount} succeeded, ` +
        `${response.failureCount} failed.`
      );

      // Remove invalid tokens
      const tokensToRemove = [];
      response.responses.forEach((res, idx) => {
        if (res.error) {
          console.error(`Error sending to token ${fcmTokens[idx]}:`, res.error);
          if (
            res.error.code === 'messaging/invalid-registration-token' ||
            res.error.code === 'messaging/registration-token-not-registered'
          ) {
            tokensToRemove.push(fcmTokens[idx]);
          }
        }
      });

      if (tokensToRemove.length > 0) {
        console.log('Removing invalid tokens from Firestore:', tokensToRemove);
        for (const invalidToken of tokensToRemove) {
          const usersSnap = await admin
            .firestore()
            .collection('users')
            .where('fcmToken', '==', invalidToken)
            .get();
          if (!usersSnap.empty) {
            // Remove the token from each matched user doc
            for (const doc of usersSnap.docs) {
              await doc.ref.update({
                fcmToken: admin.firestore.FieldValue.delete(),
              });
              console.log(`Removed invalid token from user ${doc.id}`);
            }
          }
        }
      }
    } catch (err) {
      console.error('Error in sendTagNotification:', err);
    }
  }
);

// ------------------------------------------
// CHAT MESSAGE NOTIFICATION FUNCTION
// Triggered when a new doc is created in:
//   chats/{chatId}/messages/{messageId}
// ------------------------------------------
exports.sendChatNotification = onDocumentCreated(
  'chats/{chatId}/messages/{messageId}',
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) {
      console.log('No message data found in the created document.');
      return;
    }

    const chatId = event.params.chatId;
    const senderId = messageData.senderId || '';
    const text = messageData.text || 'New message';

    console.log(`New message in chat ${chatId} from user ${senderId}`);

    // 1) Fetch the chat doc to see who the participants are
    const chatRef = admin.firestore().collection('chats').doc(chatId);
    const chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      console.log(`Chat with ID ${chatId} does not exist.`);
      return;
    }

    const chatInfo = chatSnap.data() || {};
    // Suppose it has an array of user IDs
    const participants = chatInfo.participants || [];
    if (!participants.length) {
      console.log(`No participants found for chat ${chatId}.`);
      return;
    }

    // 2) Find the other participants
    const otherUserIds = participants.filter((uid) => uid !== senderId);
    if (!otherUserIds.length) {
      console.log(`No other participants to notify for chat ${chatId}.`);
      return;
    }

    // 3) Collect FCM tokens
    const fcmTokens = [];
    for (const userId of otherUserIds) {
      const userDoc = await admin.firestore().collection('users').doc(userId).get();
      if (!userDoc.exists) continue;
      const userData = userDoc.data();
      if (userData?.fcmToken) {
        fcmTokens.push(userData.fcmToken);
      }
    }

    if (!fcmTokens.length) {
      console.log(`No valid FCM tokens found among recipients in chat ${chatId}.`);
      return;
    }

    // 4) Build the push notification payload
    const messagePayload = {
      tokens: fcmTokens,
      notification: {
        title: 'New Message',
        body: text, // or 'Image message' if there's no text
      },
      data: {
        chatId,
      },
    };

    // 5) Send notifications
    try {
      const response = await admin.messaging().sendMulticast(messagePayload);
      console.log(
        `Chat notifications sent: ${response.successCount} succeeded, ` +
        `${response.failureCount} failed.`
      );

      // 6) Remove invalid tokens
      const tokensToRemove = [];
      response.responses.forEach((res, idx) => {
        if (res.error) {
          console.error(`Error sending to token: ${fcmTokens[idx]}`, res.error);
          if (
            res.error.code === 'messaging/invalid-registration-token' ||
            res.error.code === 'messaging/registration-token-not-registered'
          ) {
            tokensToRemove.push(fcmTokens[idx]);
          }
        }
      });

      if (tokensToRemove.length) {
        console.log('Removing invalid tokens from Firestore:', tokensToRemove);
        for (const invalidToken of tokensToRemove) {
          const usersWithBadToken = await admin
            .firestore()
            .collection('users')
            .where('fcmToken', '==', invalidToken)
            .get();

          if (!usersWithBadToken.empty) {
            for (const doc of usersWithBadToken.docs) {
              await doc.ref.update({
                fcmToken: admin.firestore.FieldValue.delete(),
              });
              console.log(`Removed invalid token from user ${doc.id}`);
            }
          }
        }
      }
    } catch (error) {
      console.error('Error sending chat notifications:', error);
    }
  }
);
