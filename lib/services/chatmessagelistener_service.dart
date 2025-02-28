import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class ChatMessageListenerService {
  // Keep track of all active subscriptions so they can be cancelled later.
  final List<StreamSubscription<QuerySnapshot>> _subscriptions = [];

  /// Listen for messages in a user-to-user chat.
  /// Firestore path: chats/{chatId}/messages
  void listenToUserChat(String chatId) {
    final CollectionReference messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages');

    final subscription = messagesRef.orderBy('timestamp').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          // Optionally, tag the data with the chat type.
          data['chatType'] = 'user';
          NotificationService().showChatNotification(data);
        }
      }
    });
    _subscriptions.add(subscription);
  }

  /// Listen for messages in a club chat.
  /// Firestore path: clubs/{clubId}/messages
  void listenToClubChat(String clubId) {
    final CollectionReference messagesRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .collection('messages');

    final subscription = messagesRef.orderBy('timestamp').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          data['chatType'] = 'club';
          NotificationService().showChatNotification(data);
        }
      }
    });
    _subscriptions.add(subscription);
  }

  /// Listen for messages in an interest group chat.
  /// Firestore path: interestGroups/{interestGroupId}/messages
  void listenToInterestGroupChat(String interestGroupId) {
    final CollectionReference messagesRef = FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(interestGroupId)
        .collection('messages');

    final subscription = messagesRef.orderBy('timestamp').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          data['chatType'] = 'interestGroup';
          NotificationService().showChatNotification(data);
        }
      }
    });
    _subscriptions.add(subscription);
  }

  /// Listen for messages in an open forum chat.
  /// Firestore path: openForums/{openForumId}/messages
  void listenToOpenForumChat(String openForumId) {
    final CollectionReference messagesRef = FirebaseFirestore.instance
        .collection('openForums')
        .doc(openForumId)
        .collection('messages');

    final subscription = messagesRef.orderBy('timestamp').snapshots().listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          data['chatType'] = 'openForum';
          NotificationService().showChatNotification(data);
        }
      }
    });
    _subscriptions.add(subscription);
  }

  /// Optionally, listen to multiple chat channels at once.
  /// Each channel is represented as a map with keys 'type' and 'id'.
  /// For example: {'type': 'user', 'id': 'chat123'}
  void listenToMultipleChats(List<Map<String, String>> chatChannels) {
    for (var channel in chatChannels) {
      final String? type = channel['type'];
      final String? id = channel['id'];
      if (type == null || id == null) continue;

      switch (type) {
        case 'user':
          listenToUserChat(id);
          break;
        case 'club':
          listenToClubChat(id);
          break;
        case 'interestGroup':
          listenToInterestGroupChat(id);
          break;
        case 'openForum':
          listenToOpenForumChat(id);
          break;
        default:
          print('Unsupported chat type: $type');
          break;
      }
    }
  }

  /// Cancel all active listeners to avoid memory leaks.
  void stopListening() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
