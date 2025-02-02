import 'dart:math' as math; // for pi
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';

// Make sure this import points to where your FindCommunityPage is located:
// import 'package:ragtagrevived/pages/find_community_page.dart';  
import 'package:ragtagrevived/pages/find_community.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({Key? key}) : super(key: key);

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  final User? user = FirebaseAuth.instance.currentUser;
  late Future<List<QueryDocumentSnapshot>> _allCommunitiesFuture;

  /// For the search
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  /// Toggle for dark mode
  bool isDarkMode = true;

  /// We'll store the user's pfp URL here
  String? userPfpUrl;

  /// Track if we have shown the creation badge dialog once
  bool _hasShownCreationBadgeDialog = false;

  // Animation controller for the “breathing” effect on the creation badge
  late AnimationController _badgeAnimController;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotationAnim;

  /// Track press state for center Ragtag logo
  bool _centerIconPressed = false;

  @override
  void initState() {
    super.initState();
    _allCommunitiesFuture = _fetchAllAdminCommunities();
    _fetchUserPfpUrl();

    // Set up the subtle badge animation
    _badgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _badgeAnimController, curve: Curves.easeInOut),
    );
    _rotationAnim = Tween<double>(begin: -0.015, end: 0.015).animate(
      CurvedAnimation(parent: _badgeAnimController, curve: Curves.easeInOut),
    );

    // Make the animation continuously “breathe”
    _badgeAnimController.forward().then((_) => _badgeAnimController.reverse());
    _badgeAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _badgeAnimController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _badgeAnimController.forward();
      }
    });
  }

  @override
  void dispose() {
    _badgeAnimController.dispose();
    super.dispose();
  }

  /// Grab all admin communities from your collections
  Future<List<QueryDocumentSnapshot>> _fetchAllAdminCommunities() async {
    final userId = user?.uid;
    if (userId == null) return [];

    final collections = [
      'clubs',
      'openForums',
      'interestGroups',
      'ragtagSparks',
    ];

    final queries = collections.map((col) {
      return FirebaseFirestore.instance
          .collection(col)
          .where('admins', arrayContains: userId)
          .get();
    }).toList();

    final results = await Future.wait(queries);
    return results.expand((snapshot) => snapshot.docs).toList();
  }

  /// Minimal function to fetch current user's pfp from Firestore
  Future<void> _fetchUserPfpUrl() async {
    final uid = user?.uid;
    if (uid == null) return;
    try {
      final docSnap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null) {
          setState(() {
            userPfpUrl = data['photoUrl'] ?? '';
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching user pfpUrl: $e");
    }
  }

  /// Checks if the user is a first-time admin: if they have at least 1 doc
  /// in the list of admin communities AND do not already have "creationbadge".
  /// If so, show the awarding dialog.
  Future<void> _checkForFirstTimeAdmin(
      List<QueryDocumentSnapshot> communityDocs) async {
    // If user is admin of at least 1 community
    if (communityDocs.isNotEmpty && !_hasShownCreationBadgeDialog) {
      try {
        final uid = user?.uid;
        if (uid == null) return;

        final userDocRef =
            FirebaseFirestore.instance.collection('users').doc(uid);
        final userDoc = await userDocRef.get();
        if (userDoc.exists) {
          final data = userDoc.data();
          final badges = data?['badges'] as List<dynamic>? ?? [];
          // If they do NOT have creationbadge yet
          if (!badges.contains('creationbadge')) {
            // Show the awarding dialog
            _hasShownCreationBadgeDialog = true; // so we don’t show repeatedly
            _showCreationBadgeDialog();
          }
        }
      } catch (e) {
        debugPrint("Error checking for creation badge: $e");
      }
    }
  }

  /// Show the awarding dialog for creationbadge
  void _showCreationBadgeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true, // tap outside to close
      builder: (BuildContext context) {
        return Center(
          child: Material(
            color: Colors.black54,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 40,
                    spreadRadius: 10,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stack for layered glow & shimmer behind the badge
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Big radial glow
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.amberAccent.withOpacity(0.5),
                              Colors.transparent,
                            ],
                            radius: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellowAccent.withOpacity(0.4),
                              blurRadius: 70,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      // Subtle shimmer circle behind the badge
                      Shimmer.fromColors(
                        baseColor: Colors.yellowAccent.withOpacity(0.2),
                        highlightColor: Colors.white.withOpacity(0.1),
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: const BoxDecoration(
                            color: Colors.amberAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                      // Actual animated badge (creationbadge.png)
                      AnimatedBuilder(
                        animation: _badgeAnimController,
                        builder: (ctx, child) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..scale(_scaleAnim.value, _scaleAnim.value)
                              ..rotateZ(_rotationAnim.value),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/creationbadge.png', // <-- your creation badge
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Big header text in Lovelo
                  Text(
                    "CONGRATS, ADMIN!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lovelo',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Body text
                  const Text(
                    "You just created or now lead your first community. "
                    "A brand new badge has been added to your profile.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black87,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                      elevation: 2,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _awardCreationBadge();
                    },
                    child: const Text("Awesome!"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Actually write "creationbadge" into Firestore
  Future<void> _awardCreationBadge() async {
    try {
      final uid = user?.uid;
      if (uid == null) return;
      final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

      await docRef.set({
        'badges': FieldValue.arrayUnion(['creationbadge']),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error awarding creation badge: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.black54 : Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: Icon(
                isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () {
                setState(() {
                  isDarkMode = !isDarkMode;
                });
              },
            ),
          ),
        ),
        bottomNavigationBar: _buildFooter(context),
        body: SafeArea(
          child: FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _allCommunitiesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Error: ${snapshot.error}",
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                  ),
                );
              }

              final communityDocs = snapshot.data ?? [];

              // Right after we get data, check for first-time admin
              _checkForFirstTimeAdmin(communityDocs);

              if (communityDocs.isEmpty) {
                return Center(
                  child: Text(
                    "You're not an admin of any communities yet.",
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      fontSize: 18,
                    ),
                  ),
                );
              }

              // Filter results based on search
              final filteredCommunities = communityDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = (data['name'] ?? '').toString().toLowerCase();
                final desc =
                    (data['description'] ?? '').toString().toLowerCase();
                final query = _searchText.toLowerCase();
                return name.contains(query) || desc.contains(query);
              }).toList();

              return Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 10),
                  _buildHeader(),
                  const SizedBox(height: 4),
                  _buildSubHeader(),
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filteredCommunities.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final doc = filteredCommunities[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final docId = doc.id;
                        final name = data['name'] ?? 'Unnamed';
                        final description =
                            data['description'] ?? 'No description.';
                        final imageUrl =
                            data['pfpUrl'] ?? data['imageUrl'] ?? '';
                        final communityType = data['type'] ?? 'Unknown';

                        return _buildBigCommunityCard(
                          context: context,
                          docId: docId,
                          name: name,
                          description: description,
                          imageUrl: imageUrl,
                          communityType: communityType,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  ///
  /// Top bar with "back" button
  ///
  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  ///
  /// Admin Dashboard Header / Subheader
  ///
  Widget _buildHeader() {
    return Text(
      "Admin Dashboard",
      style: TextStyle(
        fontFamily: 'Lovelo',
        fontWeight: FontWeight.w600,
        fontSize: 24,
        color: isDarkMode ? Colors.white : Colors.black,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubHeader() {
    return Text(
      "Manage communities like a pro",
      style: TextStyle(
        color: isDarkMode ? Colors.white70 : Colors.black54,
        fontSize: 14,
      ),
      textAlign: TextAlign.center,
    );
  }

  ///
  /// Modern search bar
  ///
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.black12,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search,
                color: isDarkMode ? Colors.white54 : Colors.black54, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
                onChanged: (value) {
                  setState(() => _searchText = value);
                },
                decoration: InputDecoration(
                  hintText: 'Search communities...',
                  hintStyle: TextStyle(
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }

  ///
  /// Big card: pfp on top, info & edit below
  ///
  Widget _buildBigCommunityCard({
    required BuildContext context,
    required String docId,
    required String name,
    required String description,
    required String imageUrl,
    required String communityType,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/edit_community',
          arguments: {
            'id': docId,
            'name': name,
            'description': description,
            'imageUrl': imageUrl,
            'type': communityType,
          },
        );
      },
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white24,
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withOpacity(0.06)
              : Colors.black.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Community image on top
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: (imageUrl.isNotEmpty)
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey.shade900,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white54,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (ctx, error, stackTrace) {
                          return Container(
                            color: Colors.grey.shade900,
                            child: Icon(
                              Icons.broken_image,
                              color: isDarkMode ? Colors.white54 : Colors.black54,
                              size: 40,
                            ),
                          );
                        },
                      )
                    : Container(
                        color: Colors.grey.shade900,
                        child: Icon(
                          Icons.photo_camera_back,
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                          size: 40,
                        ),
                      ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // Centered hollow circle icon at bottom
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      width: 1.4,
                    ),
                  ),
                  child: Icon(
                    Icons.edit,
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.9)
                        : Colors.black.withOpacity(0.9),
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ///
  /// Bottom icon bar with the new FOMO Feed logo
  ///
  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 30),
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
        borderRadius: BorderRadius.circular(30),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Far left icon => Admin Dashboard (untappable)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(
                Icons.admin_panel_settings,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 40,
              ),
            ),

            // Explore => replaced with FOMO Feed logo @ height 34
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/fomo_feed'),
                child: Image.asset(
                  isDarkMode
                      ? 'assets/fomofeedlogo.png'
                      : 'assets/fomofeedlogoblack.png',
                  height: 34,
                ),
              ),
            ),

            // Center Ragtag Logo with tap animation,
            // now navigates to the FindCommunityPage.
            GestureDetector(
              onTapDown: (_) => setState(() => _centerIconPressed = true),
              onTapUp: (_) => setState(() => _centerIconPressed = false),
              onTapCancel: () => setState(() => _centerIconPressed = false),
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FindCommunityPage(),
                  ),
                );
              },
              child: AnimatedScale(
                scale: _centerIconPressed ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Image.asset(
                  isDarkMode
                      ? 'assets/ragtaglogo.png'
                      : 'assets/ragtaglogoblack.png',
                  height: 40,
                ),
              ),
            ),

            // Plus Icon
            _buildFooterIcon(
              Icons.add,
              color: isDarkMode ? Colors.white : Colors.black,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/start-community',
                  arguments: user?.uid,
                );
              },
            ),

            // REPLACED: Instead of the plain person icon, a shimmering ring pfp
            _buildShimmeringUserPfp(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterIcon(
    IconData icon, {
    required Color color,
    required Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  /// Build the shimmering ring for the user's photo
  Widget _buildShimmeringUserPfp() {
    return GestureDetector(
      onTap: () {
        // e.g. go to profile
        Navigator.pushNamed(context, '/profilePage');
      },
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The shimmering ring
            Shimmer.fromColors(
              baseColor: const Color(0xFFFFAF7B),
              highlightColor: const Color(0xFFD76D77),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),

            // The circle avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black,
              backgroundImage: (userPfpUrl != null && userPfpUrl!.isNotEmpty)
                  ? NetworkImage(userPfpUrl!)
                  : null,
              child: (userPfpUrl == null || userPfpUrl!.isEmpty)
                  ? const Icon(
                      Icons.person,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
