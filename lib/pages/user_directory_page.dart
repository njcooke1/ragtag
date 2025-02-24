import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'uneditable_profile_page.dart';

class UserDirectoryPage extends StatefulWidget {
  final String institution;
  const UserDirectoryPage({Key? key, required this.institution})
      : super(key: key);

  @override
  State<UserDirectoryPage> createState() => _UserDirectoryPageState();
}

class _UserDirectoryPageState extends State<UserDirectoryPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Two futures: one for active users and one for blocked users.
  Future<List<Map<String, dynamic>>>? _activeUsersFuture;
  Future<List<Map<String, dynamic>>>? _blockedUsersFuture;

  @override
  void initState() {
    super.initState();
    _refreshLists();
  }

  /// Refresh both active and blocked user lists.
  void _refreshLists() {
    setState(() {
      _activeUsersFuture = _fetchActiveUsers();
      _blockedUsersFuture = _fetchBlockedUsers();
    });
  }

  /// Fetch the current user’s blocked user IDs from Firestore.
  Future<List<String>> _fetchBlockedUserIds() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .get();
    final blockedList = userDoc.data()?['Blocked'] as List<dynamic>? ?? [];
    return blockedList.map((e) => e.toString()).toList();
  }

  /// Fetch active users (those not blocked and not the current user)
  Future<List<Map<String, dynamic>>> _fetchActiveUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    final blockedUserIds = await _fetchBlockedUserIds();
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('institution', isEqualTo: widget.institution)
        .get();

    return snapshot.docs
        .where((doc) => doc.id != currentUser.uid && !blockedUserIds.contains(doc.id))
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }

  /// Fetch blocked users’ details.
  Future<List<Map<String, dynamic>>> _fetchBlockedUsers() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return [];
    final blockedUserIds = await _fetchBlockedUserIds();
    if (blockedUserIds.isEmpty) return [];

    // Firestore allows up to 10 items in a whereIn.
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: blockedUserIds)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['uid'] = doc.id;
      return data;
    }).toList();
  }

  /// Writes a detailed "report" document to Firestore.
  Future<void> _reportUser(String reportedUserId, String reason, String description) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterUid': currentUser.uid,
        'reportedUserUid': reportedUserId,
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
        SnackBar(
          content: Text('Error reporting user: $e'),
        ),
      );
    }
  }

  /// Shows a detailed report dialog allowing the reporter to choose a reason,
  /// optionally provide additional details, and informing them of our investigation timeframe.
  void _showReportDialog(String userId) {
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
                'Report User',
                style: TextStyle(color: Colors.white70),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dropdown for selecting a reason.
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
                        'Fake Account',
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
                    // Optional additional details.
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
                    _reportUser(userId, selectedReason, _descriptionController.text);
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

  /// Block a user by adding their ID to the current user's "Blocked" field.
  Future<void> _blockUser(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'Blocked': FieldValue.arrayUnion([userId]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked.')),
      );
      _refreshLists();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking user: $e')),
      );
    }
  }

  /// Unblock a user by removing their ID from the current user's "Blocked" field.
  Future<void> _unblockUser(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'Blocked': FieldValue.arrayRemove([userId]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User unblocked.')),
      );
      _refreshLists();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error unblocking user: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ========== TOP BAR WITH BACK BUTTON, TITLE & CHAT ICON ==========
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: Colors.white,
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      "User Directory",
                      style: TextStyle(
                        fontFamily: 'Lovelo',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ),
                ),
                // Chat icon with red glow
                GestureDetector(
                  onTap: () {
                    // TODO: Add your desired chat-navigation logic here
                    debugPrint("Chat icon tapped!");
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF10048).withOpacity(0.9),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chat_bubble,
                          color: Colors.white,
                          size: 32,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ========== SEARCH BAR ==========
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: Colors.white54, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value.trim().toLowerCase());
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search by Name or Username...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ========== MAIN BODY: ACTIVE USERS & BLOCKED SECTION ==========
            Expanded(
              child: FutureBuilder<List<List<Map<String, dynamic>>>>(
                // Combine both futures into one Future.
                future: Future.wait([
                  _activeUsersFuture ?? Future.value([]),
                  _blockedUsersFuture ?? Future.value([]),
                ]),
                builder: (context, snapshot) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.pinkAccent),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  // snapshot.data![0] = active users, snapshot.data![1] = blocked users
                  final activeUsers = snapshot.data![0];
                  final blockedUsers = snapshot.data![1];

                  // Apply search filter on active users.
                  final filteredActive = activeUsers.where((u) {
                    final fn = (u['fullName'] ?? '').toString().toLowerCase();
                    final un = (u['username'] ?? '').toString().toLowerCase();
                    return fn.contains(_searchQuery) || un.contains(_searchQuery);
                  }).toList();

                  // Build list children: active users first.
                  List<Widget> listChildren = [];

                  if (filteredActive.isEmpty) {
                    listChildren.add(
                      const Center(
                        child: Text(
                          "No matching users found.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    );
                  } else {
                    listChildren.addAll(
                      filteredActive.map((data) {
                        final fullName = data['fullName'] ?? 'No Name';
                        final username = data['username'] ?? 'no_username';
                        final rawGradYear = data['graduationYear'];
                        final gradYear = rawGradYear != null
                            ? rawGradYear.toString()
                            : '????';
                        final photoUrl = data['photoUrl'] ?? '';
                        final uid = data['uid'] ?? '';
                        final badgeList = (data['badges'] as List<dynamic>? ?? [])
                            .map((b) => b.toString())
                            .toList();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildUserCard(
                            context: context,
                            fullName: fullName,
                            username: username,
                            photoUrl: photoUrl,
                            gradYear: gradYear,
                            userId: uid,
                            badges: badgeList,
                            isBlocked: false,
                          ),
                        );
                      }).toList(),
                    );
                  }

                  // If there are blocked users, add an ExpansionTile section.
                  if (blockedUsers.isNotEmpty) {
                    listChildren.add(
                      ExpansionTile(
                        collapsedIconColor: Colors.white70,
                        iconColor: Colors.white70,
                        title: const Text(
                          "Blocked",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        children: blockedUsers.map((data) {
                          final fullName = data['fullName'] ?? 'No Name';
                          final username = data['username'] ?? 'no_username';
                          final rawGradYear = data['graduationYear'];
                          final gradYear = rawGradYear != null
                              ? rawGradYear.toString()
                              : '????';
                          final photoUrl = data['photoUrl'] ?? '';
                          final uid = data['uid'] ?? '';
                          final badgeList = (data['badges'] as List<dynamic>? ?? [])
                              .map((b) => b.toString())
                              .toList();

                          return Opacity(
                            opacity: 0.6,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                  left: 16, right: 16, bottom: 16),
                              child: _buildUserCard(
                                context: context,
                                fullName: fullName,
                                username: username,
                                photoUrl: photoUrl,
                                gradYear: gradYear,
                                userId: uid,
                                badges: badgeList,
                                isBlocked: true,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    physics: const BouncingScrollPhysics(),
                    children: listChildren,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a user card widget.
  /// The [isBlocked] flag determines whether the card is shown in the active list (false)
  /// or in the blocked section (true), and adapts the action button accordingly.
  Widget _buildUserCard({
    required BuildContext context,
    required String fullName,
    required String username,
    required String photoUrl,
    required String gradYear,
    required String userId,
    required List<String> badges,
    bool isBlocked = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UneditableProfilePage(userId: userId),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white24,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top header image (16:9 aspect ratio)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: photoUrl.isNotEmpty
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade800,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white54,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (ctx, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade800,
                            child: const Icon(
                              Icons.broken_image,
                              color: Colors.white54,
                              size: 40,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade800,
                        child: const Icon(
                          Icons.person,
                          color: Colors.white54,
                          size: 50,
                        ),
                      ),
              ),
            ),
            // Bottom info area with name, username, class badge, badges and action button.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Full Name
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Username
                  Text(
                    username,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Row with class bubble, badges and action button.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          // Class bubble
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFFAF7B),
                                  Color(0xFFD76D77),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Class of $gradYear',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Badges row (if any)
                          if (badges.isNotEmpty)
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: badges
                                    .map((b) => _buildSmallBadgeIcon(b))
                                    .toList(growable: false),
                              ),
                            ),
                        ],
                      ),
                      // Action button: if blocked, show an "Unblock" button; otherwise, show the three-dots.
                      isBlocked
                          ? TextButton(
                              onPressed: () {
                                _unblockUser(userId);
                              },
                              child: const Text(
                                'Unblock',
                                style: TextStyle(color: Colors.redAccent),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white70),
                              onPressed: () {
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
                                              'Report User',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            onTap: () {
                                              Navigator.of(ctx).pop();
                                              _showReportDialog(userId);
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(Icons.block, color: Colors.orangeAccent),
                                            title: const Text(
                                              'Block User',
                                              style: TextStyle(color: Colors.white70),
                                            ),
                                            onTap: () {
                                              Navigator.of(ctx).pop();
                                              _blockUser(userId);
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a small badge icon (24x24) with a subtle glow.
  Widget _buildSmallBadgeIcon(String badgeStr) {
    bool isCreationBadge = false;
    bool isChallengeBadge = false;

    if (badgeStr == 'introbadge') {
      badgeStr = 'assets/newmemberbadge.png';
    } else if (badgeStr == 'creationbadge') {
      badgeStr = 'assets/creationbadge.png';
      isCreationBadge = true;
    } else if (badgeStr == 'dayonebadge') {
      badgeStr = 'assets/dayonebadge.png';
    } else if (badgeStr == 'challengebadge') {
      badgeStr = 'assets/challengebadge.png';
      isChallengeBadge = true;
    }

    final isAsset = badgeStr.startsWith('assets/');
    final imageProvider =
        isAsset ? AssetImage(badgeStr) as ImageProvider : NetworkImage(badgeStr);

    final glowColor = isChallengeBadge
        ? Colors.amber
        : (isCreationBadge ? Colors.blueAccent : Colors.orangeAccent);

    return Container(
      width: 28,
      height: 28,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.transparent,
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
