import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';

/// Data holder for the *other* user (profile being viewed)
class _ProfileAndCommunities {
  final String fullName;
  final String username;
  final String photoUrl;
  final String institution;
  final int graduationYear;
  final String emoji1;
  final String emoji2;
  final bool privateCommunities;
  final List<QueryDocumentSnapshot> communityDocs;
  final bool isUserInQuietMode;

  _ProfileAndCommunities({
    required this.fullName,
    required this.username,
    required this.photoUrl,
    required this.institution,
    required this.graduationYear,
    required this.emoji1,
    required this.emoji2,
    required this.privateCommunities,
    required this.communityDocs,
    required this.isUserInQuietMode,
  });
}

/// Possible states for the invite button
enum InviteState { idle, loading, success }

class UneditableProfilePage extends StatefulWidget {
  final String userId; // The user we're viewing

  const UneditableProfilePage({Key? key, required this.userId})
      : super(key: key);

  @override
  State<UneditableProfilePage> createState() => _UneditableProfilePageState();
}

class _UneditableProfilePageState extends State<UneditableProfilePage>
    with TickerProviderStateMixin {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Future to fetch the *other* user + communities
  late Future<_ProfileAndCommunities> _profileAndCommsFuture;

  // We'll fetch the current user's doc to get the correct photoUrl for the footer
  String _myProfilePhotoUrl = '';

  // Searching in communities
  bool _searchActive = false;
  String _searchQuery = '';

  // Shimmer for “Campus Clout”
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // Whether we're in dark mode (you can toggle if you like)
  bool _isDarkMode = true;

  // State for our "Invite to Chat" button
  InviteState _inviteState = InviteState.idle;

  // The current chat doc ID if one exists
  String? _existingChatId;

  // Subscription to watch if the existing chat gets deleted
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _chatSubscription;

  @override
  void initState() {
    super.initState();

    // 1) Load the other user
    _profileAndCommsFuture = _fetchProfileAndCommunities(widget.userId);

    // 2) Load *our* doc photoUrl (for the footer)
    if (_currentUser != null) {
      _loadMyOwnPhotoUrl(_currentUser!.uid);
    }

    // 3) Check if there's an existing chat
    if (_currentUser != null) {
      _checkExistingChat(_currentUser!.uid, widget.userId);
    }

    // Setup shimmer for “Campus Clout”
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _shimmerController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _shimmerController.dispose();
    super.dispose();
  }

  /// Checks Firestore for an existing chat between currentUser & otherUser.
  /// If found, we set the state to success + start listening for potential deletion.
  Future<void> _checkExistingChat(String currentUserId, String otherUserId) async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      String existingId = '';
      for (var doc in query.docs) {
        final participants = doc.data()['participants'] as List<dynamic>?;
        if (participants != null &&
            participants.contains(currentUserId) &&
            participants.contains(otherUserId)) {
          existingId = doc.id;
          break;
        }
      }

      if (existingId.isNotEmpty) {
        setState(() {
          _existingChatId = existingId;
          _inviteState = InviteState.success;
        });
        _listenForChatDeletion(existingId);
      } else {
        setState(() {
          _existingChatId = null;
          _inviteState = InviteState.idle;
        });
      }
    } catch (e) {
      setState(() => _inviteState = InviteState.idle);
    }
  }

  /// Subscribes to changes on the found chat doc, if it stops existing -> revert to idle
  void _listenForChatDeletion(String chatDocId) {
    _chatSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatDocId)
        .snapshots()
        .listen((docSnap) {
      if (!docSnap.exists) {
        setState(() {
          _existingChatId = null;
          _inviteState = InviteState.idle;
        });
      }
    }, onError: (err) {
      setState(() => _inviteState = InviteState.idle);
    });
  }

  Future<void> _loadMyOwnPhotoUrl(String uid) async {
    try {
      final docSnap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!docSnap.exists) return;
      final data = docSnap.data() ?? {};
      setState(() {
        _myProfilePhotoUrl = data['photoUrl'] ?? '';
      });
    } catch (e) {
      // handle or log error if needed
    }
  }

  /// Toggle dark mode
  void _toggleDarkMode() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  /// For text color in various spots
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black;
  Color get _subTextColor => _isDarkMode ? Colors.white70 : Colors.black54;
  Color get _bgColor => _isDarkMode ? Colors.black : Colors.white;

  /// Fetch the target user doc + communities
  Future<_ProfileAndCommunities> _fetchProfileAndCommunities(
      String targetUserId) async {
    final docSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .get();
    if (!docSnap.exists) {
      throw Exception("User not found.");
    }
    final data = docSnap.data() ?? {};

    final fullName = data['fullName'] as String? ?? 'No Name';
    final username = data['username'] as String? ?? 'no_username';
    final photoUrl = data['photoUrl'] as String? ?? '';
    final institution = data['institution'] as String? ?? 'Unknown Institution';
    final graduationYear = data['graduationYear'] as int? ?? 2025;
    final emoji1 = data['emoji1'] as String? ?? '🎓';
    final emoji2 = data['emoji2'] as String? ?? '📚';
    final privateComms = data['privateCommunities'] == true;

    // Check if this user has "quiet" set
    final privacyVal = data['privacy'] as String? ?? '';
    final isInQuietMode = (privacyVal == 'quiet');

    // If not private, gather communities
    List<QueryDocumentSnapshot> combinedCommunityDocs = [];
    if (!privateComms) {
      final collections = [
        'clubs',
        'openForums',
        'interestGroups',
        'ragtagSparks'
      ];
      final futures = collections.map((coll) {
        return _fetchMembershipFromOneCollection(coll, targetUserId);
      }).toList();
      final results = await Future.wait(futures);
      final allDocs = results.expand((x) => x).toSet().toList();
      combinedCommunityDocs = allDocs;
    }

    return _ProfileAndCommunities(
      fullName: fullName,
      username: username,
      photoUrl: photoUrl,
      institution: institution,
      graduationYear: graduationYear,
      emoji1: emoji1,
      emoji2: emoji2,
      privateCommunities: privateComms,
      communityDocs: combinedCommunityDocs,
      isUserInQuietMode: isInQuietMode,
    );
  }

  Future<List<QueryDocumentSnapshot>> _fetchMembershipFromOneCollection(
      String coll, String userId) async {
    final collRef = FirebaseFirestore.instance.collection(coll);

    // A) array membership
    final arraySnap =
        await collRef.where('members', arrayContains: userId).get();

    // B) subcollection membership
    final allSnap = await collRef.get();
    final subcollectionDocs = <QueryDocumentSnapshot>[];
    for (final doc in allSnap.docs) {
      final memberDoc =
          await doc.reference.collection('members').doc(userId).get();
      if (memberDoc.exists) {
        subcollectionDocs.add(doc);
      }
    }

    final combinedSet = <QueryDocumentSnapshot>{};
    combinedSet.addAll(arraySnap.docs);
    combinedSet.addAll(subcollectionDocs);
    return combinedSet.toList();
  }

  // --------------------------------------------------
  // BUILD
  // --------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ProfileAndCommunities>(
      future: _profileAndCommsFuture,
      builder: (context, snapshot) {
        // 1) LOADING
        if (!snapshot.hasData && !snapshot.hasError) {
          return Scaffold(
            backgroundColor: _bgColor,
            body: Center(
              child: CircularProgressIndicator(
                color: _isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          );
        }

        // 2) ERROR
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: _bgColor,
            body: Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        // 3) DATA
        final profileData = snapshot.data!;
        return _buildProfileScaffold(profileData);
      },
    );
  }

  Widget _buildProfileScaffold(_ProfileAndCommunities data) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _bgColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,

        // The top-right floating action button for mode toggle
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color:
                  _isDarkMode ? Colors.black54 : Colors.white.withOpacity(0.8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                color: _isDarkMode ? Colors.white : Colors.black,
                size: 20,
              ),
              onPressed: _toggleDarkMode,
            ),
          ),
        ),

        // Here's our always-dark custom footer bar:
        bottomNavigationBar: _buildDarkFooter(),

        body: SafeArea(
          minimum: const EdgeInsets.only(top: 10),
          child: Stack(
            children: [
              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    // Top-left "back" circle
                    _buildTopLeftBar(),
                    const SizedBox(height: 20),

                    // Stats & PFP
                    _buildRowStatsAndPfp(data),
                    const SizedBox(height: 8),

                    // Full Name
                    Text(
                      data.fullName,
                      style: TextStyle(
                        color: _textColor,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Username
                    Text(
                      data.username,
                      style: TextStyle(color: _subTextColor, fontSize: 16),
                    ),
                    const SizedBox(height: 12),

                    // Institution & year
                    Text(
                      data.institution,
                      style: TextStyle(color: _subTextColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Class of ${data.graduationYear}',
                      style: TextStyle(color: _subTextColor),
                    ),
                    const SizedBox(height: 30),

                    // Invite to Chat (only if NOT the same user & not in quiet mode)
                    if (_currentUser != null &&
                        _currentUser!.uid != widget.userId &&
                        !data.isUserInQuietMode)
                      _buildInviteToChatButton(_currentUser!.uid, widget.userId),

                    const SizedBox(height: 30),

                    // Communities
                    if (data.privateCommunities)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          "Communities are private.",
                          style: TextStyle(color: _subTextColor),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(bottom: 80),
                        child: _buildCommunitiesSection(data.communityDocs),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------
  // Top-left back circle
  // --------------------------------------------------
  Widget _buildTopLeftBar() {
    return Row(
      children: [
        const SizedBox(width: 8),
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black12,
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: _isDarkMode ? Colors.white : Colors.black,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  // --------------------------------------------------
  // ROW: Stats + PFP + Clout
  // --------------------------------------------------
  Widget _buildRowStatsAndPfp(_ProfileAndCommunities data) {
    final totalComms = data.communityDocs.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem("Communities", "$totalComms"),
        _buildAvatarWithEmojis(data.photoUrl, data.emoji1, data.emoji2),
        _buildCloutBar("Campus Clout", totalComms),
      ],
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: _subTextColor, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildAvatarWithEmojis(String photoUrl, String emoji1, String emoji2) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFAF7B), Color(0xFFD76D77)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
        // Inside circle
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _bgColor,
          ),
          child: ClipOval(
            child: (photoUrl.isNotEmpty)
                ? Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade700,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.error,
                        color: _isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  )
                : Icon(
                    Icons.person,
                    color: _isDarkMode ? Colors.white : Colors.black,
                    size: 56,
                  ),
          ),
        ),
        // Left-floating emoji
        Positioned(
          top: -10,
          left: -10,
          child: Transform.scale(
            scale: 1.5,
            child: Transform.rotate(
              angle: -0.15,
              child: Text(emoji1, style: const TextStyle(fontSize: 28)),
            ),
          ),
        ),
        // Right-floating emoji
        Positioned(
          bottom: -10,
          right: -10,
          child: Transform.scale(
            scale: 1.5,
            child: Transform.rotate(
              angle: 0.15,
              child: Text(emoji2, style: const TextStyle(fontSize: 28)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCloutBar(String label, int totalCommunities) {
    const double barWidth = 80;
    const double barHeight = 10;

    double fillFraction;
    Widget fillWidget;

    if (totalCommunities >= 5) {
      fillFraction = 1.0;
      fillWidget = _buildShimmerGradientBar(barWidth, barHeight);
    } else if (totalCommunities >= 3) {
      fillFraction = 0.8;
      fillWidget = Container(
        width: barWidth * fillFraction,
        height: barHeight,
        decoration: BoxDecoration(
          color: Colors.greenAccent,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    } else if (totalCommunities >= 1) {
      fillFraction = 0.5;
      fillWidget = Container(
        width: barWidth * fillFraction,
        height: barHeight,
        decoration: BoxDecoration(
          color: Colors.orangeAccent,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    } else {
      fillFraction = 0.1;
      fillWidget = Container(
        width: barWidth * fillFraction,
        height: barHeight,
        decoration: BoxDecoration(
          color: Colors.white54,
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: _subTextColor, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Stack(
          children: [
            // Gray background
            Container(
              width: barWidth,
              height: barHeight,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            fillWidget,
          ],
        ),
      ],
    );
  }

  Widget _buildShimmerGradientBar(double width, double height) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final shimmerOffset = _shimmerAnimation.value * width;

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
                // Base gradient
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      colors: [Color(0xFFFFAF7B), Color(0xFFD76D77)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.srcATop,
                  child: Container(color: Colors.white),
                ),

                // Moving highlight
                Positioned(
                  left: shimmerOffset - (width / 2),
                  child: Container(
                    width: width / 2,
                    height: height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.0),
                          Colors.white.withOpacity(0.4),
                          Colors.white.withOpacity(0.0),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --------------------------------------------------
  // Invite to Chat Button
  // --------------------------------------------------
  Widget _buildInviteToChatButton(String currentUserId, String otherUserId) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () => _inviteToChat(currentUserId, otherUserId),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 28),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: Colors.greenAccent,
            width: 2,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, anim) => FadeTransition(
            opacity: anim,
            child: ScaleTransition(scale: anim, child: child),
          ),
          child: switch (_inviteState) {
            InviteState.loading => SizedBox(
                key: const ValueKey('loading'),
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.greenAccent,
                ),
              ),
            InviteState.success => Icon(
                key: const ValueKey('success'),
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 24,
              ),
            _ => Text(
                key: const ValueKey('idle'),
                "Start a Chat",
                style: TextStyle(
                  color: _textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(
                      color: Colors.greenAccent,
                      blurRadius: 2,
                      offset: Offset(0, 0),
                    ),
                  ],
                ),
              ),
          },
        ),
      ),
    );
  }

  Future<void> _inviteToChat(String currentUserId, String otherUserId) async {
    if (_inviteState == InviteState.success) {
      // Already good
      return;
    }

    setState(() => _inviteState = InviteState.loading);

    try {
      // 1) Check if chat doc already exists
      final query = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      String existingChatId = '';
      for (var doc in query.docs) {
        final participants = doc.data()['participants'] as List<dynamic>?;
        if (participants != null &&
            participants.contains(currentUserId) &&
            participants.contains(otherUserId)) {
          existingChatId = doc.id;
          break;
        }
      }

      // 2) If no chat, create new
      if (existingChatId.isEmpty) {
        final docRef = await FirebaseFirestore.instance.collection('chats').add({
          'participants': [currentUserId, otherUserId],
          'createdAt': DateTime.now().toIso8601String(),
        });
        existingChatId = docRef.id;
      }

      // Mark success
      setState(() {
        _inviteState = InviteState.success;
        _existingChatId = existingChatId; 
      });

      // Begin watching this chat in case it's deleted
      _chatSubscription?.cancel();
      _listenForChatDeletion(existingChatId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Chat Started!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _inviteState = InviteState.idle);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to invite: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --------------------------------------------------
  // COMMUNITIES
  // --------------------------------------------------
  Widget _buildCommunitiesSection(List<QueryDocumentSnapshot> communities) {
    if (communities.isEmpty) {
      return Text(
        "No communities to display.",
        style: TextStyle(color: _subTextColor),
      );
    }

    final filteredComms = communities.where((doc) {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      final name = (d['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        // Label + Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                "Communities",
                style: TextStyle(
                  fontSize: 24,
                  color: _textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: _searchActive ? 200 : 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    InkWell(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () {
                        setState(() {
                          if (!_searchActive) _searchActive = true;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(
                          Icons.search,
                          color: _subTextColor,
                        ),
                      ),
                    ),
                    if (_searchActive)
                      Expanded(
                        child: TextField(
                          onChanged: (value) {
                            setState(() => _searchQuery = value.trim());
                          },
                          style: TextStyle(
                            color: _textColor,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: "Search...",
                            hintStyle:
                                TextStyle(color: _subTextColor.withOpacity(0.6)),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.only(left: 4),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _searchQuery = '';
                                  _searchActive = false;
                                });
                              },
                              child: Icon(
                                Icons.close,
                                size: 18,
                                color: _subTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        if (filteredComms.isEmpty)
          SizedBox(
            height: 120,
            child: Center(
              child: Text(
                "No matching communities.",
                style: TextStyle(color: _subTextColor, fontSize: 16),
              ),
            ),
          )
        else
          SizedBox(
            height: 440,
            child: GridView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filteredComms.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final doc = filteredComms[index];
                final d = doc.data() as Map<String, dynamic>? ?? {};

                final name = d['name'] ?? 'Unnamed';
                final description = d['description'] ?? '';
                final imageUrl = d['pfpUrl'] ?? d['imageUrl'] ?? '';
                final type = d['type'] ?? 'Unknown';

                return _buildCommunityCard(
                  name: name,
                  description: description,
                  imageUrl: imageUrl,
                  type: type,
                  onTap: () => _goToCommunity(doc.id, d),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildCommunityCard({
    required String name,
    required String description,
    required String imageUrl,
    required String type,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          border: Border.all(color: _isDarkMode ? Colors.white : Colors.black87),
          borderRadius: BorderRadius.circular(18),
          color: _isDarkMode ? Colors.white10 : Colors.black12,
          boxShadow: [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              if (imageUrl.isNotEmpty)
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade800,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image,
                      color: _isDarkMode ? Colors.white : Colors.black54,
                    ),
                  ),
                )
              else
                Container(
                  color: Colors.grey.shade800,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.image,
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              // Dark gradient from bottom to top
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ),
              // White circle highlight top-left
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Info text
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            blurRadius: 4,
                            color: Colors.black45,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToCommunity(String docId, Map<String, dynamic> communityData) {
    Navigator.pushNamed(
      context,
      '/community_detail',
      arguments: {
        'communityId': docId,
        'communityData': communityData,
        'viewerId': _currentUser?.uid ?? '',
      },
    );
  }

  // --------------------------------------------------
  // DARK FOOTER (Always black background, white icons)
  // --------------------------------------------------
  Widget _buildDarkFooter() {
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
          color: Colors.black, // Always dark
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Admin
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/admin-dashboard');
                },
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),

            // FOMO Feed (Replacing "explore" icon with an image)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/fomo_feed'),
                child: Image.asset(
                  'assets/fomofeedlogo.png',
                  // if you prefer a black version, do: 'assets/fomofeedlogoblack.png'
                  height: 34,
                  // Since the background is black, the colored or white version stands out
                ),
              ),
            ),

            // Center ragtag icon
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/find-community');
              },
              child: Image.asset(
                'assets/ragtaglogo.png',
                height: 40,
              ),
            ),

            // plus icon => start community
            _buildFooterIcon(
              icon: Icons.add,
              onTap: () {
                Navigator.pushNamed(context, '/start-community');
              },
            ),

            // Shimmering user PFP
            _buildShimmeringUserPfp(_myProfilePhotoUrl),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(
          icon,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  Widget _buildShimmeringUserPfp(String photoUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/myProfile');
      },
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
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
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black,
              backgroundImage:
                  (photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
              child: (photoUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
