import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize local notifications and set up tap handling.
  Future<void> initialize({required GlobalKey<NavigatorState> navigatorKey}) async {
    // Initialization settings for Android and iOS.
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iOSSettings = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final String? payload = response.payload;
        if (payload != null) {
          _handleNotificationTap(payload, navigatorKey);
        }
      },
    );

    // Also listen for FCM messages that open the app.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        final String? payload = message.data['payload'];
        if (payload != null && payload.isNotEmpty) {
          _handleNotificationTap(payload, navigatorKey);
        }
      }
    });
  }

  /// Handle what happens when a notification is tapped.
  void _handleNotificationTap(String payload, GlobalKey<NavigatorState> navigatorKey) {
    try {
      final Map<String, dynamic> data = jsonDecode(payload);
      final String screen = data['screen'];
      if (screen == 'chat') {
        final String chatId = data['chatId'];
        // Navigate to the chat screen with the provided chatId.
        navigatorKey.currentState?.pushNamed('/chat', arguments: {'chatId': chatId});
      }
      // Handle other screens if needed.
    } catch (e) {
      print('Error handling notification tap: $e');
    }
  }

  /// Show a local notification (typically used for foreground messages).
  Future<void> showLocalNotification(RemoteMessage message) async {
    final RemoteNotification? notification = message.notification;
    if (notification == null) return;

    // Optionally, assume your FCM data includes a "payload" key (a JSON string).
    final String? payload = message.data['payload'];

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'default_channel',
      'Default',
      channelDescription: 'Default channel for notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      platformDetails,
      payload: payload,
    );
  }
}
