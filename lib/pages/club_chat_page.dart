import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/scheduler.dart';

class ClubChatPage extends StatefulWidget {
  final String clubId;
  final String clubName;
  final String? clubPfpUrl;

  const ClubChatPage({
    Key? key,
    required this.clubId,
    required this.clubName,
    this.clubPfpUrl,
  }) : super(key: key);

  @override
  State<ClubChatPage> createState() => _ClubChatPageState();
}

class _ClubChatPageState extends State<ClubChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();


  bool _isAdmin = false;
  bool _isTyping = false;
  bool _isUploadingImage = false;

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

  bool _didMarkHere = false;
  List<DocumentSnapshot> _pinnedMessages = [];

  String? _clubPfpUrl;

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool _attendanceActive = false;
  bool _censorActive = false; // controls chat censorship

  // For potential attendance usage
  List<String> _attendees = [];

  List<String> _blockedUserIds = [];


  // ---------------------------------------------------------------------------
  // THEME COLORS & BUBBLE STYLING
  // ---------------------------------------------------------------------------
  final Color scaffoldBg = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF00BFA6);

  // “My” message bubble color
  final Color myBubbleColor = Colors.blueGrey;
  // “Other” message bubble color
  final Color otherBubbleColor = Colors.grey;

  // Pinned icon color
  final Color pinnedIconColor = const Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _checkIfAdmin(); // checks admin from clubs/{clubId}/admins/{uid}
    _fetchClubPfpIfNeeded();
    _listenToAttendance();
    _listenToCensor(); // watch for changes to "censorActive" in Firestore
    _listenToBlockedUsers(); 
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 1) FETCH CLUB PFP + ADMIN CHECK
  // ---------------------------------------------------------------------------
  Future<void> _fetchClubPfpIfNeeded() async {
    // Only fetch the club's pfp if not passed in the constructor
    if (widget.clubPfpUrl != null) {
      setState(() => _clubPfpUrl = widget.clubPfpUrl);
      return;
    }
    final clubDoc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .get();

    if (clubDoc.exists) {
      final data = clubDoc.data();
      if (data != null && data['pfpUrl'] != null) {
        setState(() => _clubPfpUrl = data['pfpUrl'] as String);
      }
    }
  }

  /// Checks admin status by looking for a doc at: clubs/{clubId}/admins/{userUid}
  Future<void> _checkIfAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final adminDoc = await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('admins')
        .doc(user.uid)
        .get();

    if (adminDoc.exists) {
      setState(() => _isAdmin = true);
    }
  }

  // ---------------------------------------------------------------------------
  // 2) SENDING MESSAGES
  // ---------------------------------------------------------------------------
  void _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to send messages.')),
      );
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    final senderName = userDoc.data()?['fullName']?.toString().trim() ?? '';
    final senderPhotoUrl = userDoc.data()?['photoUrl']?.toString().trim() ?? '';

    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('messages')
        .add({
      'text': text,
      'senderUid': user.uid,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'pinned': false,
      'type': 'text',
    });

    _messageController.clear();
    setState(() => _isTyping = false);
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: scaffoldBg,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.camera_alt, color: accentColor),
              title: const Text(
                'Take a photo',
                style: TextStyle(color: Colors.white70),
              ),
              onTap: () {
                Navigator.of(context).pop();
                _getImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: accentColor),
              title: const Text(
                'Choose from Gallery',
                style: TextStyle(color: Colors.white70),
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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    setState(() => _isUploadingImage = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final senderName = userDoc.data()?['fullName']?.toString().trim() ?? '';
      final senderPhotoUrl = userDoc.data()?['photoUrl']?.toString().trim() ?? '';

      final fileName = 'chatImages/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);

      final imageUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('messages')
          .add({
        'imageUrl': imageUrl,
        'senderUid': user.uid,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'pinned': false,
        'type': 'image',
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading image: $e')),
      );
    }

    setState(() => _isUploadingImage = false);
    _scrollToBottom();
  }

  // ---------------------------------------------------------------------------
  // 3) ADMIN ACTIONS: DELETE / PIN
  // ---------------------------------------------------------------------------
  Future<void> _deleteMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('messages')
        .doc(docId)
        .delete();
  }

  Future<void> _pinMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('messages')
        .doc(docId)
        .update({'pinned': true});
  }

  Future<void> _unpinMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('messages')
        .doc(docId)
        .update({'pinned': false});
  }

  void _showDeleteDialog(String docId, bool isOwnMessage) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: scaffoldBg,
          title: Text(
            isOwnMessage ? 'Delete Message' : 'Remove Message',
            style: const TextStyle(color: Colors.white70),
          ),
          content: Text(
            isOwnMessage
                ? 'Are you sure you want to delete this message?'
                : 'Are you sure you want to remove this message?',
            style: const TextStyle(color: Colors.white60),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: accentColor)),
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
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 4) DATE DIVIDER + SEARCH HIGHLIGHT
  // ---------------------------------------------------------------------------
  Widget _buildDateDivider(DateTime date) {
    final formattedDate = DateFormat.yMMMd().format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              thickness: 1,
              color: Colors.grey.shade800,
              endIndent: 6,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFAF7B), Color(0xFFD76D77)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              formattedDate,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: Colors.grey.shade800,
              indent: 6,
            ),
          ),
        ],
      ),
    );
  }

  InlineSpan _highlightSearchResult(String text) {
    if (_searchQuery.isEmpty) {
      return TextSpan(text: text);
    }
    final lowerText = text.toLowerCase();
    final lowerQuery = _searchQuery.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      final match = text.substring(index, index + _searchQuery.length);
      spans.add(
        TextSpan(
          text: match,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: accentColor,
          ),
        ),
      );
      start = index + _searchQuery.length;
    }

    return TextSpan(children: spans);
  }

  // ---------------------------------------------------------------------------
  // 5) CENSOR LOGIC
  // ---------------------------------------------------------------------------
  final List<String> _badWords = [
    'fuck', 'shit', 'ass', 'bitch', 'bastard', 'dick'
    // Add more as needed...
  ];

  final List<String> _cuteWords = [
    'bubbles', 'hugs', 'kittens', 'puppies', 'rainbows'
    // Add more as needed...
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
  // 6) MESSAGE BUBBLE (with robust long-press options)
  // ---------------------------------------------------------------------------
  Widget _buildMessageBubble({
    required DocumentSnapshot doc,
    required String senderName,
    required bool isMe,
    required bool showName,
    required Timestamp? timestamp,
    required bool pinned,
    required String senderPhotoUrl,
  }) {
    final data = doc.data() as Map<String, dynamic>;
    final type = data['type'] ?? 'text';
    final originalText = data['text'];
    final imageUrl = data['imageUrl'];
    final messageTime = (timestamp != null)
        ? DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch)
        : null;

    final Color bubbleColor = isMe ? Colors.blueGrey[700]! : Colors.grey[800]!;
    final Color textColor = Colors.white;

    // If text, censor it if _censorActive == true
    String displayText = '';
    if (type == 'text' && originalText != null) {
      displayText = _censorActive ? _censorText(originalText) : originalText;
    }

    Widget pinnedIconWidget() => Positioned(
          top: 6,
          right: 6,
          child: Icon(
            Icons.push_pin,
            color: pinnedIconColor,
            size: 16,
          ),
        );

    Widget bubbleContent() {
      return Container(
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (showName && senderName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: textColor,
                        ),
                      ),
                    ),
                  if (type == 'text' && displayText.isNotEmpty)
                    DefaultTextStyle(
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.2,
                      ),
                      child: RichText(
                        text: _highlightSearchResult(displayText),
                      ),
                    ),
                  if (type == 'image' && imageUrl != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade300,
                            height: 150,
                            child: const Center(child: Text('Image Error')),
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
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (pinned) pinnedIconWidget(),
          ],
        ),
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
                backgroundColor: Colors.grey.shade800,
                backgroundImage: (senderPhotoUrl.isNotEmpty)
                    ? NetworkImage(senderPhotoUrl)
                    : null,
                child: (senderPhotoUrl.isEmpty && senderName.isNotEmpty)
                    ? Text(
                        senderName[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: bubbleContent(),
              ),
            ],
            if (isMe) ...[
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: bubbleContent(),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: (senderPhotoUrl.isNotEmpty)
                    ? NetworkImage(senderPhotoUrl)
                    : null,
                child: (senderPhotoUrl.isEmpty && senderName.isNotEmpty)
                    ? Text(
                        senderName[0].toUpperCase(),
                        style: const TextStyle(
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

  /// New: Show a robust bottom sheet of options when a message is long-pressed.
  void _showMessageOptions(DocumentSnapshot doc, bool isMe) {
    final data = doc.data() as Map<String, dynamic>;
    final bool pinned = data['pinned'] ?? false;
    final senderUid = data['senderUid'] ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: scaffoldBg,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.redAccent),
                title: const Text('Report Message',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(context).pop();
                  _showReportMessageDialog(doc);
                },
              ),
            if (!isMe)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.orangeAccent),
                title: const Text('Block User',
                    style: TextStyle(color: Colors.white70)),
                onTap: () {
                  Navigator.of(context).pop();
                  _blockUserFromChat(senderUid);
                },
              ),
            if (isMe || _isAdmin)
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
            if (isMe || _isAdmin)
              if (!pinned)
                ListTile(
                  leading: Icon(Icons.push_pin, color: accentColor),
                  title: const Text('Pin Message',
                      style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _pinMessage(doc.id);
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.push_pin_outlined, color: accentColor),
                  title: const Text('Unpin Message',
                      style: TextStyle(color: Colors.white70)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _unpinMessage(doc.id);
                  },
                ),
          ],
        ),
      ),
    );
  }

  /// New: Report message flow.
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
                    "We will review this message and take appropriate action within 24 hours.",
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
        'clubId': widget.clubId,
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

  /// New: Block user from chat – adds the sender’s uid to current user’s "Blocked" field.
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
      // Optionally, filter out messages from blocked users.
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking user: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 7) PINNED MESSAGES
  // ---------------------------------------------------------------------------
  Widget _buildPinnedMessages() {
    if (_pinnedMessages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          color: Colors.black54,
          padding: const EdgeInsets.all(8),
          child: const Text(
            'Pinned Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        for (var doc in _pinnedMessages)
          Builder(builder: (context) {
            final data = doc.data() as Map<String, dynamic>;
            final senderName = data['senderName'] ?? '';
            final pinned = data['pinned'] == true;
            final timestamp = data['timestamp'] as Timestamp?;
            final senderUid = data['senderUid'] ?? '';
            final senderPhotoUrl = data['senderPhotoUrl'] ?? '';
            final user = FirebaseAuth.instance.currentUser;
            final isMe = (user != null && user.uid == senderUid);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade700),
              ),
              child: _buildMessageBubble(
                doc: doc,
                senderName: senderName,
                isMe: isMe,
                showName: true,
                timestamp: timestamp,
                pinned: pinned,
                senderPhotoUrl: senderPhotoUrl,
              ),
            );
          }),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 8) MAIN MESSAGES LIST
  // ---------------------------------------------------------------------------
  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
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
          return const Center(
            child: Text(
              'No messages yet. Start the conversation!',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        // Separate pinned vs normal
        _pinnedMessages = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['pinned'] ?? false) == true;
        }).toList();

        List<DocumentSnapshot> normalMessages = docs.where((doc) {
  final data = doc.data() as Map<String, dynamic>;
  final senderUid = data['senderUid'] ?? '';
  // Exclude messages that are pinned or from blocked users.
  return (data['pinned'] ?? false) == false && !_blockedUserIds.contains(senderUid);
}).toList();

        if (_searchQuery.isNotEmpty) {
          normalMessages = normalMessages.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final text = data['text'] ?? '';
            final type = data['type'] ?? 'text';
            if (type == 'image') return false;
            return text.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
        }

        SchedulerBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        final List<Widget> messageWidgets = [];
        String? lastMessageDateStr;

        for (int i = 0; i < normalMessages.length; i++) {
          final doc = normalMessages[i];
          final data = doc.data() as Map<String, dynamic>;
          final senderName = data['senderName'] ?? '';
          final senderUid = data['senderUid'] ?? '';
          final pinned = data['pinned'] == true;
          final timestamp = data['timestamp'] as Timestamp?;
          final senderPhotoUrl = data['senderPhotoUrl'] ?? '';

          final user = FirebaseAuth.instance.currentUser;
          final isMe = (user != null && user.uid == senderUid);

          bool showName = true;
          if (i > 0) {
            final prevDoc = normalMessages[i - 1];
            final prevData = prevDoc.data() as Map<String, dynamic>;
            final prevSenderUid = prevData['senderUid'] ?? '';
            if (prevSenderUid == senderUid) {
              showName = false;
            }
          }

          String currentDateStr = '';
          if (timestamp != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(
              timestamp.millisecondsSinceEpoch,
            );
            currentDateStr = DateFormat('yyyy-MM-dd').format(date);
            if (currentDateStr != lastMessageDateStr) {
              messageWidgets.add(_buildDateDivider(date));
              lastMessageDateStr = currentDateStr;
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
              senderPhotoUrl: senderPhotoUrl,
            ),
          );
        }

        return ListView(
          controller: _scrollController,
          children: [
            _buildPinnedMessages(),
            ...messageWidgets,
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 9) ATTENDANCE
  // ---------------------------------------------------------------------------
  void _listenToAttendance() {
    FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final bool isActive = data['attendanceActive'] == true;
      setState(() => _attendanceActive = isActive);
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .collection('attendance')
        .doc(user.uid)
        .snapshots()
        .listen((docSnap) {
      if (docSnap.exists) {
        setState(() => _didMarkHere = true);
      } else {
        setState(() => _didMarkHere = false);
      }
    });
  }

  Future<void> _showAttendanceList() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Show attendance list - not implemented.')),
    );
  }

  // ---------------------------------------------------------------------------
  // 10) CENSOR LOGIC: READ + TOGGLE
  // ---------------------------------------------------------------------------
  void _listenToCensor() {
    FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data()!;
      final bool isCensorOn = data['censorActive'] == true;
      setState(() => _censorActive = isCensorOn);
    });
  }

  Future<void> _toggleCensor() async {
    final docRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId);

    await docRef.update({'censorActive': !_censorActive});
  }

  // ---------------------------------------------------------------------------
  // 11) TOP BAR WITH SEARCH
  // ---------------------------------------------------------------------------
  Widget _buildTopBar() {
    if (_isSearching) {
      return Container(
        padding: const EdgeInsets.only(top: 60, bottom: 16, left: 16, right: 16),
        color: scaffoldBg,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: accentColor),
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
                style: const TextStyle(color: Colors.white),
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  hintStyle: TextStyle(color: Colors.white54),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.only(top: 60, bottom: 16, left: 16, right: 16),
        color: scaffoldBg,
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: accentColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu_open, color: accentColor),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey.shade800,
              backgroundImage:
                  (_clubPfpUrl != null) ? NetworkImage(_clubPfpUrl!) : null,
              child: (_clubPfpUrl == null)
                  ? Icon(Icons.groups, color: accentColor)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.clubName,
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _isSearching = true),
              icon: Icon(Icons.search, color: accentColor),
            ),
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 12) SIDE DRAWER
  // ---------------------------------------------------------------------------
  Widget _buildSideDrawer() {
    return Drawer(
      backgroundColor: scaffoldBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: scaffoldBg,
            height: 140,
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 60),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage:
                      (_clubPfpUrl != null) ? NetworkImage(_clubPfpUrl!) : null,
                  child: (_clubPfpUrl == null)
                      ? Icon(Icons.groups, color: accentColor, size: 30)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.clubName,
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (_isAdmin)
            ListTile(
              leading: Icon(Icons.people_alt_outlined, color: accentColor),
              title: const Text(
                'Attendees',
                style: TextStyle(color: Colors.white),
              ),
              onTap: _showAttendanceList,
            ),
          if (_isAdmin)
            SwitchListTile(
              activeColor: accentColor,
              inactiveThumbColor: Colors.grey,
              title: const Text(
                'Censor Chat',
                style: TextStyle(color: Colors.white),
              ),
              value: _censorActive,
              onChanged: (_) => _toggleCensor(),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              '© 2025 Ragtag Social LLC. All Rights Reserved.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 13) TYPING INDICATOR
  // ---------------------------------------------------------------------------
  Widget _buildTypingIndicator() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isTyping
          ? Container(
              key: const ValueKey('typingIndicator'),
              padding: const EdgeInsets.only(bottom: 6),
              child: Center(
                child: Text(
                  'Typing…',
                  style: TextStyle(
                    color: accentColor,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          : const SizedBox(key: ValueKey('emptyIndicator')),
    );
  }

  // ---------------------------------------------------------------------------
  // 14) MESSAGE COMPOSER
  // ---------------------------------------------------------------------------
  Widget _buildMessageComposer() {
    return Container(
      decoration: BoxDecoration(color: Colors.grey.shade900),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SafeArea(
        child: Row(
          children: [
            if (_isUploadingImage)
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                onPressed: _pickImage,
                icon: const Icon(Icons.attach_file),
                color: accentColor,
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                textInputAction: TextInputAction.send,
                onChanged: (val) {
                  if (val.isNotEmpty && !_isTyping) {
                    setState(() => _isTyping = true);
                  } else if (val.isEmpty && _isTyping) {
                    setState(() => _isTyping = false);
                  }
                },
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  hintStyle: const TextStyle(color: Colors.white54),
                  fillColor: Colors.grey.shade800,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sendMessage,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 15) OPTIONAL FUN FEATURES
  // ---------------------------------------------------------------------------
  Widget _buildFunFeaturesRow() {
    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // 16) SCROLL
  // ---------------------------------------------------------------------------
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildSideDrawer(),
      backgroundColor: scaffoldBg,
      body: Column(
        children: [
          _buildTopBar(),
          _buildTypingIndicator(),
          _buildFunFeaturesRow(),
          Expanded(child: _buildMessagesList()),
          _buildMessageComposer(),
        ],
      ),
    );
  }
}
