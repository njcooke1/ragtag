// lib/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'managing_community.dart';

class HomePage extends StatefulWidget {
  final String userId;

  const HomePage({Key? key, required this.userId}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late CollectionReference _userCommunities;

  @override
  void initState() {
    super.initState();
    _userCommunities = _firestore
        .collection('users')
        .doc(widget.userId)
        .collection('communities');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Communities'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _userCommunities.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading communities.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          if (data == null || data.docs.isEmpty) {
            return const Center(child: Text('You have not joined any communities.'));
          }

          return ListView.builder(
            itemCount: data.docs.length,
            itemBuilder: (context, index) {
              var communityRef = data.docs[index].id;
              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('communities').doc(communityRef).get(),
                builder: (context, communitySnapshot) {
                  if (communitySnapshot.connectionState == ConnectionState.waiting) {
                    return const ListTile(
                      title: Text('Loading...'),
                    );
                  }

                  if (!communitySnapshot.hasData || !communitySnapshot.data!.exists) {
                    return const ListTile(
                      title: Text('Community does not exist.'),
                    );
                  }

                  var communityData = communitySnapshot.data!.data() as Map<String, dynamic>;
                  String communityName = communityData['name'] ?? 'Unnamed Community';

                  return ListTile(
                    leading: const Icon(Icons.group),
                    title: Text(communityName),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ManagingCommunityPage(
                            communityId: communityRef,
                            communityData: communityData,
                            userId: widget.userId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
