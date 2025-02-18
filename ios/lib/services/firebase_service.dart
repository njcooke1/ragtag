import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fetch tags for a specific community
  Stream<List<Map<String, dynamic>>> fetchTags(String communityId) {
    return _firestore
        .collection('communities')
        .doc(communityId)
        .collection('tags')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
  }

  // Add a new tag
  Future<void> addTag(String communityId, Map<String, dynamic> tagData) async {
    await _firestore.collection('communities').doc(communityId).collection('tags').add(tagData);
  }

  // Fetch user role (admin/member)
  Future<bool> checkAdminStatus(String communityId, String userId) async {
    final doc = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('admins')
        .doc(userId)
        .get();
    return doc.exists;
  }

  Future<bool> checkMembershipStatus(String communityId, String userId) async {
    final doc = await _firestore
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(userId)
        .get();
    return doc.exists;
  }
}
