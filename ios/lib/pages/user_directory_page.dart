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
  Future<List<Map<String, dynamic>>>? _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = _fetchUsers();
  }

  Future<List<Map<String, dynamic>>> _fetchUsers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('institution', isEqualTo: widget.institution)
        .get();

    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'noUser';

    return snapshot.docs
        .where((doc) => doc.id != currentUserId)
        .map((doc) {
          final data = doc.data();
          data['uid'] = doc.id;
          return data;
        })
        .toList();
  }

  /// Actually writes a "report" to Firestore.
  /// Customize the fields, location, or logic as you prefer.
  Future<void> _reportUser(String reportedUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'reporterUid': currentUser.uid,
        'reportedUserUid': reportedUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // e.g. "pending", "resolved"
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User has been reported.'),
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

  /// Shows a confirmation dialog to report a user.
  void _showReportDialog(String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text(
          'Report User',
          style: TextStyle(color: Colors.white70),
        ),
        content: const Text(
          'Are you sure you want to report this user for inappropriate behavior?',
          style: TextStyle(color: Colors.white60),
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
              Navigator.of(ctx).pop(); // close the dialog
              _reportUser(userId);
            },
            child: const Text(
              'Report',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ========== TOP BAR WITH BACK BUTTON & TITLE & WHITE CHAT ICON ==========
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
                // The new chat icon: White with that same red (#F10048) glow
                GestureDetector(
                  onTap: () {
                    // TODO: Add your desired chat-navigation logic here
                    debugPrint("Chat icon tapped!");
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    // A Stack for the icon + glow
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

            // ========== MAIN BODY: LIST OF BIG USER CARDS ==========
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _usersFuture,
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

                  final users = snapshot.data!;
                  // Filter by search query
                  final filtered = users.where((u) {
                    final fn = (u['fullName'] ?? '').toString().toLowerCase();
                    final un = (u['username'] ?? '').toString().toLowerCase();
                    return fn.contains(_searchQuery) || un.contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        "No matching users found.",
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                    itemBuilder: (ctx, index) {
                      final data = filtered[index];
                      final fullName = data['fullName'] ?? 'No Name';
                      final username = data['username'] ?? 'no_username';
                      final rawGradYear = data['graduationYear'];
                      final gradYear = rawGradYear != null
                          ? rawGradYear.toString()
                          : '????';
                      final photoUrl = data['photoUrl'] ?? '';
                      final uid = data['uid'] ?? '';

                      // Collect user badges (if present)
                      final badgeList = (data['badges'] as List<dynamic>? ?? [])
                          .map((b) => b.toString())
                          .toList();

                      return _buildBigUserCard(
                        context: context,
                        fullName: fullName,
                        username: username,
                        photoUrl: photoUrl,
                        gradYear: gradYear,
                        userId: uid,
                        badges: badgeList,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== BIG USER CARD WIDGET ==========
  Widget _buildBigUserCard({
    required BuildContext context,
    required String fullName,
    required String username,
    required String photoUrl,
    required String gradYear,
    required String userId,
    required List<String> badges,
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
          color: Colors.white.withOpacity(0.07), // Slightly lighter black
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1) Top header image (aspect ratio 16:9)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
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

                // 2) Bottom info area
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

                      // Row: Class bubble + badges
                      Row(
                        children: [
                          // Class of ____ bubble
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
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: badges
                                      .map((b) => _buildSmallBadgeIcon(b))
                                      .toList(growable: false),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // “More” button (3-dots) in top-right corner => Bottom sheet => 'Report'
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
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
                                Navigator.of(ctx).pop(); // close bottom sheet
                                _showReportDialog(userId);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds each small badge icon (24x24) with a subtle glow or style if needed.
  Widget _buildSmallBadgeIcon(String badgeStr) {
    // Map badge key -> asset path. Adjust as needed.
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

    // Distinguish between creation badge (blue glow) and challenge badge (gold glow)
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
