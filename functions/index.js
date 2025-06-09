// ------------------------------------------
// 1) IMPORTS
// ------------------------------------------
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const admin = require('firebase-admin');

// Initialize the Firebase Admin SDK once
initializeApp();

// ------------------------------------------
// HELPER FUNCTION: Send notifications
// ------------------------------------------
async function sendNotification(fcmTokens, notificationPayload) {
  if (fcmTokens.length === 1) {
    const message = {
      token: fcmTokens[0],
      notification: notificationPayload.notification,
      data: notificationPayload.data,
    };
    const messageId = await admin.messaging().send(message);
    return {
      successCount: 1,
      failureCount: 0,
      responses: [{ error: null, messageId }],
    };
  } else {
    const messages = fcmTokens.map((token) => ({
      token,
      notification: notificationPayload.notification,
      data: notificationPayload.data,
    }));
    return await admin.messaging().sendAll(messages);
  }
}

// ------------------------------------------
// HELPER FUNCTION: Get sender's full name
// ------------------------------------------
async function getSenderName(senderId, currentName) {
  // If currentName is set and not "Anonymous", use it.
  if (currentName && currentName !== 'Anonymous') {
    return currentName;
  }
  try {
    const userDoc = await admin.firestore().collection('users').doc(senderId).get();
    if (userDoc.exists) {
      return userDoc.data().fullName || 'Unknown User';
    }
  } catch (error) {
    console.error(`Error fetching fullName for senderId ${senderId}:`, error);
  }
  return 'Unknown User';
}

// ------------------------------------------
// TAG NOTIFICATION FUNCTION
// (Remains unchanged)
// ------------------------------------------
exports.sendTagNotification = onDocumentCreated(
  'clubs/{communityId}/tagNotifications/{tagId}',
  async (event) => {
    const newTag = event.data?.data();
    if (!newTag) {
      console.log('No data found in the created document.');
      return;
    }

    const tagTitle = newTag.title || 'New Tag';
    const tagMessage = newTag.message || '';
    const communityId = event.params.communityId;
    const tagId = event.params.tagId;

    console.log(
      `Tag created: Title=${tagTitle}, Message=${tagMessage}, CommunityID=${communityId}, TagID=${tagId}`
    );

    const communityRef = admin.firestore().collection('clubs').doc(communityId);
    try {
      const communitySnap = await communityRef.get();
      if (!communitySnap.exists) {
        console.log(`Community with ID ${communityId} does not exist.`);
        return;
      }

      const communityData = communitySnap.data() || {};
      const membersMap = communityData.members || {};
      const memberIds = Object.keys(membersMap);

      if (memberIds.length === 0) {
        console.log('No members found to send notifications.');
        return;
      }

      console.log(`Found ${memberIds.length} members in community ${communityId}.`);

      const fcmTokens = [];
      for (const userId of memberIds) {
        const userRef = admin.firestore().collection('users').doc(userId);
        const userSnap = await userRef.get();
        if (!userSnap.exists) continue;
        const userData = userSnap.data();
        if (userData?.fcmToken) {
          fcmTokens.push(userData.fcmToken);
        }
      }

      if (fcmTokens.length === 0) {
        console.log('No valid FCM tokens found among members.');
        return;
      }

      const notificationPayload = {
        notification: {
          title: tagTitle,
          body: tagMessage,
        },
        data: { communityId, tagId },
      };

      const response = await sendNotification(fcmTokens, notificationPayload);
      console.log(`Tag notifications sent: ${response.successCount} succeeded, ${response.failureCount} failed.`);

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
          const usersSnap = await admin.firestore().collection('users').where('fcmToken', '==', invalidToken).get();
          if (!usersSnap.empty) {
            for (const doc of usersSnap.docs) {
              await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
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
// USER CHAT MESSAGE NOTIFICATION FUNCTION
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
    const messageId = event.params.messageId;
    const senderId = messageData.senderId || '';
    let senderName = messageData.senderName || 'Unknown User';
    senderName = await getSenderName(senderId, senderName);

    // Update the message document if the senderName is outdated.
    if (messageData.senderName !== senderName) {
      await admin.firestore()
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .update({ senderName });
    }

    const messageText = messageData.text || '';
    const messagePreview =
      messageText.length > 0
        ? messageText.substring(0, 50) + (messageText.length > 50 ? '…' : '')
        : 'sent a message';

    console.log(`New message in chat ${chatId} from ${senderName}`);

    const chatRef = admin.firestore().collection('chats').doc(chatId);
    const chatSnap = await chatRef.get();
    if (!chatSnap.exists) {
      console.log(`Chat with ID ${chatId} does not exist.`);
      return;
    }

    const chatInfo = chatSnap.data() || {};
    const participants = chatInfo.participants || [];
    if (!participants.length) {
      console.log(`No participants found for chat ${chatId}.`);
      return;
    }

    const otherUserIds = participants.filter((uid) => uid !== senderId);
    if (!otherUserIds.length) {
      console.log(`No other participants to notify for chat ${chatId}.`);
      return;
    }

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

    const notificationPayload = {
      notification: { title: senderName, body: messagePreview },
      data: { chatId },
    };

    try {
      const response = await sendNotification(fcmTokens, notificationPayload);
      console.log(`Chat notifications sent: ${response.successCount} succeeded, ${response.failureCount} failed.`);

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
      if (tokensToRemove.length) {
        console.log('Removing invalid tokens from Firestore:', tokensToRemove);
        for (const invalidToken of tokensToRemove) {
          const usersWithBadToken = await admin.firestore().collection('users').where('fcmToken', '==', invalidToken).get();
          if (!usersWithBadToken.empty) {
            for (const doc of usersWithBadToken.docs) {
              await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
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

// ------------------------------------------
// CLUB CHAT MESSAGE NOTIFICATION FUNCTION
// ------------------------------------------
exports.sendClubChatNotification = onDocumentCreated(
  'clubs/{clubId}/messages/{messageId}',
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) {
      console.log('No message data found in the created club message document.');
      return;
    }

    const clubId = event.params.clubId;
    const messageId = event.params.messageId;
    const senderId = messageData.senderId || '';
    let senderName = messageData.senderName || 'Unknown User';
    senderName = await getSenderName(senderId, senderName);

    // Update the message document if the senderName is outdated.
    if (messageData.senderName !== senderName) {
      await admin.firestore()
        .collection('clubs')
        .doc(clubId)
        .collection('messages')
        .doc(messageId)
        .update({ senderName });
    }

    const messageText = messageData.text || '';
    const messagePreview =
      messageText.length > 0
        ? messageText.substring(0, 50) + (messageText.length > 50 ? '…' : '')
        : 'sent a message';

    console.log(`New message in club ${clubId} from ${senderName}`);

    const clubRef = admin.firestore().collection('clubs').doc(clubId);
    const clubSnap = await clubRef.get();
    if (!clubSnap.exists) {
      console.log(`Club with ID ${clubId} does not exist.`);
      return;
    }

    const clubData = clubSnap.data() || {};
    const membersMap = clubData.members || {};
    const memberIds = Object.keys(membersMap);
    if (!memberIds.length) {
      console.log(`No members found for club ${clubId}.`);
      return;
    }

    const otherUserIds = memberIds.filter((uid) => uid !== senderId);
    if (!otherUserIds.length) {
      console.log(`No other members to notify for club ${clubId}.`);
      return;
    }

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
      console.log(`No valid FCM tokens found among recipients in club ${clubId}.`);
      return;
    }

    const notificationPayload = {
      notification: { title: senderName, body: messagePreview },
      data: { clubId },
    };

    try {
      const response = await sendNotification(fcmTokens, notificationPayload);
      console.log(`Club chat notifications sent: ${response.successCount} succeeded, ${response.failureCount} failed.`);

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
      if (tokensToRemove.length) {
        console.log('Removing invalid tokens from Firestore:', tokensToRemove);
        for (const invalidToken of tokensToRemove) {
          const usersSnap = await admin.firestore().collection('users').where('fcmToken', '==', invalidToken).get();
          if (!usersSnap.empty) {
            for (const doc of usersSnap.docs) {
              await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
              console.log(`Removed invalid token from user ${doc.id}`);
            }
          }
        }
      }
    } catch (error) {
      console.error('Error sending club chat notifications:', error);
    }
  }
);

// ------------------------------------------
// INTEREST GROUP CHAT MESSAGE NOTIFICATION FUNCTION
// ------------------------------------------
exports.sendInterestGroupChatNotification = onDocumentCreated(
  'interestGroups/{interestGroupId}/messages/{messageId}',
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) {
      console.log('No message data found in the created interest group message document.');
      return;
    }

    const interestGroupId = event.params.interestGroupId;
    const messageId = event.params.messageId;
    const senderId = messageData.senderId || '';
    let senderName = messageData.senderName || 'Unknown User';
    senderName = await getSenderName(senderId, senderName);

    // Update the message document if the senderName is outdated.
    if (messageData.senderName !== senderName) {
      await admin.firestore()
        .collection('interestGroups')
        .doc(interestGroupId)
        .collection('messages')
        .doc(messageId)
        .update({ senderName });
    }

    const messageText = messageData.text || '';
    const messagePreview =
      messageText.length > 0
        ? messageText.substring(0, 50) + (messageText.length > 50 ? '…' : '')
        : 'sent a message';

    console.log(`New message in interest group ${interestGroupId} from ${senderName}`);

    const groupRef = admin.firestore().collection('interestGroups').doc(interestGroupId);
    const groupSnap = await groupRef.get();
    if (!groupSnap.exists) {
      console.log(`Interest group with ID ${interestGroupId} does not exist.`);
      return;
    }

    const groupData = groupSnap.data() || {};
    const membersMap = groupData.members || {};
    const memberIds = Object.keys(membersMap);
    if (!memberIds.length) {
      console.log(`No members found for interest group ${interestGroupId}.`);
      return;
    }

    const otherUserIds = memberIds.filter((uid) => uid !== senderId);
    if (!otherUserIds.length) {
      console.log(`No other members to notify for interest group ${interestGroupId}.`);
      return;
    }

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
      console.log(`No valid FCM tokens found among recipients in interest group ${interestGroupId}.`);
      return;
    }

    const notificationPayload = {
      notification: { title: senderName, body: messagePreview },
      data: { interestGroupId },
    };

    try {
      const response = await sendNotification(fcmTokens, notificationPayload);
      console.log(`Interest group chat notifications sent: ${response.successCount} succeeded, ${response.failureCount} failed.`);

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
      if (tokensToRemove.length) {
        console.log('Removing invalid tokens from Firestore:', tokensToRemove);
        for (const invalidToken of tokensToRemove) {
          const usersSnap = await admin.firestore().collection('users').where('fcmToken', '==', invalidToken).get();
          if (!usersSnap.empty) {
            for (const doc of usersSnap.docs) {
              await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
              console.log(`Removed invalid token from user ${doc.id}`);
            }
          }
        }
      }
    } catch (error) {
      console.error('Error sending interest group chat notifications:', error);
    }
  }
);

// ------------------------------------------
// OPEN FORUM CHAT MESSAGE NOTIFICATION FUNCTION
// ------------------------------------------
exports.sendOpenForumChatNotification = onDocumentCreated(
  'openForums/{openForumId}/messages/{messageId}',
  async (event) => {
    const messageData = event.data?.data();
    if (!messageData) {
      console.log('No message data found in the created open forum message document.');
      return;
    }

    const openForumId = event.params.openForumId;
    const messageId = event.params.messageId;
    const senderId = messageData.senderId || '';
    let senderName = messageData.senderName || 'Unknown User';
    senderName = await getSenderName(senderId, senderName);

    // Update the message document if the senderName is outdated.
    if (messageData.senderName !== senderName) {
      await admin.firestore()
        .collection('openForums')
        .doc(openForumId)
        .collection('messages')
        .doc(messageId)
        .update({ senderName });
    }

    const messageText = messageData.text || '';
    const messagePreview =
      messageText.length > 0
        ? messageText.substring(0, 50) + (messageText.length > 50 ? '…' : '')
        : 'sent a message';

    console.log(`New message in open forum ${openForumId} from ${senderName}`);

    const forumRef = admin.firestore().collection('openForums').doc(openForumId);
    const forumSnap = await forumRef.get();
    if (!forumSnap.exists) {
      console.log(`Open forum with ID ${openForumId} does not exist.`);
      return;
    }

    const forumData = forumSnap.data() || {};
    const participantsMap = forumData.participants || forumData.members || {};
    const participantIds = Object.keys(participantsMap);
    if (!participantIds.length) {
      console.log(`No participants found for open forum ${openForumId}.`);
      return;
    }

    const otherUserIds = participantIds.filter((uid) => uid !== senderId);
    if (!otherUserIds.length) {
      console.log(`No other participants to notify for open forum ${openForumId}.`);
      return;
    }

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
      console.log(`No valid FCM tokens found among recipients in open forum ${openForumId}.`);
      return;
    }

    const notificationPayload = {
      notification: { title: senderName, body: messagePreview },
      data: { openForumId },
    };

    try {
      const response = await sendNotification(fcmTokens, notificationPayload);
      console.log(`Open forum chat notifications sent: ${response.successCount} succeeded, ${response.failureCount} failed.`);

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
      if (tokensToRemove.length) {
        console.log('Removing invalid tokens from Firestore:', tokensToRemove);
        for (const invalidToken of tokensToRemove) {
          const usersSnap = await admin.firestore().collection('users').where('fcmToken', '==', invalidToken).get();
          if (!usersSnap.empty) {
            for (const doc of usersSnap.docs) {
              await doc.ref.update({ fcmToken: admin.firestore.FieldValue.delete() });
              console.log(`Removed invalid token from user ${doc.id}`);
            }
          }
        }
      }
    } catch (error) {
      console.error('Error sending open forum chat notifications:', error);
    }
  }
);
