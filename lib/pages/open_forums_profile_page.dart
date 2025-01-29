import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

class OpenForumsProfilePage extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic> communityData;
  final String userId;

  const OpenForumsProfilePage({
    Key? key,
    required this.communityId,
    required this.communityData,
    required this.userId,
  }) : super(key: key);

  @override
  State<OpenForumsProfilePage> createState() => _OpenForumsProfilePageState();
}

class _OpenForumsProfilePageState extends State<OpenForumsProfilePage>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  // 1) BASIC STATES
  // ---------------------------------------------------------------------------
  bool isLoading = false;
  bool isAdmin = false;
  bool isDarkMode = true; // Default to dark mode

  Map<String, dynamic> forumData = {};
  Map<String, dynamic>? pinnedMessageData;
  List<Map<String, dynamic>> eventList = [];

  late AnimationController _heroController;
  late Animation<double> _heroAnimation;
  late AnimationController _fadeController;

  final TextEditingController _msgController = TextEditingController();
  final TextEditingController _renameController = TextEditingController();

  final TextEditingController _newEventTitleCtrl = TextEditingController();
  final TextEditingController _newEventLocationCtrl = TextEditingController();
  DateTime? _newEventDateTime;

  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;

  // ---------------------------------------------------------------------------
  // 2) CENSOR & ANONYMITY
  // ---------------------------------------------------------------------------
  bool _censorActive = false;
  bool _identitiesArePublic = true;

  void _listenToForumSettings() {
    FirebaseFirestore.instance
        .collection('openForums')
        .doc(widget.communityId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;

      final bool isCensorOn = data['censorActive'] == true;
      final bool areIdentitiesPublic = data['identitiesArePublic'] ?? true;

      setState(() {
        _censorActive = isCensorOn;
        _identitiesArePublic = areIdentitiesPublic;
      });
    });
  }

  Future<void> _toggleCensorActive(bool newVal) async {
    if (!isAdmin) return;
    try {
      await FirebaseFirestore.instance
          .collection('openForums')
          .doc(widget.communityId)
          .update({'censorActive': newVal});
    } catch (e) {
      _showSnack("Error toggling censor: $e");
    }
  }

  Future<void> _toggleAnonymousForum() async {
    if (!isAdmin) return;
    if (!_identitiesArePublic) {
      _showSnack("Already Anonymous; can't revert.");
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
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
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Make Forum Anonymous",
                style: GoogleFonts.workSans(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Once you switch everyone to Anonymous, you will NEVER be able to revert back.\n\nDo you wish to proceed?",
                style: GoogleFonts.workSans(
                  color: Colors.white,
                  fontSize: 15,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                    ),
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(
                      "Cancel",
                      style: GoogleFonts.workSans(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      "Yes, Proceed",
                      style: GoogleFonts.workSans(),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('openForums')
          .doc(widget.communityId)
          .update({'identitiesArePublic': false});
      _showSnack("Forum is now anonymous forever!");
    } catch (e) {
      _showSnack("Error making forum anonymous: $e");
    }
  }

  void _showForumSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                width: double.infinity,
                child: Text(
                  "Admin Settings",
                  style: GoogleFonts.workSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
              const Divider(height: 1, thickness: 0.5),
              SwitchListTile(
                activeColor: Colors.tealAccent,
                inactiveThumbColor: Colors.grey,
                title: Text(
                  'Censor Chat',
                  style: GoogleFonts.workSans(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                subtitle: Text(
                  "Replace offensive words with cuteness",
                  style: GoogleFonts.workSans(
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                    fontSize: 13,
                  ),
                ),
                value: _censorActive,
                onChanged: (val) {
                  Navigator.of(context).pop();
                  _toggleCensorActive(val);
                },
              ),
              SwitchListTile(
                activeColor: Colors.orangeAccent,
                inactiveThumbColor: Colors.grey,
                title: Text(
                  'Anonymous Forum',
                  style: GoogleFonts.workSans(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                subtitle: _identitiesArePublic
                    ? Text(
                        "Make user identities hidden forever",
                        style: GoogleFonts.workSans(
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                          fontSize: 13,
                        ),
                      )
                    : Text(
                        "Already Anonymous (irreversible)",
                        style: GoogleFonts.workSans(
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                value: !_identitiesArePublic,
                onChanged: (val) {
                  if (!_identitiesArePublic && val == false) return;
                  if (!_identitiesArePublic) {
                    _showSnack("Already Anonymous; can't revert.");
                    return;
                  }
                  if (val == true) {
                    Navigator.of(context).pop();
                    _toggleAnonymousForum();
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 3) PROFANITY LISTS
  // ---------------------------------------------------------------------------
  final List<String> _badWords = [
    'fuck','fuckyou','fucking','shit','shitty','ass','asshole','jackass','dumbass',
    'bitch','bitchy','bastard','dick','dicks','dickhead','cock','pussy','cunt','whore',
    'slut','slutty','douche','douchebag','motherfucker','motherfuckin','son of a bitch',
    'goddamn','goddamned','damn','damned','piss','pissed','crapping','blowjob','bj',
    'handjob','rimjob','dildo','vibrator','anal','butthole','bust a nut','jizz','ho',
    'hoe','nigger','nigga','spic','beaner','kike','chink','gook','wetback','raghead',
    'towelhead','jap','cracker','fag','faggot','dyke','homo','tranny','queer','retard',
    'retarded','spazz','spastic','cripple','christfag','bible-basher','infidel',
    'heathen','harlot','slant','slope','gypsy','kill yourself','kys','die in a hole',
    'die in a fire','i\'ll kill you','i\'ll murder you','hang yourself'
  ];

  final List<String> _cuteWords = [
    'bubbles','hugs','kittens','puppies','rainbows','sprinkles','cupcakes','unicorns',
    'cuddles','snuggles','fairy dust','pixie wings','butterfly kisses','marshmallows',
    'sugarplums','stardust','confetti','daydreams','fluff','sunshine','glitter','sparkles',
    'angel wings','cinnamon rolls','puppy dog tails','cotton candy','daisies','warm cookies',
    'rainbow sprinkles',
  ];

  final Random _random = Random();

  String _censorText(String text) {
    for (final badWord in _badWords) {
      final regex = RegExp(r'\b' + badWord + r'\b', caseSensitive: false);
      while (regex.hasMatch(text)) {
        final replacement = _cuteWords[_random.nextInt(_cuteWords.length)];
        text = text.replaceFirst(regex, replacement);
      }
    }
    return text;
  }

  // ---------------------------------------------------------------------------
  // 4) CHALLENGEBADGE ANIMATION SETUP
  // ---------------------------------------------------------------------------
  bool _hasShownChallengeBadgeDialog = false;

  late AnimationController _badgeAnimController;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();

    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _heroAnimation = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutQuad,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

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
    _badgeAnimController.forward().then((_) => _badgeAnimController.reverse());
    _badgeAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _badgeAnimController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _badgeAnimController.forward();
      }
    });

    _listenToForumSettings();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAllData().then((_) {
        _heroController.forward();
        _fadeController.forward();
      });
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _fadeController.dispose();
    _msgController.dispose();
    _renameController.dispose();
    _newEventTitleCtrl.dispose();
    _newEventLocationCtrl.dispose();
    _scrollController.dispose();
    _badgeAnimController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 5) FETCH ALL DATA
  // ---------------------------------------------------------------------------
  Future<void> _fetchAllData() async {
    setState(() => isLoading = true);
    try {
      // 1. Forum Info, pinned messages, events
      await _fetchForumInfo(widget.communityId);
      if (pinnedMessageId != null) {
        await _fetchPinnedMessage(widget.communityId, pinnedMessageId!);
      }
      await _fetchEvents(widget.communityId);

      // 2. Check final challenge first
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await _checkAndCompleteFinalChallenge(uid);
      }

      // 3. Check if user is admin
      await _checkIfUserIsAdmin(widget.communityId);
      // (Membership logic removed)
    } catch (e) {
      _showSnack("Error loading forum data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchForumInfo(String forumId) async {
    final docRef =
        FirebaseFirestore.instance.collection('openForums').doc(forumId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      setState(() => forumData = snapshot.data() ?? {});
    } else {
      _showSnack("This Open Forum does not exist in Firestore.");
    }
  }

  Future<void> _checkIfUserIsAdmin(String forumId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final adminDocRef = FirebaseFirestore.instance
        .collection('openForums')
        .doc(forumId)
        .collection('admins')
        .doc(uid);
    final adminSnap = await adminDocRef.get();
    setState(() => isAdmin = adminSnap.exists);
  }

  Future<void> _fetchPinnedMessage(String forumId, String messageDocId) async {
    final docRef = FirebaseFirestore.instance
        .collection('openForums')
        .doc(forumId)
        .collection('messages')
        .doc(messageDocId);
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      setState(() => pinnedMessageData = snapshot.data());
    } else {
      setState(() => pinnedMessageData = null);
    }
  }

  Future<void> _fetchEvents(String forumId) async {
    final eventsSnap = await FirebaseFirestore.instance
        .collection('openForums')
        .doc(forumId)
        .collection('events')
        .orderBy('dateTime', descending: true)
        .get();

    setState(() {
      eventList = eventsSnap.docs.map((doc) {
        return {...doc.data(), 'id': doc.id};
      }).toList();
    });
  }

  bool get identitiesArePublic => _identitiesArePublic;

  String? get pinnedMessageId {
    return forumData['pinnedMessageId'] as String?;
  }

  // ---------------------------------------------------------------------------
  // CHECK & COMPLETE FINAL CHALLENGE IMMEDIATELY
  // ---------------------------------------------------------------------------
  Future<void> _checkAndCompleteFinalChallenge(String uid) async {
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return;
      final data = userDoc.data();
      if (data == null) return;

      final introStep = data['introchallenge'] ?? 0;

      // If user is at step 2 and hasn't shown the badge pop-up
      if (introStep == 2 && !_hasShownChallengeBadgeDialog) {
        _hasShownChallengeBadgeDialog = true;

        // Immediately set introchallenge to 3, plus add badge
        await userRef.update({
          'introchallenge': 3,
          'badges': FieldValue.arrayUnion(['ChallengeBadge'])
        });

        if (!mounted) return;
        _showChallengeBadgeDialog();
      }
    } catch (e) {
      _showSnack("Error checking final challenge: $e");
    }
  }

  void _showChallengeBadgeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
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
                  // Stack for glow + shimmer
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
                          'assets/challengebadge.png',
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "CONGRATS!",
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
                  const Text(
                    "You’ve just earned the Challenge-Badge.\nWelcome to the big leagues!",
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
                    onPressed: () => Navigator.pop(context),
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

  // ---------------------------------------------------------------------------
  // 6) UPDATE FORUM NAME + PIN
  // ---------------------------------------------------------------------------
  Future<void> _updateForumName(String newName) async {
    if (!isAdmin) return;
    try {
      await FirebaseFirestore.instance
          .collection('openForums')
          .doc(widget.communityId)
          .update({'name': newName});
      setState(() => forumData['name'] = newName);
      _showSnack("Forum name updated!");
    } catch (e) {
      _showSnack("Error renaming forum: $e");
    }
  }

  Future<void> _pinMessage(String messageId) async {
    if (!isAdmin) return;
    try {
      await FirebaseFirestore.instance
          .collection('openForums')
          .doc(widget.communityId)
          .update({'pinnedMessageId': messageId});
      setState(() => forumData['pinnedMessageId'] = messageId);

      await _fetchPinnedMessage(widget.communityId, messageId);
      _showSnack("Message pinned!");
    } catch (e) {
      _showSnack("Error pinning message: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 7) SENDING MESSAGES (include senderPhotoUrl)
  // ---------------------------------------------------------------------------
  Future<void> _sendMessage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final text = _msgController.text.trim();
    if (text.isEmpty && _selectedImage == null) {
      return;
    }

    // Grab the user's photoUrl to include in the message
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final senderName = userDoc.data()?['fullName'] ?? 'User';
    final userPhotoUrl = userDoc.data()?['photoUrl'] ?? '';

    String? imageUrl;
    if (_selectedImage != null) {
      try {
        // In real usage, you'd upload to Firebase Storage, but here we store local path as example
        imageUrl = _selectedImage!.path;
      } catch (e) {
        _showSnack("Couldn't upload image: $e");
        return;
      }
    }

    try {
      await FirebaseFirestore.instance
          .collection('openForums')
          .doc(widget.communityId)
          .collection('messages')
          .add({
        'text': text,
        'senderId': uid,
        'senderName': senderName,
        'senderPhotoUrl': userPhotoUrl, // <-- We add the user's photo URL
        'timestamp': FieldValue.serverTimestamp(),
        if (imageUrl != null) 'imageUrl': imageUrl,
      });

      _msgController.clear();
      setState(() => _selectedImage = null);
    } catch (e) {
      _showSnack("Couldn't send message: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 8) UI BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final fallbackName = forumData['name'] ?? widget.communityData['name'] ?? '';
    final pfpUrl = forumData['pfpUrl'] ?? widget.communityData['pfpUrl'] ?? '';

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(pfpUrl: pfpUrl, fallbackName: fallbackName),
                if (pinnedMessageData != null) _buildPinnedMessage(),
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: _buildChatList(),
                  ),
                ),
                _buildBottomMessageField(),
              ],
            ),
            if (isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader({required String pfpUrl, required String fallbackName}) {
    return AnimatedBuilder(
      animation: _heroAnimation,
      builder: (context, child) {
        final scaleValue = 1.0 + 0.03 * _heroAnimation.value;
        return SizedBox(
          height: 220,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (pfpUrl.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(pfpUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(color: Colors.grey[600]),
              Container(color: Colors.black.withOpacity(0.35)),

              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (isAdmin)
                      InkWell(
                        onTap: _showForumSettingsSheet,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.grey[800]
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.settings_outlined,
                            color:
                                isDarkMode ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    InkWell(
                      onTap: () => setState(() => isDarkMode = !isDarkMode),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color:
                              isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDarkMode
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Align(
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: scaleValue,
                  child: InkWell(
                    onTap: isAdmin
                        ? () async {
                            _renameController.text = fallbackName;
                            await showDialog(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text("Edit Forum Name"),
                                content: TextField(
                                  controller: _renameController,
                                  decoration:
                                      const InputDecoration(labelText: "Name"),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      _updateForumName(
                                          _renameController.text.trim());
                                      Navigator.pop(context);
                                    },
                                    child: const Text("Save"),
                                  ),
                                ],
                              ),
                            );
                          }
                        : null,
                    child: Text(
                      fallbackName.isNotEmpty
                          ? fallbackName
                          : widget.communityId,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(
                            color: Colors.black54,
                            offset: Offset(2, 2),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              // We remove the old membership join/leave button from here
            ],
          ),
        );
      },
    );
  }

  Widget _buildPinnedMessage() {
    final text = pinnedMessageData?['text'] ?? '';
    final realName = pinnedMessageData?['senderName'] ?? '—';
    final senderId = pinnedMessageData?['senderId'] ?? '???';
    final displayedName = identitiesArePublic
        ? realName
        : _getAnonymousNameFor(senderId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          width: 1,
          color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.push_pin_rounded,
                color: isDarkMode ? Colors.orange[200] : Colors.orange[800]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Pinned Message",
                    style: GoogleFonts.workSans(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "$text\n– $displayedName",
                    style: GoogleFonts.workSans(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('openForums')
          .doc(widget.communityId)
          .collection('messages')
          .orderBy('timestamp')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading chat."));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data?.docs ?? [];
        DateTime? previousDate;
        final messageWidgets = <Widget>[];

        for (var i = 0; i < docs.length; i++) {
          final data = docs[i].data() as Map<String, dynamic>? ?? {};
          final ts = data['timestamp'] as Timestamp?;
          final msgDate = ts?.toDate();
          final docId = docs[i].id;

          if (msgDate != null) {
            final justDate = DateTime(msgDate.year, msgDate.month, msgDate.day);
            if (previousDate == null || justDate != previousDate) {
              messageWidgets.add(_buildDayDivider(justDate));
              previousDate = justDate;
            }
          }

          messageWidgets.add(
            GestureDetector(
              onLongPress: isAdmin ? () => _pinMessage(docId) : null,
              child: _buildChatBubble(data),
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 8),
          children: messageWidgets,
        );
      },
    );
  }

  Widget _buildDayDivider(DateTime date) {
    final dayString =
        "${_weekdayName(date.weekday)}, ${_monthName(date.month)} ${date.day}, ${date.year}";
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFAF7B),
                  Color(0xFFD76D77),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dayString,
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    const days = [
      "Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"
    ];
    final index = weekday - 1;
    if (index < 0 || index > 6) return "UnknownDay";
    return days[index];
  }

  String _monthName(int month) {
    const months = [
      "January","February","March","April","May","June",
      "July","August","September","October","November","December"
    ];
    return months[month - 1];
  }

  // Reworked signature: pass the entire data doc so we can grab everything.
  Widget _buildChatBubble(Map<String, dynamic> data) {
    // Extract info
    String text = data['text'] ?? '';
    final senderId = data['senderId'] ?? '';
    final realSenderName = data['senderName'] ?? '';
    final senderPhotoUrl = data['senderPhotoUrl'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMe = currentUserId == senderId;

    // Censor text if needed
    if (_censorActive && text.isNotEmpty) {
      text = _censorText(text);
    }

    // Name can be anonymized
    final displayedName = identitiesArePublic
        ? realSenderName
        : _getAnonymousNameFor(senderId);

    // If identities are not public, we also skip showing the real photo
    final actualPhotoUrl =
        identitiesArePublic ? senderPhotoUrl : null; // hide if anonymous

    // Build a circle avatar
    final circleAvatar = CircleAvatar(
      radius: 16,
      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[400],
      backgroundImage: (actualPhotoUrl != null && actualPhotoUrl.isNotEmpty)
          ? NetworkImage(actualPhotoUrl)
          : null,
      child: (actualPhotoUrl == null || actualPhotoUrl.isEmpty)
          ? Icon(
              Icons.person,
              color: isDarkMode ? Colors.white : Colors.black87,
              size: 18,
            )
          : null,
    );

    // Build the actual message bubble
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? (isDarkMode ? Colors.blueGrey[700] : Colors.blue[100])
            : (isDarkMode ? Colors.grey[800] : Colors.grey[300]),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
          bottomRight: isMe ? Radius.zero : const Radius.circular(12),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Text(
              displayedName,
              style: GoogleFonts.workSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.grey[100] : Colors.grey[800],
              ),
            ),
          if (!isMe) const SizedBox(height: 4),
          if (imageUrl != null && imageUrl.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(imageUrl),
                  fit: BoxFit.cover,
                  height: 200,
                ),
              ),
            ),
          if (text.isNotEmpty)
            Text(
              text,
              style: GoogleFonts.workSans(
                fontSize: 14,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
        ],
      ),
    );

    // Return a row that places avatar + bubble left or right
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) circleAvatar,
          if (!isMe) const SizedBox(width: 8),
          bubble,
          if (isMe) const SizedBox(width: 8),
          if (isMe) circleAvatar,
        ],
      ),
    );
  }

  final Map<String, String> _anonymousNameMap = {};

  String _getAnonymousNameFor(String userId) {
    if (_anonymousNameMap.containsKey(userId)) {
      return _anonymousNameMap[userId]!;
    }
    final randomName = _generateFunName();
    _anonymousNameMap[userId] = randomName;
    return randomName;
  }

  String _generateFunName() {
    final adjectives = [
      "Sneaky","Silly","Mighty","Dazzling","Funky","Cheerful",
      "Whimsical","Grumpy","Clever","Goofy",
    ];
    final animals = [
      "Penguin","Tiger","Giraffe","Octopus","Koala","Dragon",
      "Dolphin","Narwhal","Hippo","Sloth",
    ];
    final rand = Random();
    final adj = adjectives[rand.nextInt(adjectives.length)];
    final anim = animals[rand.nextInt(animals.length)];
    return "$adj$anim"; // e.g. "SneakyPenguin"
  }

  Widget _buildBottomMessageField() {
    return Container(
      color: isDarkMode ? Colors.grey[850] : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedImage!.path),
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _selectedImage = null);
                    },
                    icon: Icon(
                      Icons.close,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              InkWell(
                onTap: _pickImageFromGallery,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.blueGrey[400]
                        : Colors.blueGrey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.attachment_rounded,
                    color: isDarkMode ? Colors.black : Colors.white,
                    size: 20,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _msgController,
                  style: GoogleFonts.workSans(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.workSans(
                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: isDarkMode
                            ? Colors.grey[700]!
                            : Colors.grey[300]!,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color:
                            isDarkMode ? Colors.tealAccent : Colors.blueGrey,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.blueGrey[400]
                        : Colors.blueGrey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.send,
                    color: isDarkMode ? Colors.black : Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final picked = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        setState(() => _selectedImage = picked);
      }
    } catch (e) {
      _showSnack("Error picking image: $e");
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
