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
              colors: [Color(0xFFFFAF7B), Color(0xFFD76D77)],
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
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
  // 3) PROFANITY & ANONYMITY HELPERS
  // ---------------------------------------------------------------------------
  final List<String> _badWords = [
    'fuck','fuckyou','fucking','shit','shitty','ass','asshole','jackass','dumbass',
    'bitch','bitchy','bastard','dick','dicks','dickhead','cock','pussy','cunt','whore','slut','slutty',
    'douche','douchebag','motherfucker','motherfuckin','son of a bitch','goddamn','goddamned','damn','damned',
    'piss','pissed','crapping','blowjob','bj','handjob','rimjob','dildo','vibrator','anal','butthole','bust a nut',
    'jizz','ho','hoe','nigger','nigga','spic','beaner','kike','chink','gook','wetback','raghead','towelhead','jap',
    'cracker','fag','faggot','dyke','homo','tranny','queer','retard','retarded','spazz','spastic','cripple','christfag',
    'bible-basher','infidel','heathen','harlot','slant','slope','gypsy','kill yourself','kys','die in a hole',
    'die in a fire','i\'ll kill you','i\'ll murder you','hang yourself'
  ];

  final List<String> _cuteWords = [
    'bubbles','hugs','kittens','puppies','rainbows','sprinkles','cupcakes','unicorns','cuddles','snuggles',
    'fairy dust','pixie wings','butterfly kisses','marshmallows','sugarplums','stardust','confetti','daydreams',
    'fluff','sunshine','glitter','sparkles','angel wings','cinnamon rolls','puppy dog tails','cotton candy','daisies',
    'warm cookies','rainbow sprinkles',
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
  // 4) ANIMATION SETUP (includes challenge badge animation)
  // ---------------------------------------------------------------------------
  bool _hasShownChallengeBadgeDialog = false;
  late AnimationController _badgeAnimController;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();
    _listenToBlockedUsers();

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

  Future<void> _fetchAllData() async {
    setState(() => isLoading = true);
    try {
      await _fetchForumInfo(widget.communityId);
      if (pinnedMessageId != null) {
        await _fetchPinnedMessage(widget.communityId, pinnedMessageId!);
      }
      await _fetchEvents(widget.communityId);
      await _checkIfUserIsAdmin(widget.communityId);
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

  String? get pinnedMessageId {
    return forumData['pinnedMessageId'] as String?;
  }

  // ---------------------------------------------------------------------------
  // 5) UPDATE FORUM NAME + PIN
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
  // 6) SENDING MESSAGES (include senderPhotoUrl)
  // ---------------------------------------------------------------------------
  Future<void> _sendMessage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final text = _msgController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final senderName = userDoc.data()?['fullName'] ?? 'User';
    final userPhotoUrl = userDoc.data()?['photoUrl'] ?? '';

    String? imageUrl;
    if (_selectedImage != null) {
      try {
        // For simplicity, using the local file path. Replace with Storage upload in production.
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
        'senderPhotoUrl': userPhotoUrl,
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
  // 7) IMAGE PICKING
  // ---------------------------------------------------------------------------
  void _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                Icons.camera_alt,
                color: _isDarkMode ? Colors.tealAccent : Colors.blueGrey,
              ),
              title: Text(
                'Take a photo',
                style: GoogleFonts.workSans(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _getImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: _isDarkMode ? Colors.tealAccent : Colors.blueGrey,
              ),
              title: Text(
                'Choose from Gallery',
                style: GoogleFonts.workSans(
                  color: _isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _getImageFromSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getImageFromSource(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile == null) return;
      setState(() => _selectedImage = pickedFile);
    } catch (e) {
      _showSnack("Error picking image: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 8) ADMIN ACTIONS: DELETE / PIN
  // ---------------------------------------------------------------------------
  Future<void> _deleteMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('openForums')
        .doc(widget.communityId)
        .collection('messages')
        .doc(docId)
        .delete();
  }

  Future<void> _unpinMessage(String messageId) async {
    if (!isAdmin) return;
    try {
      await FirebaseFirestore.instance
          .collection('openForums')
          .doc(widget.communityId)
          .update({'pinnedMessageId': FieldValue.delete()});
      setState(() => forumData['pinnedMessageId'] = null);
      _showSnack("Message unpinned.");
    } catch (e) {
      _showSnack("Error unpinning message: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 9) MESSAGE BUBBLE (with robust long-press options)
  // ---------------------------------------------------------------------------
  Widget _buildChatBubble(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    String text = data['text'] ?? '';
    final senderId = data['senderId'] ?? '';
    final realSenderName = data['senderName'] ?? '';
    final senderPhotoUrl = data['senderPhotoUrl'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final ts = data['timestamp'] as Timestamp?;
    final messageTime =
        ts != null ? DateTime.fromMillisecondsSinceEpoch(ts.millisecondsSinceEpoch) : null;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isMe = (currentUserId == senderId);

    // Censor text if needed
    if (_censorActive && text.isNotEmpty) {
      text = _censorText(text);
    }

    // Determine displayed name based on anonymity
    final displayedName =
        _identitiesArePublic ? realSenderName : _getAnonymousNameFor(senderId);

    // If anonymous, skip showing photo
    final actualPhotoUrl = _identitiesArePublic ? senderPhotoUrl : '';

    // Build avatar
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: isDarkMode ? Colors.grey[700] : Colors.grey[400],
      backgroundImage:
          (actualPhotoUrl != null && actualPhotoUrl.isNotEmpty) ? NetworkImage(actualPhotoUrl) : null,
      child: (actualPhotoUrl == null || actualPhotoUrl.isEmpty)
          ? Icon(Icons.person, color: isDarkMode ? Colors.white : Colors.black87, size: 18)
          : null,
    );

    // Build bubble content
    final bubbleColor = isMe
        ? const Color(0xBBFC4A1A)
        : (isDarkMode ? Colors.grey[800] : Colors.grey[300]);
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bubbleColor,
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
          if (messageTime != null)
            Container(
              margin: const EdgeInsets.only(top: 6),
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('h:mm a').format(messageTime),
                style: GoogleFonts.workSans(
                  fontSize: 11,
                  color: isMe
                      ? Colors.white70
                      : (isDarkMode ? Colors.white60 : Colors.black54),
                ),
              ),
            ),
        ],
      ),
    );

    // Wrap in GestureDetector for long-press options
    return GestureDetector(
      onLongPress: () {
        _showMessageOptions(doc, isMe);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[avatar, const SizedBox(width: 8)],
            Flexible(child: bubble),
            if (isMe) ...[const SizedBox(width: 8), avatar],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  New: Show robust message options on long press.
  // ---------------------------------------------------------------------------
  void _showMessageOptions(DocumentSnapshot doc, bool isMe) {
    final data = doc.data() as Map<String, dynamic>;
    final bool pinned = data['pinned'] ?? false;
    final senderId = data['senderId'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (!isMe) ...[
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.redAccent),
                title: const Text('Report Message',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showReportMessageDialog(doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orangeAccent),
                title: const Text('Block User',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(context).pop();
                  _blockUserFromChat(senderId);
                },
              ),
            ],
            if (isMe || isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: Text(
                  isMe ? 'Delete Message' : 'Remove Message',
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteDialog(doc.id, isMe);
                },
              ),
              if (!pinned)
                ListTile(
                  leading: Icon(Icons.push_pin, color: isDarkMode ? Colors.tealAccent : Colors.blueGrey),
                  title: const Text('Pin Message',
                      style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pinMessage(doc.id);
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.push_pin_outlined, color: isDarkMode ? Colors.tealAccent : Colors.blueGrey),
                  title: const Text('Unpin Message',
                      style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _unpinMessage(doc.id);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  New: Report message flow.
  // ---------------------------------------------------------------------------
  void _showReportMessageDialog(DocumentSnapshot doc) {
    final List<String> reportCategories = [
      "Hate Speech",
      "Harassment",
      "Spam",
      "NSFW Content",
      "Impersonation",
    ];
    String selectedCategory = reportCategories.first;
    final TextEditingController additionalDetails = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Report Message"),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select a reason for reporting this message:",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedCategory,
                    icon: const Icon(Icons.arrow_drop_down),
                    onChanged: (val) {
                      if (val != null) setStateSB(() => selectedCategory = val);
                    },
                    items: reportCategories
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: additionalDetails,
                    decoration: const InputDecoration(
                      hintText: "Additional details (optional)",
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "We will review this message and take action within 24 hours.",
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _submitMessageReport(
                  doc.id,
                  selectedCategory,
                  additionalDetails.text.trim(),
                );
              },
              child: const Text("Submit Report"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitMessageReport(String messageId, String category, String details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to report.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('messageReports').add({
        'forumId': widget.communityId,
        'messageId': messageId,
        'reporterId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'category': category,
        'details': details,
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Report Received'),
          content: const Text('Thank you. We will review your report and take action within 24 hours.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report failed: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  //  New: Block user from chat.
  // ---------------------------------------------------------------------------
  Future<void> _blockUserFromChat(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to block.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'Blocked': FieldValue.arrayUnion([userId]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking user: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 10) PINNED MESSAGES DISPLAY
  // ---------------------------------------------------------------------------
  Widget _buildPinnedMessages() {
    if (_pinnedMessages.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: isDarkMode ? Colors.grey[800] : Colors.blueGrey[200],
          padding: const EdgeInsets.all(8),
          child: Text(
            'Pinned Messages',
            style: GoogleFonts.workSans(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (var doc in _pinnedMessages) _buildPinnedCard(doc),
      ],
    );
  }

  Widget _buildPinnedCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final senderName = data['senderName'] ?? '';
    final senderId = data['senderId'] ?? '';
    final pinned = data['pinned'] == true;
    final ts = data['timestamp'] as Timestamp?;
    final isMe = FirebaseAuth.instance.currentUser?.uid == senderId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildChatBubble(doc),
    );
  }

  // ---------------------------------------------------------------------------
  // 11) MESSAGES LIST
  // ---------------------------------------------------------------------------
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
        final List<Widget> messageWidgets = [];

        for (var i = 0; i < docs.length; i++) {
          final doc = docs[i];
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'] as Timestamp?;
          if (ts != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(ts.millisecondsSinceEpoch);
            final justDate = DateTime(date.year, date.month, date.day);
            if (previousDate == null || justDate != previousDate) {
              messageWidgets.add(_buildDateDivider(date));
              previousDate = justDate;
            }
          }
          messageWidgets.add(_buildChatBubble(doc));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            _buildPinnedMessages(),
            ...messageWidgets,
          ],
        );
      },
    );
  }

  Widget _buildDateDivider(DateTime date) {
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
                colors: [Color(0xFFFFAF7B), Color(0xFFD76D77)],
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
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ];
    return days[weekday - 1];
  }

  String _monthName(int month) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December"
    ];
    return months[month - 1];
  }

  // ---------------------------------------------------------------------------
  // 12) TOP BAR
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.only(top: 48, bottom: 16, left: 16, right: 16),
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.tealAccent : Colors.blueGrey,
              ),
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.workSans(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: GoogleFonts.workSans(
                    color: isDarkMode ? Colors.white54 : Colors.black38,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      color: isDarkMode ? Colors.grey[900] : Colors.white,
      padding: const EdgeInsets.only(top: 48, bottom: 16, left: 16, right: 16),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.communityName,
              style: GoogleFonts.workSans(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (isAdmin) ...[
            InkWell(
              onTap: _showForumSettingsSheet,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.settings_outlined,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
          InkWell(
            onTap: () => setState(() => _isSearching = true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.search,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 13) MESSAGE COMPOSER (sunset orange gradient for attachment & send)
  // ---------------------------------------------------------------------------
  Widget _buildBottomMessageField() {
    return Container(
      color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
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
                    color: isDarkMode ? Colors.blueGrey[400] : Colors.blueGrey[700],
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkMode ? Colors.tealAccent : Colors.blueGrey),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFfc4a1a), Color(0xFFf7b733)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.send,
                    color: isDarkMode ? Colors.black87 : Colors.white,
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------------------------------------------------------------------------
  // 14) BUILD
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
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
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
                    image: DecorationImage(image: NetworkImage(pfpUrl), fit: BoxFit.cover),
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
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white70 : Colors.black87),
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
                            color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.settings_outlined, color: isDarkMode ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    InkWell(
                      onTap: () => setState(() => isDarkMode = !isDarkMode),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
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
                                  decoration: const InputDecoration(labelText: "Name"),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      _updateForumName(_renameController.text.trim());
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
                      fallbackName.isNotEmpty ? fallbackName : widget.communityId,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        shadows: const [Shadow(color: Colors.black54, offset: Offset(2, 2), blurRadius: 4)],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
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
    final displayedName = _identitiesArePublic ? realName : _getAnonymousNameFor(senderId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(width: 1, color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.push_pin_rounded, color: isDarkMode ? Colors.orange[200] : Colors.orange[800]),
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
        final List<Widget> messageWidgets = [];

        for (var i = 0; i < docs.length; i++) {
          final doc = docs[i];
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'] as Timestamp?;
          if (ts != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(ts.millisecondsSinceEpoch);
            final justDate = DateTime(date.year, date.month, date.day);
            if (previousDate == null || justDate != previousDate) {
              messageWidgets.add(_buildDateDivider(date));
              previousDate = justDate;
            }
          }
          messageWidgets.add(_buildChatBubble(doc));
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
          }
        });

        return ListView(
          controller: _scrollController,
          padding: const EdgeInsets.only(bottom: 8),
          children: [
            _buildPinnedMessages(),
            ...messageWidgets,
          ],
        );
      },
    );
  }

  Widget _buildDayDivider(DateTime date) {
    final dayString = "${_weekdayName(date.weekday)}, ${_monthName(date.month)} ${date.day}, ${date.year}";
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(thickness: 1, color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFAF7B), Color(0xFFD76D77)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(dayString, style: GoogleFonts.workSans(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          ),
          Expanded(
            child: Divider(thickness: 1, color: isDarkMode ? Colors.grey[600] : Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  String _weekdayName(int weekday) {
    const days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
    return days[weekday - 1];
  }

  String _monthName(int month) {
    const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    return months[month - 1];
  }

  // ---------------------------------------------------------------------------
  //  New: Anonymous helper
  // ---------------------------------------------------------------------------
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
    final adjectives = ["Sneaky", "Silly", "Mighty", "Dazzling", "Funky", "Cheerful", "Whimsical", "Grumpy", "Clever", "Goofy"];
    final animals = ["Penguin", "Tiger", "Giraffe", "Octopus", "Koala", "Dragon", "Dolphin", "Narwhal", "Hippo", "Sloth"];
    final rand = Random();
    return "${adjectives[rand.nextInt(adjectives.length)]}${animals[rand.nextInt(animals.length)]}";
  }

  // ---------------------------------------------------------------------------
  //  New: Show robust message options on long-press.
  // ---------------------------------------------------------------------------
  void _showMessageOptions(DocumentSnapshot doc, bool isMe) {
    final data = doc.data() as Map<String, dynamic>;
    final bool pinned = data['pinned'] ?? false;
    final senderId = data['senderId'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (!isMe) ...[
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.redAccent),
                title: const Text('Report Message', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showReportMessageDialog(doc);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orangeAccent),
                title: const Text('Block User', style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(context).pop();
                  _blockUserFromChat(senderId);
                },
              ),
            ],
            if (isMe || isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.redAccent),
                title: Text(isMe ? 'Delete Message' : 'Remove Message', style: const TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showDeleteDialog(doc.id, isMe);
                },
              ),
              if (!pinned)
                ListTile(
                  leading: Icon(Icons.push_pin, color: isDarkMode ? Colors.tealAccent : Colors.blueGrey),
                  title: const Text('Pin Message', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pinMessage(doc.id);
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.push_pin_outlined, color: isDarkMode ? Colors.tealAccent : Colors.blueGrey),
                  title: const Text('Unpin Message', style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _unpinMessage(doc.id);
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  New: Report message flow.
  // ---------------------------------------------------------------------------
  void _showReportMessageDialog(DocumentSnapshot doc) {
    final List<String> reportCategories = ["Hate Speech", "Harassment", "Spam", "NSFW Content", "Impersonation"];
    String selectedCategory = reportCategories.first;
    final TextEditingController additionalDetails = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Report Message"),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select a reason for reporting this message:", style: TextStyle(fontSize: 14)),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedCategory,
                    icon: const Icon(Icons.arrow_drop_down),
                    onChanged: (val) {
                      if (val != null) setStateSB(() => selectedCategory = val);
                    },
                    items: reportCategories
                        .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: additionalDetails,
                    decoration: const InputDecoration(hintText: "Additional details (optional)"),
                  ),
                  const SizedBox(height: 16),
                  const Text("We will review this message and take action within 24 hours.", style: TextStyle(fontSize: 12)),
                ],
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _submitMessageReport(doc.id, selectedCategory, additionalDetails.text.trim());
              },
              child: const Text("Submit Report"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitMessageReport(String messageId, String category, String details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to report.')));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('messageReports').add({
        'forumId': widget.communityId,
        'messageId': messageId,
        'reporterId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'category': category,
        'details': details,
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Report Received'),
          content: const Text('Thank you. We will review your report and take action within 24 hours.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Report failed: $e')));
    }
  }

  // ---------------------------------------------------------------------------
  //  New: Block user from chat.
  // ---------------------------------------------------------------------------
  Future<void> _blockUserFromChat(String userId) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must be logged in to block.')));
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'Blocked': FieldValue.arrayUnion([userId]),
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked.')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error blocking user: $e')));
    }
  }

  // ---------------------------------------------------------------------------
  //  New: Delete dialog (reuse existing)
  // ---------------------------------------------------------------------------
  void _showDeleteDialog(String docId, bool isOwnMessage) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            isOwnMessage ? 'Delete Message' : 'Remove Message',
            style: GoogleFonts.workSans(color: isDarkMode ? Colors.white70 : Colors.black87),
          ),
          content: Text(
            isOwnMessage
                ? 'Are you sure you want to delete this message?'
                : 'Are you sure you want to remove this message?',
            style: GoogleFonts.workSans(color: isDarkMode ? Colors.white60 : Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.workSans(color: isDarkMode ? Colors.tealAccent : Colors.blueGrey)),
            ),
            TextButton(
              onPressed: () {
                _deleteMessage(docId);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isOwnMessage ? 'Message deleted.' : 'Message removed.')),
                );
              },
              child: Text('Delete', style: GoogleFonts.workSans(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  //  New: Delete message (reused)
  // ---------------------------------------------------------------------------
  Future<void> _deleteMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('openForums')
        .doc(widget.communityId)
        .collection('messages')
        .doc(docId)
        .delete();
  }

  // ---------------------------------------------------------------------------
  // 14) GET ANONYMOUS NAME (helper)
  // ---------------------------------------------------------------------------
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
    final adjectives = ["Sneaky", "Silly", "Mighty", "Dazzling", "Funky", "Cheerful", "Whimsical", "Grumpy", "Clever", "Goofy"];
    final animals = ["Penguin", "Tiger", "Giraffe", "Octopus", "Koala", "Dragon", "Dolphin", "Narwhal", "Hippo", "Sloth"];
    final rand = Random();
    return "${adjectives[rand.nextInt(adjectives.length)]}${animals[rand.nextInt(animals.length)]}";
  }

  // ---------------------------------------------------------------------------
  // 15) BOTTOM MESSAGE FIELD
  // ---------------------------------------------------------------------------
  Widget _buildBottomMessageField() {
    return Container(
      color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
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
                    onPressed: () => setState(() => _selectedImage = null),
                    icon: Icon(Icons.close, color: isDarkMode ? Colors.white : Colors.black87),
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
                    color: isDarkMode ? Colors.blueGrey[400] : Colors.blueGrey[700],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.attachment_rounded, color: isDarkMode ? Colors.black : Colors.white, size: 20),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _msgController,
                  style: GoogleFonts.workSans(color: isDarkMode ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.workSans(color: isDarkMode ? Colors.grey[400] : Colors.grey[600]),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[800] : Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: isDarkMode ? Colors.tealAccent : Colors.blueGrey),
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
                    gradient: const LinearGradient(
                      colors: [Color(0xFFfc4a1a), Color(0xFFf7b733)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.send, color: isDarkMode ? Colors.black87 : Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _buildFilteredChatList() {
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
      // Filter out messages from blocked users.
      final filteredDocs = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final senderId = data['senderId'] ?? '';
        return !_blockedUserIds.contains(senderId);
      }).toList();

      DateTime? previousDate;
      final List<Widget> messageWidgets = [];
      for (var i = 0; i < filteredDocs.length; i++) {
        final doc = filteredDocs[i];
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['timestamp'] as Timestamp?;
        if (ts != null) {
          final date =
              DateTime.fromMillisecondsSinceEpoch(ts.millisecondsSinceEpoch);
          final justDate = DateTime(date.year, date.month, date.day);
          if (previousDate == null || justDate != previousDate) {
            messageWidgets.add(_buildDateDivider(date));
            previousDate = justDate;
          }
        }
        messageWidgets.add(_buildChatBubble(doc));
      }
      
      // Auto-scroll to bottom when messages update.
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
        children: [
          _buildPinnedMessages(),
          ...messageWidgets,
        ],
      );
    },
  );
}

void _listenToBlockedUsers() {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots()
        .listen((docSnapshot) {
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          _blockedUserIds = List<String>.from(data?['Blocked'] ?? []);
        });
      }
    });
  }
}
