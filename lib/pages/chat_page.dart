import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatPage extends StatefulWidget {
  final String chatId;
  final String otherUserId;
  final String otherUserName;
  final String otherUserPhotoUrl;

  const ChatPage({
    Key? key,
    required this.chatId,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserPhotoUrl,
  }) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ---------------------------------------------------------------------------
  // COLOR SCHEME
  // ---------------------------------------------------------------------------
  final Color scaffoldBg = const Color(0xFF1E1E1E);
  final Color accentColor = const Color(0xFF00BFA6);

  // “My” message bubble color
  final Color myBubbleColor = Colors.blueGrey;
  // “Other” message bubble color
  final Color otherBubbleColor = Colors.grey;

  // Pinned icon
  final Color pinnedIconColor = const Color(0xFFFFD700);

  // ---------------------------------------------------------------------------
  // STATE & CONTROLLERS
  // ---------------------------------------------------------------------------
  final _auth = FirebaseAuth.instance;
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isTyping = false;
  bool _isAdmin = false;
  bool _isUploadingImage = false;

  List<DocumentSnapshot> _pinnedMessages = [];
  List<DocumentSnapshot> _normalMessages = [];
  List<String> _blockedUserIds = [];

  @override
  void initState() {
    super.initState();
    _checkIfAdmin();
    _listenToBlockedUsers();
  }

  @override
  void dispose() {
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 1) CHECK IF ADMIN (EXAMPLE LOGIC)
  // ---------------------------------------------------------------------------
  Future<void> _checkIfAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final adminDoc = await FirebaseFirestore.instance
        .collection('admins')
        .doc(user.uid)
        .get();
    if (adminDoc.exists) {
      setState(() => _isAdmin = true);
    }
  }

  // ---------------------------------------------------------------------------
  // 2) LISTEN TO BLOCKED USERS
  // ---------------------------------------------------------------------------
  void _listenToBlockedUsers() {
    final currentUser = _auth.currentUser;
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

  // ---------------------------------------------------------------------------
  // 3) BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _buildDarkAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessagesList()),
          _buildTypingIndicator(),
          _buildInputRow(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4) DARK APP BAR + 3‐DOT MENU (REPORT & BLOCK)
  // ---------------------------------------------------------------------------
  AppBar _buildDarkAppBar() {
    return AppBar(
      backgroundColor: Colors.black87,
      elevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // The other user’s avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey[800],
            backgroundImage: widget.otherUserPhotoUrl.isNotEmpty
                ? NetworkImage(widget.otherUserPhotoUrl)
                : null,
            child: widget.otherUserPhotoUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          // The other user’s name
          Text(
            widget.otherUserName,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: _showMoreMenu,
          icon: const Icon(Icons.more_vert, color: Colors.white),
        ),
      ],
    );
  }

  /// Updated “More” menu: now shows both REPORT and BLOCK options.
  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _showReportDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "REPORT",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _confirmBlockDialog();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black.withOpacity(0.6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "BLOCK",
                  style: TextStyle(
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 5) MESSAGES LIST (PINNED + NORMAL, FILTERING BLOCKED)
  // ---------------------------------------------------------------------------
  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .orderBy('timestamp', descending: false) // oldest first
          .snapshots(),
      builder: (_, snapshot) {
        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text(
              "No messages yet...",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }

        // Separate pinned from normal messages.
        _pinnedMessages = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['pinned'] == true;
        }).toList();

        _normalMessages = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final senderId = data['senderId'] ?? '';
          // Filter out messages from blocked users (if not sent by current user)
          if (senderId != _auth.currentUser?.uid &&
              _blockedUserIds.contains(senderId)) {
            return false;
          }
          return data['pinned'] != true;
        }).toList();

        // Build the final list of widgets.
        final List<Widget> messageWidgets = [];

        // Show pinned messages in a “pinned section”
        if (_pinnedMessages.isNotEmpty) {
          messageWidgets.add(_buildPinnedSection());
        }

        // Build normal messages with day dividers.
        DateTime? lastDate;
        for (int i = 0; i < _normalMessages.length; i++) {
          final doc = _normalMessages[i];
          final data = doc.data() as Map<String, dynamic>;

          final ts = data['timestamp'] as Timestamp?;
          final dateTime = ts?.toDate();
          if (dateTime != null) {
            final justDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
            if (lastDate == null || justDate != lastDate) {
              lastDate = justDate;
              messageWidgets.add(_buildDateDivider(dateTime));
            }
          }

          messageWidgets.add(_buildMessageBubble(doc));
        }

        // Auto-scroll after building.
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

  // ---------------------------------------------------------------------------
  // 6) PINNED SECTION
  // ---------------------------------------------------------------------------
  Widget _buildPinnedSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          width: 1,
          color: Colors.white54,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label + pin icon.
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(Icons.push_pin_rounded, color: Colors.orange[200]),
                const SizedBox(width: 8),
                const Text(
                  'Pinned Messages',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white54, height: 1),
          // Render each pinned message.
          for (final doc in _pinnedMessages) _buildMessageBubble(doc),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 7) DATE DIVIDER
  // ---------------------------------------------------------------------------
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
              color: Colors.grey[700],
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              thickness: 1,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  /// Convert weekday int (Mon=1, Sun=7) to full name.
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
    if (weekday < 1 || weekday > 7) return "UnknownDay";
    return days[weekday - 1];
  }

  /// Convert month int (1-12) to full name.
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
    if (month < 1 || month > 12) return "UnknownMonth";
    return months[month - 1];
  }

  // ---------------------------------------------------------------------------
  // 8) MESSAGE BUBBLE
  // ---------------------------------------------------------------------------
  Widget _buildMessageBubble(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final senderId = data['senderId'] ?? '';
    final text = data['text'] ?? '';
    final imageUrl = data['imageUrl'] as String?;
    final pinned = data['pinned'] == true;
    final type = data['type'] ?? 'text';

    final senderName = data['senderName'] ?? '';
    final ts = data['timestamp'] as Timestamp?;
    final dt = ts?.toDate();
    final timeString = (dt != null)
        ? "${dt.hour}:${dt.minute.toString().padLeft(2, '0')}"
        : '';

    final currentUser = _auth.currentUser;
    final isMe = (currentUser != null && senderId == currentUser.uid);

    return GestureDetector(
      onLongPress: () => _showMessageOptions(doc, isMe),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? myBubbleColor : otherBubbleColor,
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
              if (!isMe && senderName.isNotEmpty) ...[
                Text(
                  senderName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (type == 'text' && text.isNotEmpty)
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.3,
                  ),
                ),
              if (type == 'image' && imageUrl != null)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, obj, stack) {
                        return Container(
                          color: Colors.grey,
                          height: 150,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeString,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white54,
                    ),
                  ),
                  if (pinned) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.push_pin,
                      color: pinnedIconColor,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 9) SHOW MESSAGE OPTIONS (PIN/UNPIN/DELETE)
  // ---------------------------------------------------------------------------
  void _showMessageOptions(DocumentSnapshot doc, bool isMe) {
    final data = doc.data() as Map<String, dynamic>;
    final pinned = data['pinned'] == true;
    if (!isMe && !_isAdmin) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(12),
          child: Wrap(
            children: [
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: Text(
                  isMe ? "Delete for Me" : "Delete Message",
                  style: const TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(doc.id);
                },
              ),
              if (!pinned)
                ListTile(
                  leading: Icon(Icons.push_pin, color: accentColor),
                  title: const Text(
                    "Pin Message",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pinMessage(doc.id, true);
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.push_pin_outlined, color: accentColor),
                  title: const Text(
                    "Unpin Message",
                    style: TextStyle(color: Colors.white70),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pinMessage(doc.id, false);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteMessage(String docId) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(docId)
        .delete();
  }

  Future<void> _pinMessage(String docId, bool pin) async {
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatId)
        .collection('messages')
        .doc(docId)
        .update({'pinned': pin});
  }

  // ---------------------------------------------------------------------------
  // 10) TYPING INDICATOR (LOCAL ONLY)
  // ---------------------------------------------------------------------------
  Widget _buildTypingIndicator() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: _isTyping
          ? Container(
              key: const ValueKey('typingIndicator'),
              padding: const EdgeInsets.only(bottom: 6),
              child: const Center(
                child: Text(
                  'Typing…',
                  style: TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          : const SizedBox(key: ValueKey('emptyIndicator')),
    );
  }

  // ---------------------------------------------------------------------------
  // 11) INPUT ROW
  // ---------------------------------------------------------------------------
  Widget _buildInputRow() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: const BoxDecoration(
          color: Colors.black87,
          border: Border(
            top: BorderSide(color: Colors.white10),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row for icons + text field.
            Row(
              children: [
                // If uploading image -> show spinner.
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
                  InkWell(
                    onTap: _sendImageMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[600],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // TextField.
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _msgController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && !_isTyping) {
                          setState(() => _isTyping = true);
                        } else if (val.isEmpty && _isTyping) {
                          setState(() => _isTyping = false);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Send button.
                InkWell(
                  onTap: _sendMessage,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
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
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 12) SEND TEXT MESSAGE
  // ---------------------------------------------------------------------------
  Future<void> _sendMessage() async {
  final text = _msgController.text.trim();
  if (text.isEmpty) return;

  final currentUser = _auth.currentUser;
  if (currentUser == null) return;

  // Use the current user's details if available.
  final senderName = currentUser.displayName ?? "Anonymous";
  final senderPhotoUrl = currentUser.photoURL ?? "";

  final data = {
    'senderId': currentUser.uid,
    'senderName': senderName,
    'senderPhotoUrl': senderPhotoUrl,
    'timestamp': FieldValue.serverTimestamp(),
    'pinned': false,
    'type': 'text',
    'text': text,
  };

  await FirebaseFirestore.instance
      .collection('chats')
      .doc(widget.chatId)
      .collection('messages')
      .add(data);

  _msgController.clear();
  setState(() => _isTyping = false);
  _autoScroll();
}
  // ---------------------------------------------------------------------------
  // 13) SEND IMAGE MESSAGE
  // ---------------------------------------------------------------------------
  Future<void> _sendImageMessage() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploadingImage = true);

    try {
      final file = File(picked.path);
      final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      final senderName = widget.otherUserName;
      final senderPhotoUrl = widget.otherUserPhotoUrl;

      final data = {
        'senderId': currentUser.uid,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'pinned': false,
        'type': 'image',
        'imageUrl': downloadUrl,
      };

      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .collection('messages')
          .add(data);
    } catch (e) {
      debugPrint("Error uploading image: $e");
    }

    setState(() => _isUploadingImage = false);
    _autoScroll();
  }

  // ---------------------------------------------------------------------------
  // 14) AUTO SCROLL
  // ---------------------------------------------------------------------------
  void _autoScroll() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(
          _scrollController.position.maxScrollExtent,
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // 15) REPORT FLOW
  // ---------------------------------------------------------------------------

  /// Step 1: Prompt user to pick a report category.
  void _showReportDialog() {
    final List<String> reportCategories = [
      "Harassment",
      "Spam",
      "NSFW Content",
      "Impersonation",
      "Other",
    ];
    String selectedCategory = reportCategories.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title:
              const Text("Report this Chat", style: TextStyle(color: Colors.white)),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select a reason for reporting:",
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    dropdownColor: Colors.grey[800],
                    value: selectedCategory,
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                    underline: Container(height: 1, color: Colors.white24),
                    onChanged: (val) {
                      if (val != null) {
                        setStateSB(() => selectedCategory = val);
                      }
                    },
                    items: reportCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _confirmReport(selectedCategory);
              },
              child: const Text("Next"),
            )
          ],
        );
      },
    );
  }

  /// Step 2: Confirmation before report submission.
  void _confirmReport(String category) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title:
              const Text("Confirm Report", style: TextStyle(color: Colors.white)),
          content: Text(
            'Are you sure you want to report this chat for "$category"?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("No", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(ctx); // close confirmation
                _submitReport(category);
              },
              child: const Text("Yes, Report"),
            ),
          ],
        );
      },
    );
  }

  /// Step 3: Write the report to 'reports' collection in Firestore.
  Future<void> _submitReport(String category) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnack("You must be logged in to report.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'chatId': widget.chatId,
        'otherUserId': widget.otherUserId,
        'reporterId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'category': category,
      });

      // Show success feedback.
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title:
              const Text('Report Received', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Thanks! We have received your report and will conduct an investigation within 24 hours.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('OK', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnack("Report failed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 16) BLOCK USER FLOW
  // ---------------------------------------------------------------------------

  /// Show a confirmation dialog before blocking the user.
  void _confirmBlockDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title:
              const Text("Confirm Block", style: TextStyle(color: Colors.white)),
          content: const Text(
            "Are you sure you want to block this user?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              onPressed: () {
                Navigator.pop(ctx);
                _blockUser();
              },
              child: const Text("Yes, Block", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  /// Perform the block action: add the other user's ID to the current user's "Blocked" field.
  Future<void> _blockUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      _showSnack("You must be logged in to block.");
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).update({
        'Blocked': FieldValue.arrayUnion([widget.otherUserId]),
      });
      _showSnack("User blocked.");
    } catch (e) {
      _showSnack("Error blocking user: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // 17) HELPER: SHOW SNACKBAR
  // ---------------------------------------------------------------------------
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
