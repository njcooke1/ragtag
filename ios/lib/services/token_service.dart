// lib/services/token_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class TokenService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Initializes token collection by saving the current token and setting up a listener for token refresh.
  Future<void> initializeToken() async {
    User? user = _auth.currentUser;
    if (user == null) return; // User not signed in

    String? token = await _messaging.getToken();
    if (token == null) return; // Failed to obtain token

    // Save the token to Firestore
    await _firestore.collection('users').doc(user.uid).update({
      'fcmToken': token,
    });

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) async {
      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': newToken,
      });
    });
  }
}
