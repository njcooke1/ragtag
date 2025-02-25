import 'dart:math';
import 'dart:ui'; // For HSLColor conversion

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

//
// --- Helper Functions for Report / Block Actions ---
//

void _showCommunityActions(BuildContext context, String communityId, String collectionName) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.black87,
    builder: (ctx) {
      return SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.flag, color: Colors.redAccent),
              title: const Text(
                'Report Community',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _showReportDialog(context, communityId, collectionName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.orangeAccent),
              title: const Text(
                'Block Community',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _blockCommunity(context, communityId);
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showReportDialog(BuildContext context, String communityId, String collectionName) {
  String selectedReason = 'Spam or Scam';
  final TextEditingController _descriptionController = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.black87,
            title: const Text(
              'Report Community',
              style: TextStyle(color: Colors.white70),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    dropdownColor: Colors.black87,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                    ),
                    items: <String>[
                      'Spam or Scam',
                      'Harassment or Bullying',
                      'Inappropriate Content',
                      'Fake Community',
                      'Other',
                    ].map((reason) => DropdownMenuItem<String>(
                      value: reason,
                      child: Text(reason, style: const TextStyle(color: Colors.white)),
                    )).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedReason = value ?? 'Spam or Scam';
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Additional details (optional)',
                      labelStyle: TextStyle(color: Colors.white70),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.white54),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'We will conduct a full investigation within 24 hours.',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _reportCommunity(
                    context,
                    communityId,
                    selectedReason,
                    _descriptionController.text,
                    collectionName,
                  );
                },
                child: const Text(
                  'Submit',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

Future<void> _reportCommunity(
  BuildContext context,
  String communityId,
  String reason,
  String description,
  String collectionName,
) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  try {
    await FirebaseFirestore.instance.collection('reports').add({
      'reporterUid': currentUser.uid,
      'reportedCommunityId': communityId,
      'collection': collectionName,
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
      'reason': reason,
      'description': description,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted. We will conduct a full investigation within 24 hours.'),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error reporting community: $e')),
    );
  }
}

Future<void> _blockCommunity(BuildContext context, String communityId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  try {
    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
      'BlockedCommunities': FieldValue.arrayUnion([communityId]),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Community blocked.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error blocking community: $e')),
    );
  }
}

Future<void> _unblockCommunity(BuildContext context, String communityId) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;
  try {
    await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
      'BlockedCommunities': FieldValue.arrayRemove([communityId]),
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Community unblocked.')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error unblocking community: $e')),
    );
  }
}

/// Fetch the current user’s blocked community IDs.
Future<List<String>> _fetchBlockedCommunityIds() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) return [];
  final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
  final blockedList = userDoc.data()?['BlockedCommunities'] as List<dynamic>? ?? [];
  return blockedList.map((e) => e.toString()).toList();
}

/// Filter ghost docs: only members see ghost-mode docs.
Future<List<QueryDocumentSnapshot>> _filterGhostDocs(
  List<QueryDocumentSnapshot> inputDocs,
) async {
  final user = FirebaseAuth.instance.currentUser;
  final uid = user?.uid;
  final List<QueryDocumentSnapshot> results = [];
  for (var docSnap in inputDocs) {
    final data = docSnap.data() as Map<String, dynamic>;
    final bool ghost = data['isGhostMode'] == true;
    if (!ghost) {
      results.add(docSnap);
    } else {
      if (uid == null) continue;
      final memberDoc = await docSnap.reference.collection('members').doc(uid).get();
      if (memberDoc.exists) {
        results.add(docSnap);
      }
    }
  }
  return results;
}

//
// --- Main Page & Related Widgets ---
//

/// A page with 3 main tabs: Clubs, Interest Groups, Open Forums.
class AllOrganizationsPage extends StatefulWidget {
  const AllOrganizationsPage({Key? key}) : super(key: key);

  @override
  State<AllOrganizationsPage> createState() => _AllOrganizationsPageState();
}

class _AllOrganizationsPageState extends State<AllOrganizationsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String? userInstitution;
  bool isLoadingInstitution = true;
  String? institutionErrorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserInstitution();
  }

  /// Get the current user’s doc to determine their institution.
  Future<void> _fetchUserInstitution() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoadingInstitution = false;
        institutionErrorMessage = 'No logged-in user found.';
      });
      return;
    }
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        final institutionInDoc = data?['institution'] ?? '';
        final introVal = data?['introchallenge'] ?? 0;
        if (introVal == 1) {
          await docRef.update({'introchallenge': 2});
        }
        setState(() {
          userInstitution = institutionInDoc;
          isLoadingInstitution = false;
        });
      } else {
        setState(() {
          isLoadingInstitution = false;
          institutionErrorMessage = 'User profile not found in Firestore.';
        });
      }
    } catch (error) {
      setState(() {
        isLoadingInstitution = false;
        institutionErrorMessage = 'Error fetching user institution: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingInstitution) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (institutionErrorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: Center(child: Text(institutionErrorMessage!, style: const TextStyle(color: Colors.red))),
      );
    }
    final institutionName = (userInstitution != null && userInstitution!.isNotEmpty)
        ? userInstitution!
        : "ALL COMMUNITIES";

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                pinned: false,
                expandedHeight: 260.0,
                backgroundColor: Colors.transparent,
                elevation: 0,
                automaticallyImplyLeading: false,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                ),
                leading: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Container(
                    width: 45,
                    height: 45,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                      onPressed: () {
                        Navigator.pushNamed(context, '/find_community');
                      },
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  collapseMode: CollapseMode.parallax,
                  titlePadding: const EdgeInsets.only(bottom: 72, left: 16, right: 16),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/commons.png', height: 40),
                      const SizedBox(height: 16),
                      Text(
                        institutionName,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFB342),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.0),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60.0),
                  child: Container(
                    height: 48,
                    margin: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(15.0),
                      border: Border.all(color: Colors.white.withOpacity(0.8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => _searchQuery = value.toLowerCase());
                            },
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lovelo',
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Find your next hangout...',
                              hintStyle: TextStyle(color: Colors.white54, fontFamily: 'Lovelo'),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.white),
                          onPressed: () {
                            setState(() => _searchQuery = _searchController.text.toLowerCase());
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    isScrollable: true,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.white,
                    labelStyle: const TextStyle(
                      fontFamily: 'Lovelo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    tabs: const [
                      Tab(text: "Clubs"),
                      Tab(text: "Interest Groups"),
                      Tab(text: "Open Forums"),
                    ],
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              OrganizationGrid(
                collectionName: 'clubs',
                searchQuery: _searchQuery,
                onCardTapRoute: '/clubs-profile',
                userInstitution: userInstitution ?? '',
                circleCards: false,
                isClassGroups: false,
              ),
              InterestOrClassGroupsTab(
                userInstitution: userInstitution ?? '',
                searchQuery: _searchQuery,
              ),
              OrganizationGrid(
                collectionName: 'openForums',
                searchQuery: _searchQuery,
                onCardTapRoute: '/open-forums-profile',
                userInstitution: userInstitution ?? '',
                circleCards: true,
                isClassGroups: false,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.pushNamed(context, '/start-community');
          },
          backgroundColor: Colors.white,
          child: const Icon(Icons.add, color: Colors.black),
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  const _SliverAppBarDelegate(this._tabBar);
  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: _tabBar,
    );
  }
  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) => false;
}

class InterestOrClassGroupsTab extends StatefulWidget {
  final String userInstitution;
  final String searchQuery;
  const InterestOrClassGroupsTab({
    Key? key,
    required this.userInstitution,
    required this.searchQuery,
  }) : super(key: key);
  @override
  State<InterestOrClassGroupsTab> createState() => _InterestOrClassGroupsTabState();
}

class _InterestOrClassGroupsTabState extends State<InterestOrClassGroupsTab> {
  bool showClassGroups = false;
  @override
  Widget build(BuildContext context) {
    final currentCollection = showClassGroups ? 'classGroups' : 'interestGroups';
    final currentRoute = '/interest-groups-profile';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => setState(() => showClassGroups = false),
                child: Text(
                  'Interest Groups',
                  style: TextStyle(
                    fontFamily: 'Lovelo',
                    fontSize: 16,
                    fontWeight: showClassGroups ? FontWeight.normal : FontWeight.bold,
                    color: showClassGroups ? Colors.grey : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => showClassGroups = true),
                child: Text(
                  'Class Groups',
                  style: TextStyle(
                    fontFamily: 'Lovelo',
                    fontSize: 16,
                    fontWeight: showClassGroups ? FontWeight.bold : FontWeight.normal,
                    color: showClassGroups ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: OrganizationGrid(
            collectionName: currentCollection,
            searchQuery: widget.searchQuery,
            onCardTapRoute: currentRoute,
            userInstitution: widget.userInstitution,
            circleCards: false,
            isClassGroups: showClassGroups,
          ),
        ),
      ],
    );
  }
}

/// Displays a grid of organizations from Firestore.
/// Blocked communities (based on BlockedCommunities in the user doc)
/// are removed from the main view and shown in an expandable section.
class OrganizationGrid extends StatelessWidget {
  final String collectionName;
  final String searchQuery;
  final String onCardTapRoute;
  final String userInstitution;
  final bool circleCards;
  final bool isClassGroups;
  const OrganizationGrid({
    Key? key,
    required this.collectionName,
    required this.searchQuery,
    required this.onCardTapRoute,
    required this.userInstitution,
    required this.circleCards,
    this.isClassGroups = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Build the base query.
    Query collectionQuery = FirebaseFirestore.instance.collection(collectionName);
    if (userInstitution.isNotEmpty && userInstitution != 'ALL COMMUNITIES') {
      collectionQuery = collectionQuery.where('institution', isEqualTo: userInstitution);
    }
    if (isClassGroups) {
      collectionQuery = collectionQuery.where('expiresAt', isGreaterThan: Timestamp.now());
    }
    return StreamBuilder<QuerySnapshot>(
      stream: collectionQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }
        if (snapshot.hasError) {
          final errorMsg = snapshot.error.toString();
          if (errorMsg.contains('FAILED_PRECONDITION')) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'A Firestore index is required for this query.\n\n'
                'Please create a composite index for:\n'
                '   - institution\n'
                '   - expiresAt\n\n'
                'Then reload the page.',
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            );
          }
          return Center(
            child: Text(
              'Something went wrong:\n\n${snapshot.error}',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        // Filter by search.
        final bySearch = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final desc = (data['description'] ?? '').toString().toLowerCase();
          return name.contains(searchQuery) || desc.contains(searchQuery);
        }).toList();
        // Filter ghost docs.
        return FutureBuilder<List<QueryDocumentSnapshot>>(
          future: _filterGhostDocs(bySearch),
          builder: (ctx, filteredSnap) {
            if (filteredSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.white));
            }
            if (filteredSnap.hasError) {
              return Center(child: Text('Ghost filter error:\n\n${filteredSnap.error}', style: const TextStyle(color: Colors.red)));
            }
            final finalDocs = filteredSnap.data ?? [];
            if (finalDocs.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('No results found', style: TextStyle(color: Colors.grey))),
              );
            }
            // Fetch blocked community IDs.
            return FutureBuilder<List<String>>(
              future: _fetchBlockedCommunityIds(),
              builder: (context, blockedSnapshot) {
                if (blockedSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (blockedSnapshot.hasError) {
                  return Center(child: Text('Error: ${blockedSnapshot.error}', style: const TextStyle(color: Colors.red)));
                }
                final blockedIds = blockedSnapshot.data ?? [];
                final activeDocs = finalDocs.where((doc) => !blockedIds.contains(doc.id)).toList();
                final blockedDocs = finalDocs.where((doc) => blockedIds.contains(doc.id)).toList();

                // Build UI sections.
                Widget activeWidget;
                if (collectionName == 'clubs') {
                  activeWidget = SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: activeDocs.asMap().entries.map((entry) {
                        int index = entry.key;
                        final docSnap = entry.value;
                        final data = docSnap.data() as Map<String, dynamic>;
                        data['id'] = docSnap.id;
                        final pfpUrl = data['pfpUrl'] ?? '';
                        final orgName = data['name'] ?? 'No Name';
                        final description = data['description'] ?? 'No Description';
                        return TweenAnimationBuilder<double>(
                          key: ValueKey(docSnap.id),
                          duration: Duration(milliseconds: 300 + 50 * index),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOut,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 30 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: _buildClubCard(
                            context: context,
                            docId: docSnap.id,
                            data: data,
                            pfpUrl: pfpUrl,
                            name: orgName,
                            description: description,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                } else {
                  int crossAxisCount = 3;
                  double aspectRatio = circleCards ? 1 : 3 / 4;
                  activeWidget = SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        itemCount: activeDocs.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          mainAxisSpacing: 16.0,
                          crossAxisSpacing: 16.0,
                          childAspectRatio: aspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          final docSnap = activeDocs[index];
                          final data = docSnap.data() as Map<String, dynamic>;
                          data['id'] = docSnap.id;
                          final orgName = data['name'] ?? 'No Name';
                          final originalDesc = data['description'] ?? 'No Description';
                          String finalDescription = originalDesc;
                          if (isClassGroups) {
                            final lastName = data['profLastName'] ?? '';
                            final daysString = data['days'] ?? '';
                            finalDescription = '$lastName - $daysString';
                            if (!(data['backgroundColor']?.isNotEmpty ?? false)) {
                              final color = OrganizationGrid._generateAllowedRandomColor();
                              final colorHex = OrganizationGrid._colorToFirestoreHex(color);
                              data['backgroundColor'] = colorHex;
                              docSnap.reference.update({'backgroundColor': colorHex});
                            }
                          }
                          final pfpUrl = data['pfpUrl'] ?? '';
                          final pfpType = data['pfpType'] ?? '';
                          final pfpText = data['pfpText'] ?? '';
                          final bgColorHex = data['backgroundColor'] ?? '';
                          return TweenAnimationBuilder<double>(
                            key: ValueKey(docSnap.id),
                            duration: Duration(milliseconds: 300 + 50 * index),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, 30 * (1 - value)),
                                  child: child,
                                ),
                              );
                            },
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  onCardTapRoute,
                                  arguments: {
                                    'communityId': docSnap.id,
                                    'communityData': data,
                                    'userId': FirebaseAuth.instance.currentUser?.uid ?? 'noUser',
                                    'collectionName': collectionName,
                                  },
                                );
                              },
                              child: OrganizationCard(
                                communityId: docSnap.id,
                                name: orgName,
                                description: finalDescription,
                                pfpUrl: pfpUrl,
                                circleCards: circleCards,
                                pfpType: pfpType,
                                pfpText: pfpText,
                                backgroundColorHex: bgColorHex,
                                isClassGroups: isClassGroups,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }

                return ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    activeWidget,
                    if (blockedDocs.isNotEmpty)
                      ExpansionTile(
                        collapsedIconColor: Colors.white70,
                        iconColor: Colors.white70,
                        title: const Text(
                          "Blocked Communities",
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        children: blockedDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          data['id'] = doc.id;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: OrganizationCard(
                              communityId: doc.id,
                              name: data['name'] ?? 'No Name',
                              description: data['description'] ?? '',
                              pfpUrl: data['pfpUrl'] ?? '',
                              circleCards: circleCards,
                              pfpType: data['pfpType'] ?? '',
                              pfpText: data['pfpText'] ?? '',
                              backgroundColorHex: data['backgroundColor'] ?? '',
                              isClassGroups: isClassGroups,
                              isBlocked: true,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  static Color _generateAllowedRandomColor() {
    const maxTries = 50;
    for (int i = 0; i < maxTries; i++) {
      final int randomColorValue = (Random().nextDouble() * 0xFFFFFF).toInt();
      final color = Color(0xFF000000 | randomColorValue);
      if (!_isDisallowedColor(color)) {
        return color;
      }
    }
    return Colors.blue;
  }

  static String _colorToFirestoreHex(Color color) {
    final int argb = color.value;
    final hex = argb.toRadixString(16).toUpperCase().padLeft(8, '0');
    return '0x$hex';
  }

  static bool _isDisallowedColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    final h = hsl.hue;
    final s = hsl.saturation;
    final l = hsl.lightness;
    if (l > 0.9) return true;
    if (s < 0.1) return true;
    if (h >= 50 && h <= 70 && s > 0.5 && l > 0.4) return true;
    return false;
  }

  Widget _buildClubCard({
    required BuildContext context,
    required String docId,
    required Map<String, dynamic> data,
    required String pfpUrl,
    required String name,
    required String description,
  }) {
    return GestureDetector(
      onLongPress: () => _showCommunityActions(context, docId, 'clubs'),
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/clubs-profile',
                arguments: {
                  'communityId': docId,
                  'communityData': data,
                  'userId': FirebaseAuth.instance.currentUser?.uid ?? 'noUser',
                  'collectionName': 'clubs',
                },
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: pfpUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: pfpUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey.shade900,
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey.shade900,
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.white54,
                                  size: 48,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey.shade900,
                              child: const Icon(
                                Icons.image,
                                color: Colors.white54,
                                size: 48,
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Lovelo',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
              onPressed: () => _showCommunityActions(context, docId, 'clubs'),
            ),
          ),
        ],
      ),
    );
  }
}

/// A community card that can be rectangular or circular and now includes
/// report/block actions on long press or via a “...” overlay.
/// When [isBlocked] is true, an “Unblock” button is shown instead.
class OrganizationCard extends StatelessWidget {
  final String communityId;
  final String name;
  final String description;
  final String pfpUrl;
  final bool circleCards;
  final String pfpType;
  final String pfpText;
  final String backgroundColorHex;
  final bool isClassGroups;
  final bool isBlocked;

  const OrganizationCard({
    Key? key,
    required this.communityId,
    required this.name,
    required this.description,
    required this.pfpUrl,
    required this.circleCards,
    required this.pfpType,
    required this.pfpText,
    required this.backgroundColorHex,
    required this.isClassGroups,
    this.isBlocked = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cardContent = GestureDetector(
      onLongPress: () {
        if (!isBlocked) {
          _showCommunityActions(context, communityId, 'organizations');
        }
      },
      child: Stack(
        children: [
          circleCards
              ? _buildCircleCard(pfpType == 'textAvatar' && pfpText.isNotEmpty)
              : _buildRectangularCard(pfpType == 'textAvatar' && pfpText.isNotEmpty),
          Positioned(
            top: 4,
            right: 4,
            child: isBlocked
                ? TextButton(
                    onPressed: () => _unblockCommunity(context, communityId),
                    child: const Text(
                      'Unblock',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                    onPressed: () => _showCommunityActions(context, communityId, 'organizations'),
                  ),
          ),
        ],
      ),
    );

    return isBlocked
        ? Opacity(opacity: 0.6, child: cardContent)
        : cardContent;
  }

  Widget _buildCircleCard(bool isTextAvatar) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            if (!isTextAvatar) ...[
              Positioned.fill(child: _buildImageOrPlaceholder()),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.black26],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Positioned.fill(child: _buildTextAvatar(isCircle: true)),
            ],
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8.0),
                color: Colors.black54,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lovelo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRectangularCard(bool isTextAvatar) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            if (!isTextAvatar) ...[
              Positioned.fill(child: _buildImageOrPlaceholder()),
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black87, Colors.black38, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            ] else ...[
              Positioned.fill(child: _buildTextAvatar(isCircle: false)),
            ],
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: circleCards ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Lovelo',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOrPlaceholder() {
    if (pfpUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: pfpUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade900,
          child: const Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade900,
          child: const Icon(Icons.broken_image, color: Colors.white54, size: 48),
        ),
      );
    } else {
      return Container(
        color: Colors.grey.shade900,
        child: const Icon(Icons.image, color: Colors.white54, size: 48),
      );
    }
  }

  Widget _buildTextAvatar({required bool isCircle}) {
    Color parsedColor = Colors.grey.shade700;
    try {
      if (backgroundColorHex.startsWith('0x')) {
        final colorValue = int.parse(backgroundColorHex);
        parsedColor = Color(colorValue);
      }
    } catch (_) {
      parsedColor = Colors.grey.shade700;
    }
    return Container(
      decoration: BoxDecoration(
        color: parsedColor,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: Center(
        child: Text(
          pfpText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Lovelo',
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}
