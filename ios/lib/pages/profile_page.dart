import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import 'opening_landing_page.dart';
import 'privacy_and_blocked_page.dart';
import 'likes_dislikes_page.dart';
import 'change_password_page.dart';
import 'chat_page.dart';
import 'user_directory_page.dart';
import 'find_community.dart';
// ADD THIS IMPORT IF YOU WANT THE "CONTACT US" PAGE:
import 'contact_us_page.dart';

/// Holds user data + user’s communities.
class _ProfileAndCommunities {
  final String fullName;
  final String username;
  final String photoUrl;
  final String institution;
  final int graduationYear;
  final String emoji1;
  final String emoji2;
  final List<QueryDocumentSnapshot> communityDocs;
  final List<String> badges;

  _ProfileAndCommunities({
    required this.fullName,
    required this.username,
    required this.photoUrl,
    required this.institution,
    required this.graduationYear,
    required this.emoji1,
    required this.emoji2,
    required this.communityDocs,
    required this.badges,
  });
}

/// Represents each conversation for the user
class ChatConversation {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  ChatConversation({
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
  });
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  bool _isDarkMode = true;
  bool _isLoadingPage = true;

  // We'll load everything in one combined future
  late Future<Map<String, dynamic>> _combinedFuture;

  // Toggling between “list” vs. “grid” for communities
  bool _isGridView = true;

  // Searching in communities
  bool _searchActive = false;
  String _searchQuery = '';

  // Edit entire profile fields at once
  bool _isEditingAll = false;

  // Controllers for editing
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _gradYearController = TextEditingController();

  // We remember the original username so we know when to check if it’s taken
  String _originalUsername = '';

  // Emojis
  final List<String> _availableEmojis = [
    '🎓','📚','✏️','📝','💻','🧮','⚗️','🔬','🔭','📐','📏','🏫',
    '🎨','🏆','🥇','🥈','🥉','🚀','🌏','📸','☕','🎧','👾','🤓'
  ];
  String _tempEmoji1 = '🎓';
  String _tempEmoji2 = '📚';
  int _selectedEmojiSlot = 1;

  // Loading animations (mimicking the opening landing page)
  late AnimationController _loadingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<Color?> _bgColor1Animation;
  late Animation<Color?> _bgColor2Animation;

  // Repeated “loading message”
  final List<String> _loadingMessages = [
    "Fetching Data…",
    "Making it look cool…",
    "Finalizing magic…",
  ];
  late Timer _loadingTimer;
  int _loadingMessageIndex = 0;

  // Track which chat is selected for possible deletion
  String? _selectedChatId;

  // Neon X animation
  late AnimationController _trashController;
  late Animation<double> _trashScale;
  late Animation<double> _trashRotation;

  // If we've shown dayone pop-up
  bool _hasShownDayOneBadgeDialog = false;

  // Colors
  Color get _bgColor => _isDarkMode ? Colors.black : Colors.white;
  Color get _textColor => _isDarkMode ? Colors.white : Colors.black87;
  Color get _subTextColor => _isDarkMode ? Colors.white70 : Colors.black54;
  Color get _searchBgColor =>
      _isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05);

  @override
  void initState() {
    super.initState();

    // System bars
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    // Loading animation controller (SAME intervals & curves as the opening page)
    _loadingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..forward();

    // Fade in from 0 to 1
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    // Scale from 0.8 to 1.0
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    // Shimmer sweep
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
      ),
    );
    // Slight rotation
    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );
    // Animated gradient background
    _bgColor1Animation = ColorTween(
      begin: const Color(0xFF000000),
      end: const Color(0xFFFFAF7B),
    ).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );
    _bgColor2Animation = ColorTween(
      begin: const Color(0xFF000000),
      end: const Color(0xFFD76D77),
    ).animate(
      CurvedAnimation(
        parent: _loadingController,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Loading text cycle
    _loadingTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      setState(() {
        _loadingMessageIndex =
            (_loadingMessageIndex + 1) % _loadingMessages.length;
      });
    });

    // Combine data
    _combinedFuture = _loadAllData();

    // Neon X (trash) animations
    _trashController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _trashScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _trashController, curve: Curves.elasticOut),
    );
    _trashRotation = Tween<double>(begin: 0.0, end: -0.2).animate(
      CurvedAnimation(parent: _trashController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _loadingTimer.cancel();
    _loadingController.dispose();
    _trashController.dispose();

    _nameController.dispose();
    _usernameController.dispose();
    _gradYearController.dispose();

    super.dispose();
  }

  /// Load profile + chats
  Future<Map<String, dynamic>> _loadAllData() async {
    final profile = await _fetchProfileAndCommunities();
    final chats = await _fetchUserChats();
    return {
      "profile": profile,
      "chats": chats,
    };
  }

  Future<_ProfileAndCommunities> _fetchProfileAndCommunities() async {
    final uid = _currentUser?.uid;
    if (uid == null) throw Exception("No user logged in!");
    final userDocSnap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDocSnap.data() ?? {};

    final fullName = data['fullName'] as String? ?? 'No Name';
    final username = data['username'] as String? ?? 'no_username';
    final photoUrl = data['photoUrl'] as String? ?? '';
    final institution = data['institution'] as String? ?? 'Unknown Institution';
    final graduationYear = data['graduationYear'] as int? ?? 2025;
    final emoji1 = data['emoji1'] as String? ?? '🎓';
    final emoji2 = data['emoji2'] as String? ?? '📚';

    final badges = (data['badges'] as List<dynamic>? ?? [])
        .map((b) => b.toString())
        .toList();

    // Prefill editing controllers
    _nameController.text = fullName;
    _usernameController.text = username;
    _gradYearController.text = graduationYear.toString();
    _tempEmoji1 = emoji1;
    _tempEmoji2 = emoji2;

    // Store the original username so we know if user changed it
    _originalUsername = username;

    // Gather communities
    final collections = ['clubs', 'openForums', 'interestGroups', 'ragtagSparks'];
    final futures =
        collections.map((c) => _fetchMembershipFromOneCollection(c, uid));
    final results = await Future.wait(futures);
    final allDocs = results.expand((x) => x).toSet().toList();

    return _ProfileAndCommunities(
      fullName: fullName,
      username: username,
      photoUrl: photoUrl,
      institution: institution,
      graduationYear: graduationYear,
      emoji1: emoji1,
      emoji2: emoji2,
      communityDocs: allDocs,
      badges: badges,
    );
  }

  Future<List<QueryDocumentSnapshot>> _fetchMembershipFromOneCollection(
    String coll,
    String uid,
  ) async {
    final collRef = FirebaseFirestore.instance.collection(coll);

    // membership array
    final arraySnap = await collRef.where('members', arrayContains: uid).get();
    final allSnap = await collRef.get();

    // membership subcollection
    final subcollectionDocs = <QueryDocumentSnapshot>[];
    for (final doc in allSnap.docs) {
      final memberDoc = await doc.reference.collection('members').doc(uid).get();
      if (memberDoc.exists) {
        subcollectionDocs.add(doc);
      }
    }

    final combinedSet = <QueryDocumentSnapshot>{};
    combinedSet.addAll(arraySnap.docs);
    combinedSet.addAll(subcollectionDocs);
    return combinedSet.toList();
  }

  Future<List<ChatConversation>> _fetchUserChats() async {
    if (_currentUser == null) return [];
    final uid = _currentUser!.uid;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('chats')
        .where('participants', arrayContains: uid)
        .get();

    List<ChatConversation> chats = [];
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final participants = data['participants'] as List<dynamic>? ?? [];
      String otherUserId = '';
      for (String p in participants.cast<String>()) {
        if (p != uid) {
          otherUserId = p;
          break;
        }
      }
      if (otherUserId.isNotEmpty) {
        final otherUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(otherUserId)
            .get();
        final otherUserData = otherUserDoc.data() ?? {};
        chats.add(ChatConversation(
          chatId: doc.id,
          otherUserId: otherUserId,
          otherUserName: otherUserData['username'] ?? 'UnknownUser',
          otherUserPhotoUrl: otherUserData['photoUrl'] ?? '',
        ));
      }
    }
    return chats;
  }

  // Toggle between “display” and “edit” profile
  void _toggleEditProfile() {
    setState(() {
      if (_isEditingAll) {
        // User clicked "Save Edits"
        _saveAllEdits();
      } else {
        // Enter editing mode
        _isEditingAll = true;
      }
    });
  }

  Future<void> _saveAllEdits() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    final newName = _nameController.text.trim().isEmpty
        ? 'No Name'
        : _nameController.text.trim();

    final newUsername = _usernameController.text.trim();

    // 1) Must start with '@'
    if (!newUsername.startsWith('@')) {
      _showSnack('Username must start with @');
      return;
    }

    // 2) Must not be just '@'
    if (newUsername.length <= 1) {
      _showSnack('Please enter a username after @');
      return;
    }

    // 3) If you want to ensure exactly one '@', check that too
    final countAt = '@'.allMatches(newUsername).length;
    if (countAt > 1) {
      _showSnack('Username can only contain one @');
      return;
    }

    final newGradYear = int.tryParse(_gradYearController.text) ?? 2025;

    // 1) If user changed username, check if it’s taken
    if (newUsername != _originalUsername) {
      // Query for an existing doc with same username
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: newUsername)
          .limit(1)
          .get();

      // If found a different doc with that username => bail out
      if (userQuery.docs.isNotEmpty && userQuery.docs.first.id != uid) {
        _showSnack('Sorry, that username is taken.');
        return;
      }
    }

    // 2) If not taken (or user didn’t change username), proceed
    await _updateUserData({
      'fullName': newName,
      'username': newUsername,
      'graduationYear': newGradYear,
      'emoji1': _tempEmoji1,
      'emoji2': _tempEmoji2,
    });

    // If user never did "introchallenge" step 1, mark it
    await _markIntroStep1IfAppropriate();

    // Update local references
    _originalUsername = newUsername;

    setState(() {
      _isEditingAll = false;
      _combinedFuture = _loadAllData();
    });
  }

  Future<void> _editPhoto() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;
    final imageFile = File(pickedFile.path);
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('profilePics')
        .child('${_currentUser!.uid}.png');

    await storageRef.putFile(imageFile);
    final downloadUrl = await storageRef.getDownloadURL();
    await _updateUserData({'photoUrl': downloadUrl});

    setState(() {
      _combinedFuture = _loadAllData();
    });
  }

  Future<void> _updateUserData(Map<String, dynamic> data) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update(data);
  }

  Future<void> _markIntroStep1IfAppropriate() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final data = snap.data() ?? {};
    final currentVal = data['introchallenge'] ?? 0;
    if (currentVal < 1) {
      await docRef.update({'introchallenge': 1});
    }
  }

  void _openSettings() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  void _toggleDarkMode() {
    setState(() => _isDarkMode = !_isDarkMode);
  }

  // Show day-one badge only once
  void _checkDayOneBadge(List<String> badges) {
    if (!badges.contains('dayonebadge') && !_hasShownDayOneBadgeDialog) {
      _hasShownDayOneBadgeDialog = true;
      _showDayOneBadgeDialog();
    }
  }

  void _showDayOneBadgeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
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
                  // radial glow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.orangeAccent.withOpacity(0.5),
                              Colors.transparent,
                            ],
                            radius: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orangeAccent.withOpacity(0.4),
                              blurRadius: 70,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      // The badge image
                      Image.asset(
                        'assets/dayonebadge.png',
                        height: 160,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "WELCOME ABOARD!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lovelo',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "We’re thrilled that you hopped in from Day One.\n"
                    "Enjoy this exclusive badge on your profile!",
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
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black87,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
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
                      _awardDayOneBadge();
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

  Future<void> _awardDayOneBadge() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await docRef.set({
      'badges': FieldValue.arrayUnion(['dayonebadge'])
    }, SetOptions(merge: true));
  }

  // Deletion method for chats
  Future<void> _deleteChat(String chatId) async {
    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .delete();

      setState(() {
        // Clear the selected chat so the X disappears
        _selectedChatId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting chat: $e')),
      );
    }
  }

  // A helper for quick SnackBars
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _combinedFuture,
      builder: (ctx, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          // LOADING
          _isLoadingPage = true;
          return _buildFancyLoading(); // Updated animation
        }
        if (snapshot.hasError) {
          // ERROR
          return Scaffold(
            backgroundColor: Colors.red,
            body: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Error: ${snapshot.error}\nStack: ${snapshot.stackTrace}",
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        _isLoadingPage = false;
        final profileData = snapshot.data!["profile"] as _ProfileAndCommunities;
        final chatData = snapshot.data!["chats"] as List<ChatConversation>;

        // Show day-one badge if needed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkDayOneBadge(profileData.badges);
        });

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: _bgColor,
          endDrawer: _buildMinimalSettingsDrawer(context),
          bottomNavigationBar:
              _isLoadingPage ? null : _buildFloatingFooter(context, profileData),

          // 1) Entire body in a GestureDetector to close neon X if tapped outside
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              // If a chat is selected & user taps anywhere else -> close the neon X
              if (_selectedChatId != null) {
                setState(() => _selectedChatId = null);
              }
            },
            child: SafeArea(
              child: Column(
                children: [
                  // Minimal row of icons at top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                        onPressed: _toggleDarkMode,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.settings,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                        onPressed: _openSettings,
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),

                  // The rest
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildTopProfileContainer(profileData),
                          const SizedBox(height: 20),
                          _buildPrivateMessagesSection(profileData, chatData),
                          _buildShadowDivider(),
                          const SizedBox(height: 20),
                          _buildCommunitiesLabelAndSearch(),
                          const SizedBox(height: 16),
                          _buildCommunitiesSection(profileData),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Minimal settings drawer
  Widget _buildMinimalSettingsDrawer(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.75,
      color: _isDarkMode ? Colors.black : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // top row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Row(
                children: [
                  Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 20,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: _isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildDrawerTile(
                    icon: Icons.lock_person_outlined,
                    title: "Privacy & Blocked",
                    onTap: () => _openPage(const PrivacyAndBlockedPage()),
                  ),
                  _buildDrawerTile(
                    icon: Icons.thumb_up_off_alt_outlined,
                    title: "Manage Likes/Dislikes",
                    onTap: () => _openPage(const LikesDislikesPage()),
                  ),
                  _buildDrawerTile(
                    icon: Icons.password_outlined,
                    title: "Change Password",
                    onTap: () => _openPage(const ChangePasswordPage()),
                  ),

                  // SPACER to place "Contact Us" far below change password
                  const SizedBox(height: 35),

                  // "CONTACT US" BUTTON (OPTIONAL)
                  _buildDrawerTile(
                    icon: Icons.email_outlined,
                    title: "Contact Us",
                    onTap: () => _openPage(const ContactUsPage()),
                  ),
                ],
              ),
            ),
            // sign out
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: ListTile(
                onTap: () async {
                  Navigator.of(context).pop();
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const OpeningLandingPage()),
                  );
                },
                leading: Icon(
                  Icons.logout,
                  color: _isDarkMode ? Colors.redAccent : Colors.red,
                ),
                title: Text(
                  "Sign Out",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.redAccent : Colors.red,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: ListTile(
        leading: Icon(
          icon,
          color: _isDarkMode ? Colors.white70 : Colors.black87,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: _isDarkMode ? Colors.white70 : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).pop();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // The bottom nav bar
  Widget _buildFloatingFooter(
    BuildContext context,
    _ProfileAndCommunities profileData,
  ) {
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
          color: _isDarkMode ? Colors.black : Colors.white,
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
                child: Icon(
                  Icons.admin_panel_settings,
                  color: _isDarkMode ? Colors.white : Colors.black,
                  size: 40,
                ),
              ),
            ),
            // Explore => replaced with FOMO Feed logo @ height 34
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/fomo_feed'),
                child: Image.asset(
                  _isDarkMode
                      ? 'assets/fomofeedlogo.png'
                      : 'assets/fomofeedlogoblack.png',
                  height: 34,
                ),
              ),
            ),
            // Middle: Ragtag Logo => navigates to FindCommunityPage
            GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, '/find_community');
              },
              child: Image.asset(
                'assets/ragtaglogoblack.png',
                height: 40,
                color: _isDarkMode ? Colors.white : null,
              ),
            ),
            // plus
            _buildFooterIcon(
              Icons.add,
              color: _isDarkMode ? Colors.white : Colors.black,
              onTap: () {
                Navigator.pushNamed(context, '/start-community');
              },
            ),
            // user pfp
            _buildShimmeringUserPfp(profileData.photoUrl),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterIcon(
    IconData icon, {
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  Widget _buildShimmeringUserPfp(String? photoUrl) {
    return GestureDetector(
      onTap: () {
        // e.g. go to user profile
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
            // The actual circle avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black,
              backgroundImage:
                  (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShadowDivider() {
    return Container(
      width: double.infinity,
      height: 2,
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.transparent,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            spreadRadius: 3,
            offset: const Offset(0, -2),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // TOP container: stats + PFP + user info + “Edit Profile”
  // ---------------------------------------------------------
  Widget _buildTopProfileContainer(_ProfileAndCommunities data) {
    final totalCommunities = data.communityDocs.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.white24 : Colors.black26,
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statItem("Communities", "$totalCommunities"),
                  _buildPfpWithEmojis(data),
                  _buildCloutBar("Campus Clout", totalCommunities),
                ],
              ),
              const SizedBox(height: 16),
              _isEditingAll
                  ? _buildAllFieldsEditor(data)
                  : _buildAllFieldsDisplay(data),
              const SizedBox(height: 46),
            ],
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: TextButton(
              onPressed: _toggleEditProfile,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                // “Slimmer & less round” button
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                  side: const BorderSide(color: Colors.white, width: 1),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              child: Text(_isEditingAll ? "Save Edits" : "Edit Profile"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value) {
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

  Widget _buildPfpWithEmojis(_ProfileAndCommunities data) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFFAF7B), Color(0xFFD76D77)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _bgColor,
          ),
          child: GestureDetector(
            onTap: _editPhoto,
            child: ClipOval(
              child: data.photoUrl.isNotEmpty
                  ? Image.network(
                      data.photoUrl,
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
        ),
        // Emojis
        Positioned(
          top: -10,
          left: -10,
          child: Transform.scale(
            scale: 1.2,
            child: Text(data.emoji1, style: const TextStyle(fontSize: 28)),
          ),
        ),
        Positioned(
          bottom: -10,
          right: -10,
          child: Transform.scale(
            scale: 1.2,
            child: Text(data.emoji2, style: const TextStyle(fontSize: 28)),
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
      animation: _shimmerAnimation,
      builder: (context, child) {
        final shimmerOffset = _shimmerAnimation.value * width;

        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              children: [
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

  Widget _buildAllFieldsDisplay(_ProfileAndCommunities data) {
    return Column(
      children: [
        Text(
          data.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 22,
            color: _textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          data.username,
          style: TextStyle(fontSize: 16, color: _subTextColor),
        ),
        const SizedBox(height: 8),
        Text(
          data.institution,
          style: TextStyle(fontSize: 15, color: _subTextColor),
        ),
        const SizedBox(height: 2),
        Text(
          'Class of ${data.graduationYear}',
          style: TextStyle(fontSize: 15, color: _subTextColor),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Vibes:",
              style: TextStyle(fontSize: 15, color: _subTextColor),
            ),
            const SizedBox(width: 6),
            Text(
              "${data.emoji1}  ${data.emoji2}",
              style: const TextStyle(fontSize: 18),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAllFieldsEditor(_ProfileAndCommunities data) {
    final color = _isDarkMode ? Colors.white : Colors.black87;

    return Column(
      children: [
        TextField(
          controller: _nameController,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, color: color),
          decoration: InputDecoration(
            hintText: 'Full name',
            hintStyle: TextStyle(color: color.withOpacity(0.4)),
            border: const UnderlineInputBorder(),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.pinkAccent.shade100),
            ),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _usernameController,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: color),
          decoration: InputDecoration(
            hintText: 'username',
            hintStyle: TextStyle(color: color.withOpacity(0.4)),
            border: const UnderlineInputBorder(),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.pinkAccent.shade100),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          data.institution,
          style: TextStyle(fontSize: 15, color: _subTextColor),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 80,
          child: TextField(
            controller: _gradYearController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: color),
            decoration: InputDecoration(
              hintText: 'Year',
              hintStyle: TextStyle(color: color.withOpacity(0.4)),
              border: const UnderlineInputBorder(),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.pinkAccent.shade100),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Pick your vibe icons:",
          style: TextStyle(fontSize: 15, color: color),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildVibeSlot(1, _tempEmoji1),
            const SizedBox(width: 16),
            _buildVibeSlot(2, _tempEmoji2),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 50,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _availableEmojis.map((emoji) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedEmojiSlot == 1) {
                        _tempEmoji1 = emoji;
                      } else {
                        _tempEmoji2 = emoji;
                      }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(emoji, style: const TextStyle(fontSize: 30)),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  /// One “emoji vibe” slot
  Widget _buildVibeSlot(int slotNumber, String currentEmoji) {
    final isSelected = (_selectedEmojiSlot == slotNumber);

    return GestureDetector(
      onTap: () => setState(() {
        _selectedEmojiSlot = slotNumber;
      }),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.pinkAccent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          currentEmoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }

  // ------------------------------
  // PRIVATE MESSAGES SECTION
  // ------------------------------
  Widget _buildPrivateMessagesSection(
    _ProfileAndCommunities data,
    List<ChatConversation> chats,
  ) {
    final myInstitution = data.institution;

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          _buildBadgeTrophy(data.badges),
          const SizedBox(width: 8),
          // The red chat circle => go to user directory
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserDirectoryPage(institution: myInstitution),
                ),
              );
            },
            child: Container(
              width: 70,
              height: 70,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF10048),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF10048).withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // The row of chat avatars
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: chats.map(_buildChatAvatar).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Single chat avatar with neon red X animation
  Widget _buildChatAvatar(ChatConversation chat) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: () {
        // Show the neon X
        setState(() {
          _selectedChatId = chat.chatId;
        });
        _trashController.forward(from: 0);
      },
      onTap: () {
        // If user taps a different avatar while one is selected, clear the neon X first.
        if (_selectedChatId != null && _selectedChatId != chat.chatId) {
          setState(() => _selectedChatId = null);
        }
        // Then open the chat normally
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatPage(
              chatId: chat.chatId,
              otherUserId: chat.otherUserId,
              otherUserName: chat.otherUserName,
              otherUserPhotoUrl: chat.otherUserPhotoUrl,
            ),
          ),
        );
      },
      child: Container(
        width: 70,
        height: 70,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Chat avatar image or placeholder
            CircleAvatar(
              radius: 35,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: chat.otherUserPhotoUrl.isNotEmpty
                  ? NetworkImage(chat.otherUserPhotoUrl)
                  : null,
              child: chat.otherUserPhotoUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                      size: 35,
                    )
                  : null,
            ),

            // Neon red X overlay
            if (_selectedChatId == chat.chatId)
              AnimatedBuilder(
                animation: _trashScale,
                builder: (ctx, child) {
                  return Transform.scale(
                    scale: _trashScale.value,
                    child: GestureDetector(
                      onTap: () => _deleteChat(chat.chatId),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          // Neon Glow
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.6),
                              blurRadius: 3,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.4),
                              blurRadius: 9,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.redAccent,
                          size: 50,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // A minimal bottom-sheet for user badges
  Widget _buildBadgeTrophy(List<String> badges) {
    return GestureDetector(
      onTap: () => _showUltraMinimalBadgeSheet(badges),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Colors.orangeAccent, Colors.amber],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.amberAccent.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.emoji_events,
          color: Colors.white,
          size: 34,
        ),
      ),
    );
  }

  void _showUltraMinimalBadgeSheet(List<String> badges) {
    showModalBottomSheet(
      context: context,
      barrierColor: Colors.black54,
      backgroundColor: Colors.transparent,
      isScrollControlled: false,
      builder: (_) {
        return Container(
          decoration: BoxDecoration(
            color: _isDarkMode ? Colors.grey[900]!.withOpacity(0.92) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The minimal drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _isDarkMode ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                if (badges.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "No badges yet...",
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: badges
                          .map((b) => _buildSingleUltraMinimalBadge(b))
                          .toList(growable: false),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleUltraMinimalBadge(String badgeStr) {
    bool isCreationBadge = false;
    bool isChallengeBadge = false;

    if (badgeStr == 'introbadge') {
      badgeStr = 'assets/newmemberbadge.png';
    } else if (badgeStr == 'creationbadge') {
      badgeStr = 'assets/creationbadge.png';
      isCreationBadge = true;
    } else if (badgeStr == 'dayonebadge') {
      badgeStr = 'assets/dayonebadge.png';
    } else if (badgeStr == 'ChallengeBadge') {
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glowColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipOval(
        child: Container(
          color: Colors.transparent,
          width: 70,
          height: 70,
          child: Image(
            image: imageProvider,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // The label + search for communities
  Widget _buildCommunitiesLabelAndSearch() {
    // Switch icons for list vs. grid
    final String iconName;
    if (_isDarkMode) {
      iconName = _isGridView ? 'communitieswhite.png' : 'gridcardwhite.png';
    } else {
      iconName = _isGridView ? 'communities.png' : 'gridcard.png';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              splashColor: _isDarkMode ? Colors.white24 : Colors.black12,
              onTap: () {
                setState(() => _isGridView = !_isGridView);
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.asset(
                  'assets/$iconName',
                  height: 22,
                ),
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              setState(() {
                if (!_searchActive) {
                  _searchActive = true;
                }
              });
            },
            child: Container(
              width: 160,
              height: 36,
              decoration: BoxDecoration(
                color: _searchBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.search,
                      color: Colors.black54,
                      size: 18,
                    ),
                  ),
                  if (_searchActive)
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 12,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search…",
                          hintStyle: TextStyle(
                            color:
                                _isDarkMode ? Colors.white54 : Colors.black38,
                            fontSize: 12,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(left: 2),
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchQuery = '';
                                _searchActive = false;
                              });
                            },
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // The communities section => calls either list or grid
  Widget _buildCommunitiesSection(_ProfileAndCommunities data) {
    final comms = data.communityDocs;
    final filtered = comms.where((doc) {
      final docData = doc.data() as Map<String, dynamic>;
      final name = (docData['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filtered.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            "No communities yet... What are you waiting on! :)",
            style: TextStyle(color: _subTextColor, fontSize: 16),
          ),
        ),
      );
    }

    return _isGridView
        ? _buildHorizontalRectangleGrid(filtered)
        : _buildBigCardList(filtered);
  }

  // “LIST MODE” => big vertical 16:9 cards
  Widget _buildBigCardList(List<QueryDocumentSnapshot> comms) {
    return SizedBox(
      height: 700,
      child: ListView.separated(
        itemCount: comms.length,
        separatorBuilder: (ctx, i) => const SizedBox(height: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (ctx, index) {
          final doc = comms[index];
          final d = doc.data() as Map<String, dynamic>;

          final docId = doc.id;
          final name = d['name'] ?? 'Unnamed';
          final description = d['description'] ?? 'No desc.';
          final imageUrl = d['pfpUrl'] ?? d['imageUrl'] ?? '';
          final type = d['type'] ?? 'Unknown';

          return _buildBigCardCommunityItem(
            docId: docId,
            name: name,
            description: description,
            imageUrl: imageUrl,
            communityType: type,
            onTap: () => _goToCommunity(type, docId, d),
          );
        },
      ),
    );
  }

  Widget _buildBigCardCommunityItem({
    required String docId,
    required String name,
    required String description,
    required String imageUrl,
    required String communityType,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white24,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // top 16:9 image
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: (imageUrl.isNotEmpty)
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, error, stack) {
                              return Container(
                                color: Colors.grey.shade800,
                                child: Icon(
                                  Icons.broken_image,
                                  color: _isDarkMode
                                      ? Colors.white54
                                      : Colors.black54,
                                  size: 40,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade800,
                            child: Icon(
                              Icons.photo_camera_back,
                              color: _isDarkMode
                                  ? Colors.white54
                                  : Colors.black54,
                              size: 40,
                            ),
                          ),
                  ),
                ),
                // name + desc
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
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                // bottom icon
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isDarkMode ? Colors.white70 : Colors.black87,
                          width: 1.4,
                        ),
                      ),
                      child: Icon(
                        Icons.open_in_new,
                        color: _isDarkMode
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
          // White circle in top-left corner
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // “GRID MODE” => single-column horizontal rectangles
  Widget _buildHorizontalRectangleGrid(List<QueryDocumentSnapshot> comms) {
    return SizedBox(
      height: 700,
      child: GridView.builder(
        itemCount: comms.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          mainAxisSpacing: 12,
          childAspectRatio: 4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemBuilder: (ctx, index) {
          final doc = comms[index];
          final d = doc.data() as Map<String, dynamic>;

          final docId = doc.id;
          final name = d['name'] ?? 'Unnamed';
          final description = d['description'] ?? 'No desc.';
          final imageUrl = d['pfpUrl'] ?? d['imageUrl'] ?? '';
          final type = d['type'] ?? 'Unknown';

          return _buildHorizontalRectCommunityCard(
            docId: docId,
            name: name,
            description: description,
            imageUrl: imageUrl,
            communityType: type,
            onTap: () => _goToCommunity(type, docId, d),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalRectCommunityCard({
    required String docId,
    required String name,
    required String description,
    required String imageUrl,
    required String communityType,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      splashColor: Colors.white24,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: _isDarkMode
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.black.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Left image
                ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 16 / 10,
                    child: (imageUrl.isNotEmpty)
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, error, stack) {
                              return Container(
                                color: Colors.grey.shade800,
                                child: Icon(
                                  Icons.broken_image,
                                  color: _isDarkMode
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              );
                            },
                          )
                        : Container(
                            color: Colors.grey.shade800,
                            child: Icon(
                              Icons.photo_camera_back,
                              color:
                                  _isDarkMode ? Colors.white54 : Colors.black54,
                            ),
                          ),
                  ),
                ),
                // Right side: name, desc, bottom-right icon
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                _isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _isDarkMode ? Colors.white70 : Colors.black87,
                                width: 1.2,
                              ),
                            ),
                            child: Icon(
                              Icons.open_in_new,
                              size: 14,
                              color: _isDarkMode
                                  ? Colors.white.withOpacity(0.9)
                                  : Colors.black.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // White circle in top-left corner
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goToCommunity(String type, String docId, Map<String, dynamic> docData) {
    final userId = _currentUser?.uid ?? 'noUser';

    if (type.toLowerCase().contains('forum')) {
      Navigator.pushNamed(
        context,
        '/open-forums-profile',
        arguments: {
          'communityId': docId,
          'communityData': docData,
          'userId': userId,
        },
      );
    } else if (type.toLowerCase().contains('interest')) {
      Navigator.pushNamed(
        context,
        '/interest-groups-profile',
        arguments: {
          'communityId': docId,
          'communityData': docData,
          'userId': userId,
        },
      );
    } else if (type.toLowerCase().contains('club')) {
      Navigator.pushNamed(
        context,
        '/clubs-profile',
        arguments: {
          'communityId': docId,
          'communityData': docData,
          'userId': userId,
        },
      );
    } else if (type.toLowerCase().contains('spark')) {
      Navigator.pushNamed(
        context,
        '/ragtag-sparks-profile',
        arguments: {
          'communityId': docId,
          'communityData': docData,
          'userId': userId,
        },
      );
    } else {
      Navigator.pushNamed(
        context,
        '/community_detail',
        arguments: {
          'communityId': docId,
          'communityData': docData,
          'userId': userId,
        },
      );
    }
  }

  // ----------------------------------------------------------------
  // The fancy loading screen (ONLY the animation changed to mimic
  // the OpeningLandingPage shimmer, fade, scale, & gradient overlays)
  // ----------------------------------------------------------------
  Widget _buildFancyLoading() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (ctx, child) {
        final color1 = _bgColor1Animation.value ?? Colors.black;
        final color2 = _bgColor2Animation.value ?? Colors.black;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Animated gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color1, color2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // Faint shimmer overlays
            _buildShimmerOverlays(),

            // Centered logo + loading text
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: _buildShimmerLogo(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _loadingMessages[_loadingMessageIndex],
                      key: ValueKey(_loadingMessageIndex),
                      style: const TextStyle(
                        fontFamily: 'Lovelo',
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  /// Same faint shimmer overlays from OpeningLandingPage
  Widget _buildShimmerOverlays() {
    return Stack(
      children: [
        // First shimmer layer
        Positioned.fill(
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFD76D77).withOpacity(0.2),
            highlightColor: const Color(0xFFFFAF7B).withOpacity(0.3),
            period: const Duration(seconds: 4),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFAF7B),
                    Color(0xFFD76D77),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        // Second shimmer layer
        Positioned.fill(
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFD76D77).withOpacity(0.1),
            highlightColor: const Color(0xFFFFAF7B).withOpacity(0.2),
            period: const Duration(seconds: 9),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFD76D77),
                    Color(0xFFFFAF7B),
                  ],
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The shimmering, gradient-filled logo
  Widget _buildShimmerLogo() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (ctx, child) {
        final shimmerWidth = MediaQuery.of(context).size.width / 2;
        final start = _shimmerAnimation.value * MediaQuery.of(context).size.width;

        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.4),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(
              Rect.fromLTWH(start, 0, shimmerWidth, bounds.height),
            );
          },
          blendMode: BlendMode.srcATop,
          child: _buildGradientLogo(),
        );
      },
    );
  }

  Widget _buildGradientLogo() {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Color(0xFFFFAF7B),
            Color(0xFFD76D77),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcATop,
      child: Image.asset(
        'assets/ragtaglogoblack.png',
        width: 200,
        height: 200,
      ),
    );
  }
}
