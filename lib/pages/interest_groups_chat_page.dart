import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class InterestGroupChatPage extends StatefulWidget {
  final String communityId;
  final String communityName;
  final String? groupPfpUrl;

  const InterestGroupChatPage({
    Key? key,
    required this.communityId,
    required this.communityName,
    this.groupPfpUrl,
  }) : super(key: key);

  @override
  State<InterestGroupChatPage> createState() => _InterestGroupChatPageState();
}

class _InterestGroupChatPageState extends State<InterestGroupChatPage>
    with TickerProviderStateMixin {
  // ---------------------------------------------------------------------------
  //  1) BASIC STATES & CONTROLLERS
  // ---------------------------------------------------------------------------
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isAdmin = false;
  bool _isUploadingImage = false;
  bool _isSearching = false;
  bool _isDarkMode = true; // toggles dark-ish UI

  // Searching
  String _searchQuery = '';

  // Group profile fields
  String? _groupPfpUrl;
  String _pfpType = '';
  String _pfpText = '';
  String _bgColorHex = '';

  // For pinned messages
  List<DocumentSnapshot> _pinnedMessages = [];

  // For Blocking Users
  List<String> _blockedUserIds = [];

  // For animations
  late AnimationController _heroController;
  late Animation<double> _heroAnimation;
  late AnimationController _fadeController;

  // For image picking
  final ImagePicker _imagePicker = ImagePicker();
  File? _selectedImage;

  // ---------------------------------------------------------------------------
  //  2) CENSOR LOGIC
  // ---------------------------------------------------------------------------
  bool _censorActive = false;

  void _listenToCensor() {
    FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final bool isCensorOn = data['censorActive'] == true;
      setState(() => _censorActive = isCensorOn);
    });
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

  Future<void> _toggleCensor(bool newVal) async {
    await FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .update({'censorActive': newVal});
  }

  final List<String> _badWords = [
    'fuck','fuckyou','fucking','shit','shitty','ass','asshole','jackass','dumbass',
    'bitch','bitchy','bastard','dick','dicks','dickhead','cock','pussy','cunt','whore','slut','slutty',
    'douche','douchebag','motherfucker','motherfuckin','son of a bitch','goddamn','goddamned','damn','damned',
    'piss','pissed','crapping','blowjob','bj','handjob','rimjob','dildo','vibrator','anal','butthole','bust a nut',
    'jizz','ho','hoe','nigger','nigga','spic','beaner','kike','chink','gook','wetback','raghead','towelhead','jap',
    'cracker','fag','faggot','dyke','homo','tranny','queer','retard','retarded','spazz','spastic','cripple','christfag',
    'bible-basher','infidel','heathen','harlot','slant','slope','gypsy','kill yourself','kys','die in a hole','die in a fire',
    'i\'ll kill you','i\'ll murder you','hang yourself',
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
  //  3) INIT & DISPOSE
  // ---------------------------------------------------------------------------
  @override
  void initState() {
    super.initState();

    // Check admin + fetch group data
    _checkIfAdmin();
    _fetchGroupData();

    // Listen for censor changes
    _listenToCensor();

    // Listen for blocked users updates
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _heroController.forward();
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _heroController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  //  4) FETCH GROUP DATA + ADMIN CHECK
  // ---------------------------------------------------------------------------
  Future<void> _fetchGroupData() async {
    if (widget.groupPfpUrl != null) {
      setState(() => _groupPfpUrl = widget.groupPfpUrl);
    }

    final doc = await FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      setState(() {
        _groupPfpUrl ??= data['pfpUrl'] ?? '';
        _pfpType = data['pfpType'] ?? '';
        _pfpText = data['pfpText'] ?? '';
        _bgColorHex = data['backgroundColor'] ?? '';
      });
    }
  }

  Future<void> _checkIfAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final adminDoc = await FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .collection('admins')
        .doc(user.uid)
        .get();

    if (adminDoc.exists) {
      setState(() => _isAdmin = true);
    }
  }

  // ---------------------------------------------------------------------------
  //  5) SENDING MESSAGES
  // ---------------------------------------------------------------------------
  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to send messages.')),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImage == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final senderName = userDoc.data()?['fullName']?.toString().trim() ?? '';
    final senderPhotoUrl = userDoc.data()?['photoUrl'] ?? '';

    String? imageUrl;
    if (_selectedImage != null) {
      setState(() => _isUploadingImage = true);
      try {
        final fileName =
            'chatImages/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final ref = FirebaseStorage.instance.ref().child(fileName);
        await ref.putFile(_selectedImage!);
        imageUrl = await ref.getDownloadURL();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
        setState(() {
          _isUploadingImage = false;
          _selectedImage = null;
        });
        return;
      }
      setState(() {
        _isUploadingImage = false;
        _selectedImage = null;
      });
    }

    await FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .collection('messages')
        .add({
      'text': text,
      'senderUid': user.uid,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'pinned': false,
      'type': (imageUrl != null) ? 'image' : 'text',
      if (imageUrl != null) 'imageUrl': imageUrl,
    });

    _messageController.clear();
    _scrollToBottom();
  }

  // ---------------------------------------------------------------------------
  //  6) IMAGE PICKING
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
      setState(() => _selectedImage = File(pickedFile.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  //  7) ADMIN ACTIONS: DELETE / PIN
  // ---------------------------------------------------------------------------
  Future<void> _deleteMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .collection('messages')
        .doc(docId)
        .delete();
  }

  Future<void> _pinMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .collection('messages')
        .doc(docId)
        .update({'pinned': true});
  }

  Future<void> _unpinMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .collection('messages')
        .doc(docId)
        .update({'pinned': false});
  }

  void _showDeleteDialog(String docId, bool isOwnMessage) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
          title: Text(
            isOwnMessage ? 'Delete Message' : 'Remove Message',
            style: GoogleFonts.workSans(
              color: _isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          content: Text(
            isOwnMessage
                ? 'Are you sure you want to delete this message?'
                : 'Are you sure you want to remove this message?',
            style: GoogleFonts.workSans(
              color: _isDarkMode ? Colors.white60 : Colors.black54,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.workSans(
                  color: _isDarkMode ? Colors.tealAccent : Colors.blueGrey,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                _deleteMessage(docId);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isOwnMessage ? 'Message deleted.' : 'Message removed.',
                    ),
                  ),
                );
              },
              child: Text(
                'Delete',
                style: GoogleFonts.workSans(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  //  8) DAY DIVIDER + SEARCH HIGHLIGHT
  // ---------------------------------------------------------------------------
  Widget _buildDateDivider(DateTime date) {
    final dayString = DateFormat.yMMMd().format(date);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1,
              color: _isDarkMode ? Colors.grey[700] : Colors.grey[400],
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dayString,
              style: GoogleFonts.workSans(color: Colors.white, fontSize: 12),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: _isDarkMode ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
        ],
      ),
    );
  }

  InlineSpan _highlightSearchResult(String text) {
    if (_censorActive) {
      text = _censorText(text);
    }

    if (_searchQuery.isEmpty) {
      return TextSpan(
        text: text,
        style: GoogleFonts.workSans(
          color: _isDarkMode ? Colors.white : Colors.black87,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: GoogleFonts.workSans(
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: GoogleFonts.workSans(
            color: _isDarkMode ? Colors.white : Colors.black87,
          ),
        ));
      }
      final match = text.substring(index, index + _searchQuery.length);
      spans.add(
        TextSpan(
          text: match,
          style: GoogleFonts.workSans(
            fontWeight: FontWeight.bold,
            color: _isDarkMode ? Colors.tealAccent : Colors.blueGrey,
          ),
        ),
      );
      start = index + _searchQuery.length;
    }

    return TextSpan(children: spans);
  }

  // ---------------------------------------------------------------------------
  //  9) MESSAGE BUBBLE
  // ---------------------------------------------------------------------------
  Widget _buildMessageBubble({
    required DocumentSnapshot doc,
    required String senderName,
    required bool isMe,
    required bool showName,
    required Timestamp? timestamp,
    required bool pinned,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] ?? 'text';
    var text = data['text'] ?? '';
    final imageUrl = data['imageUrl'];
    final profileImageUrl = data['senderPhotoUrl'] ?? '';
    final messageTime = timestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
        : null;

    Widget pinnedIcon() => Positioned(
          top: 6,
          right: 6,
          child: Icon(
            Icons.push_pin,
            color: Colors.amber[300],
            size: 16,
          ),
        );

    // If it's me, use a semi-transparent deep sunset orange; otherwise use a dark/light grey.
    final bubbleColor = isMe
        ? const Color(0xBBFC4A1A)
        : (_isDarkMode ? Colors.grey[800] : Colors.grey[300]);

    Widget bubbleContent() {
      return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName && senderName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      senderName,
                      style: GoogleFonts.workSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: (isMe || _isDarkMode)
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ),
                if (type == 'text' && text.isNotEmpty)
                  RichText(
                    text: _highlightSearchResult(text),
                  ),
                if (type == 'image' && imageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: Colors.grey.shade300,
                        height: 150,
                        child: Center(
                          child: Text(
                            'Image Error',
                            style: GoogleFonts.workSans(
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ),
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
                            : (_isDarkMode ? Colors.white60 : Colors.black54),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (pinned) pinnedIcon(),
        ],
      );
    }

    return GestureDetector(
      onLongPress: () {
        _showMessageOptions(doc, isMe);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 20,
                backgroundColor: pinned ? Colors.tealAccent : Colors.grey.shade800,
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: (profileImageUrl.isEmpty && senderName.isNotEmpty)
                    ? Text(
                        senderName[0].toUpperCase(),
                        style: GoogleFonts.workSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: bubbleContent(),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: pinned ? Colors.tealAccent : Colors.grey.shade800,
                backgroundImage: profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
                child: (profileImageUrl.isEmpty && senderName.isNotEmpty)
                    ? Text(
                        senderName[0].toUpperCase(),
                        style: GoogleFonts.workSans(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  New: Show message options on long-press.
  // ---------------------------------------------------------------------------
  void _showMessageOptions(DocumentSnapshot doc, bool isMe) {
    final data = doc.data() as Map<String, dynamic>;
    final bool pinned = data['pinned'] ?? false;
    final senderUid = data['senderUid'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
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
                  _blockUserFromChat(senderUid);
                },
              ),
            ],
            if (isMe || _isAdmin) ...[
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
                  leading: Icon(Icons.push_pin,
                      color: _isDarkMode ? Colors.tealAccent : Colors.blueGrey),
                  title: const Text('Pin Message',
                      style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pinMessage(doc.id);
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.push_pin_outlined,
                      color: _isDarkMode ? Colors.tealAccent : Colors.blueGrey),
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

  Future<void> _submitMessageReport(
      String messageId, String category, String details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to report.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('messageReports').add({
        'groupId': widget.communityId,
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
          content: const Text(
              'Thank you. We will review your report and take action within 24 hours.'),
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
          color: _isDarkMode ? Colors.grey[800] : Colors.blueGrey[200],
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
    final senderUid = data['senderUid'] ?? '';
    final pinned = data['pinned'] == true;
    final timestamp = data['timestamp'] as Timestamp?;
    final user = FirebaseAuth.instance.currentUser;
    final isMe = (user != null && user.uid == senderUid);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(
          color: _isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: _buildMessageBubble(
        doc: doc,
        senderName: senderName,
        isMe: isMe,
        showName: true,
        timestamp: timestamp,
        pinned: pinned,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 11) MESSAGES LIST
  // ---------------------------------------------------------------------------
Widget _buildMessagesList() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('interestGroups')
        .doc(widget.communityId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Text('Error loading messages'));
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }

      final docs = snapshot.data?.docs ?? [];
      if (docs.isEmpty) {
        return Center(
          child: Text(
            'No messages yet. Start the conversation!',
            style: GoogleFonts.workSans(
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
        );
      }

      // Pinned messages remain as-is.
      _pinnedMessages = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return (data['pinned'] ?? false) == true;
      }).toList();

      // Filter normal messages: exclude pinned and messages from blocked users.
      List<DocumentSnapshot> normalMessages = docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final senderUid = data['senderUid'] ?? '';
        return (data['pinned'] ?? false) == false && !_blockedUserIds.contains(senderUid);
      }).toList();

      // Apply search filter if a query is active.
      if (_searchQuery.isNotEmpty) {
        normalMessages = normalMessages.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final msgType = data['type'] ?? 'text';
          final msgText = data['text'] ?? '';
          if (msgType == 'image') return false;
          return msgText.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
      }

      final List<Widget> messageWidgets = [];
      String? lastDateStr;

      for (int i = 0; i < normalMessages.length; i++) {
        final doc = normalMessages[i];
        final data = doc.data() as Map<String, dynamic>;
        final senderUid = data['senderUid'] ?? '';
        final senderName = data['senderName'] ?? '';
        final pinned = data['pinned'] == true;
        final timestamp = data['timestamp'] as Timestamp?;

        final user = FirebaseAuth.instance.currentUser;
        final isMe = (user != null && user.uid == senderUid);

        bool showName = true;
        if (i > 0) {
          final prevDoc = normalMessages[i - 1];
          final prevData = prevDoc.data() as Map<String, dynamic>;
          if (prevData['senderUid'] == senderUid) {
            showName = false;
          }
        }

        if (timestamp != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(
            timestamp.millisecondsSinceEpoch,
          );
          final currentDateStr = DateFormat('yyyy-MM-dd').format(date);
          if (currentDateStr != lastDateStr) {
            messageWidgets.add(_buildDateDivider(date));
            lastDateStr = currentDateStr;
          }
        }

        messageWidgets.add(
          _buildMessageBubble(
            doc: doc,
            senderName: senderName,
            isMe: isMe,
            showName: showName,
            timestamp: timestamp,
            pinned: pinned,
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
        padding: const EdgeInsets.only(bottom: 4),
        children: [
          _buildPinnedMessages(),
          ...messageWidgets,
        ],
      );
    },
  );
}

  // ---------------------------------------------------------------------------
  // 12) TOP BAR
  // ---------------------------------------------------------------------------
  void _showCensorToggleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) {
        return SafeArea(
          child: SwitchListTile(
            activeColor: Colors.tealAccent,
            inactiveThumbColor: Colors.grey,
            title: Text(
              'Censor Chat',
              style: GoogleFonts.workSans(
                color: _isDarkMode ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            value: _censorActive,
            onChanged: (val) {
              Navigator.of(context).pop();
              _toggleCensor(val);
            },
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.only(top: 48, bottom: 16, left: 16, right: 16),
        color: _isDarkMode ? Colors.grey[900] : Colors.white,
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: _isDarkMode ? Colors.tealAccent : Colors.blueGrey,
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
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: GoogleFonts.workSans(
                    color: _isDarkMode ? Colors.white54 : Colors.black38,
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
      color: _isDarkMode ? Colors.grey[900] : Colors.white,
      padding: const EdgeInsets.only(top: 48, bottom: 16, left: 16, right: 16),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back,
                color: _isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.communityName,
              style: GoogleFonts.workSans(
                color: _isDarkMode ? Colors.white : Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_isAdmin) ...[
            InkWell(
              onTap: _showCensorToggleSheet,
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _isDarkMode ? Colors.grey[800] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.shield_outlined,
                  color: _censorActive
                      ? Colors.redAccent
                      : (_isDarkMode ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ],
          InkWell(
            onTap: () => setState(() => _isSearching = true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isDarkMode ? Colors.grey[800] : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.search,
                color: _isDarkMode ? Colors.white70 : Colors.black87,
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
  Widget _buildMessageComposer() {
    return Container(
      color: _isDarkMode ? Colors.grey[850] : Colors.grey[100],
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
                        _selectedImage!,
                        height: 120,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => setState(() => _selectedImage = null),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              InkWell(
                onTap: _pickImage,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFfc4a1a),
                        Color(0xFFf7b733),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.attachment_rounded,
                    size: 20,
                    color: _isDarkMode ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  style: GoogleFonts.workSans(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: GoogleFonts.workSans(
                      color: _isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    filled: true,
                    fillColor: _isDarkMode ? Colors.grey[800] : Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFfc4a1a),
                        Color(0xFFf7b733),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.send,
                    color: _isDarkMode ? Colors.black87 : Colors.white,
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

  // ---------------------------------------------------------------------------
  // 14) BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF1E1E1E) : Colors.grey[100],
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeController,
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(child: _buildMessagesList()),
              _buildMessageComposer(),
            ],
          ),
        ),
      ),
    );
  }
}
