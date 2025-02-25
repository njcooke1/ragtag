import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// Firebase imports
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ClubDrawerPage extends StatefulWidget {
  final String clubId;      // used to remove from Firestore
  final String clubName;
  final String pfpUrl;
  final bool isDarkMode;
  final bool isAdmin;
  final int memberCount;
  final Map<String, dynamic> socials;

  /// Callback that tells the parent widget the user has unfollowed the club.
  final VoidCallback onUserLeftClub;

  const ClubDrawerPage({
    Key? key,
    required this.clubId,
    required this.clubName,
    required this.pfpUrl,
    required this.isDarkMode,
    required this.isAdmin,
    required this.memberCount,
    required this.socials,
    required this.onUserLeftClub,
  }) : super(key: key);

  @override
  State<ClubDrawerPage> createState() => _ClubDrawerPageState();
}

class _ClubDrawerPageState extends State<ClubDrawerPage> {
  bool _isEditing = false;

  late TextEditingController _instagramController;
  late TextEditingController _twitterController;
  late TextEditingController _otherController;

  @override
  void initState() {
    super.initState();
    _instagramController = TextEditingController(
      text: widget.socials["instagram"] ?? "",
    );
    _twitterController = TextEditingController(
      text: widget.socials["twitter"] ?? "",
    );
    _otherController = TextEditingController(
      text: widget.socials["other"] ?? "",
    );
  }

  @override
  void dispose() {
    _instagramController.dispose();
    _twitterController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // Unfollow (Leave) the club
  // ---------------------------------------------------------
Future<void> _unfollowClub() async {
  try {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No user is currently logged in.')),
      );
      return;
    }

    // 1) Remove user from the club’s membership on Firestore
    // (If you store members as a subcollection, adapt this.)
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(widget.clubId)
        .update({
      'members': FieldValue.arrayRemove([userId])
    });

    // 2) Also remove this club from the user’s record, if you track that
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({
      'clubMemberships': FieldValue.arrayRemove([widget.clubId])
    });

    // 3) Close the drawer and show a quick toast or snackbar
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You have unfollowed this club.')),
    );

    // 4) Tell the parent we left the club
    //    The parent should set _isFollowing = false,
    //    which changes the UI from drawer -> plus icon.
    widget.onUserLeftClub();

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error leaving the club: $e')),
    );
  }
}

  // ---------------------------------------------------------
  // Save socials to Firestore
  // ---------------------------------------------------------
  Future<void> _saveEdits() async {
    final ig = _instagramController.text.trim();
    final tw = _twitterController.text.trim();
    final ot = _otherController.text.trim();

    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .update({
        'socials.instagram': ig,
        'socials.twitter': tw,
        'socials.other': ot,
      });

      setState(() => _isEditing = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Socials updated!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating socials: $e")),
      );
    }
  }

  // ---------------------------------------------------------
  // Admin: View Attendance
  // ---------------------------------------------------------
  Future<void> _viewAttendanceRecords() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                "Attendance Records",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(widget.clubId)
                      .collection('attendance')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error: ${snapshot.error}",
                          style: TextStyle(
                            color: widget.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text("No attendance records."));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final docId = docs[index].id;
                        final title = data["title"] ?? "Untitled";
                        final code = data["code"] ?? "???";
                        final isLive = data["isLive"] == true;

                        return Card(
                          color: widget.isDarkMode
                              ? Colors.white10
                              : Colors.grey.shade100,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(
                              title,
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "Code: $code\n${isLive ? 'Live' : 'Closed'}",
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
                              ),
                            ),
                            onTap: () => _showAttendees(docId, title),
                            trailing: isLive
                                ? TextButton(
                                    onPressed: () => _endAttendanceSession(docId),
                                    child: const Text("End"),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAttendees(String attendanceDocId, String title) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                "Attendees: $title",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(widget.clubId)
                      .collection('attendance')
                      .doc(attendanceDocId)
                      .collection('attendees')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text("No one checked in yet."));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final fullName = data["fullName"] ?? "Unknown";
                        final username = data["username"] ?? "";

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: widget.isDarkMode
                                ? Colors.white24
                                : Colors.grey.shade300,
                            child: Text(
                              fullName.isNotEmpty
                                  ? fullName[0].toUpperCase()
                                  : "?",
                            ),
                          ),
                          title: Text(
                            fullName,
                            style: TextStyle(
                              color:
                                  widget.isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: Text(
                            "User: $username",
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _endAttendanceSession(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('attendance')
          .doc(docId)
          .update({"isLive": false});

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance ended.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error ending session: $e")),
      );
    }
  }

  // ---------------------------------------------------------
  // Admin: View Anonymous Feedback
  // ---------------------------------------------------------
  Future<void> _viewAnonymousFeedback() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                "Anonymous Feedback",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(widget.clubId)
                      .collection('anonymousFeedback')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text("No feedback yet."));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final feedback = data["feedback"] ?? "No text";

                        return Card(
                          color: widget.isDarkMode
                              ? Colors.white10
                              : Colors.grey.shade100,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            leading: const Icon(
                              Icons.person_outline,
                              color: Colors.grey,
                            ),
                            title: Text(
                              "Anonymous #${docs.length - index}",
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              feedback,
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white70
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // Admin: View & Close Polls
  // ---------------------------------------------------------
  Future<void> _viewPollResults() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 16),
                Text(
                  "Poll Results",
                  style: TextStyle(
                    color: widget.isDarkMode ? Colors.white : Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                Expanded(
                  child: FutureBuilder<QuerySnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('clubs')
                        .doc(widget.clubId)
                        .collection('polls')
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text("Error: ${snapshot.error}"),
                        );
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(child: Text("No polls found."));
                      }

                      return ListView.builder(
                        controller: scrollController,
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final pollId = docs[index].id;
                          final data = docs[index].data() as Map<String, dynamic>;
                          final title = data["title"] ?? "Untitled";
                          final isClosed = data["isClosed"] == true;
                          final options = data["options"] ?? [];
                          // each option => { "option": "...", "votes": ... }

                          return Card(
                            color: widget.isDarkMode
                                ? Colors.white10
                                : Colors.grey.shade100,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: TextStyle(
                                            color: widget.isDarkMode
                                                ? Colors.white
                                                : Colors.black87,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      if (!isClosed)
                                        TextButton(
                                          onPressed: () =>
                                              _closePoll(pollId, title),
                                          child: const Text("Close Poll"),
                                        )
                                      else
                                        Text(
                                          "Closed",
                                          style: TextStyle(
                                            color: Colors.redAccent[100],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ...List.generate(options.length, (i) {
                                    final opt = options[i];
                                    final optText = opt["option"] ?? "Option";
                                    final votes = opt["votes"] ?? 0;
                                    return Text(
                                      "$optText - $votes vote(s)",
                                      style: TextStyle(
                                        color: widget.isDarkMode
                                            ? Colors.white70
                                            : Colors.black87,
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _closePoll(String pollId, String pollTitle) async {
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .collection('polls')
          .doc(pollId)
          .update({"isClosed": true});

      Navigator.pop(context); // close the bottom sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Poll '$pollTitle' is now closed.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error closing poll: $e")),
      );
    }
  }

  // ---------------------------------------------------------
  // Admin: View Event RSVPs
  // ---------------------------------------------------------
  Future<void> _viewEventRsvps() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                "Event RSVPs",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(widget.clubId)
                      .collection('events')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          "Error: ${snapshot.error}",
                          style: TextStyle(
                            color: widget.isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text("No events found."));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final eventDocId = docs[index].id;
                        final eventTitle = data["title"] ?? "Untitled Event";

                        return Card(
                          color: widget.isDarkMode
                              ? Colors.white10
                              : Colors.grey.shade100,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(
                              eventTitle,
                              style: TextStyle(
                                color: widget.isDarkMode
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () => _showRsvpsForEvent(eventDocId, eventTitle),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showRsvpsForEvent(String eventDocId, String eventTitle) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.8,
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                "RSVPs: $eventTitle",
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(widget.clubId)
                      .collection('events')
                      .doc(eventDocId)
                      .collection('rsvps')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text("Error: ${snapshot.error}"));
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Center(child: Text("No RSVPs yet."));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final rsvpData =
                            docs[index].data() as Map<String, dynamic>;
                        final fullName = rsvpData["fullName"] ?? "Unknown";

                        return ListTile(
                          title: Text(
                            fullName,
                            style: TextStyle(
                              color: widget.isDarkMode
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------
  // Link-building for socials
  // ---------------------------------------------------------
  String _buildProperLink(IconData icon, String raw) {
    final lowerRaw = raw.toLowerCase().trim();
    if (lowerRaw.isEmpty) {
      return "";
    }
    if (icon == FontAwesomeIcons.instagram) {
      if (!lowerRaw.contains("instagram.com")) {
        return "https://instagram.com/${raw.trim()}";
      }
      if (!lowerRaw.startsWith("http")) {
        return "https://$lowerRaw";
      }
      return raw.trim();
    } else if (icon == FontAwesomeIcons.twitter) {
      if (!lowerRaw.contains("twitter.com")) {
        return "https://twitter.com/${raw.trim()}";
      }
      if (!lowerRaw.startsWith("http")) {
        return "https://$lowerRaw";
      }
      return raw.trim();
    } else {
      if (!lowerRaw.startsWith("http://") && !lowerRaw.startsWith("https://")) {
        return "https://${raw.trim()}";
      }
      return raw.trim();
    }
  }

  Future<void> _launchURL(IconData icon, String rawUrl) async {
    final link = _buildProperLink(icon, rawUrl);
    if (link.isEmpty) return;

    final uri = Uri.parse(link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch $link");
    }
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDarkMode ? const Color(0xFF1F1F1F) : Colors.white;
    final textColor = widget.isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = widget.isDarkMode ? Colors.white70 : Colors.black54;

    return Drawer(
      child: Container(
        color: bgColor,
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    // Top header
                    _buildHeader(context),
                    Container(
                      margin: const EdgeInsets.only(top: 0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 20.0,
                      ),
                      decoration: BoxDecoration(color: bgColor),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatsCard(textColor, subTextColor),
                          const SizedBox(height: 16),
                          _buildSocialsSection(textColor, subTextColor),

                          // ADMIN EXTRAS
                          if (widget.isAdmin)
                            Container(
                              margin: const EdgeInsets.only(top: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: widget.isDarkMode
                                    ? Colors.white.withOpacity(0.07)
                                    : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Admin Extras",
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // ATTENDANCE
                                  ListTile(
                                    leading: Icon(
                                      Icons.fact_check_outlined,
                                      color: subTextColor,
                                    ),
                                    title: Text(
                                      "Attendance Records",
                                      style: TextStyle(color: textColor),
                                    ),
                                    onTap: _viewAttendanceRecords,
                                  ),
                                  // FEEDBACK
                                  ListTile(
                                    leading: Icon(
                                      Icons.feedback_outlined,
                                      color: subTextColor,
                                    ),
                                    title: Text(
                                      "Feedback",
                                      style: TextStyle(color: textColor),
                                    ),
                                    onTap: _viewAnonymousFeedback,
                                  ),
                                  // POLLS
                                  ListTile(
                                    leading: Icon(
                                      Icons.bar_chart_outlined,
                                      color: subTextColor,
                                    ),
                                    title: Text(
                                      "View & Close Polls",
                                      style: TextStyle(color: textColor),
                                    ),
                                    onTap: _viewPollResults,
                                  ),
                                  // RSVPs
                                  ListTile(
                                    leading: Icon(
                                      Icons.event_available_outlined,
                                      color: subTextColor,
                                    ),
                                    title: Text(
                                      "Event RSVPs",
                                      style: TextStyle(color: textColor),
                                    ),
                                    onTap: _viewEventRsvps,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Optional pinned close-drawer arrow
              Positioned(
                top: 0,
                left: 0,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ),

              // =========================================================
              //   BOTTOM BUTTON FOR REGULAR MEMBERS ONLY
              // =========================================================
              if (!widget.isAdmin)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: OutlinedButton(
                    onPressed: _unfollowClub,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red, width: 2.0),
                      // Subtle background to highlight the neon effect:
                      backgroundColor: widget.isDarkMode
                          ? Colors.black.withOpacity(0.3)
                          : Colors.white,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: Text(
                      "Unfollow",
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.redAccent,
                            blurRadius: 2,
                            offset: Offset(0, 0),
                          ),
                          Shadow(
                            color: Colors.redAccent,
                            blurRadius: 2,
                            offset: Offset(0, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------
  // Header with background image
  // ---------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.pfpUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.pfpUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) => Container(color: Colors.grey),
            )
          else
            Container(color: Colors.grey),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.2),
                  Colors.transparent,
                ],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.clubName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      blurRadius: 4,
                      offset: Offset(1, 1),
                      color: Colors.black54,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Stats card: members
  // ---------------------------------------------------------
  Widget _buildStatsCard(Color textColor, Color subTextColor) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withOpacity(0.07)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(Icons.people_alt, color: subTextColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Members: ${widget.memberCount}",
              style: TextStyle(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // Socials section
  // ---------------------------------------------------------
  Widget _buildSocialsSection(Color textColor, Color subTextColor) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDarkMode
            ? Colors.white.withOpacity(0.07)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Socials",
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          if (!_isEditing) ...[
            _buildSocialLinkRow(
              icon: FontAwesomeIcons.instagram,
              handle: widget.socials["instagram"],
            ),
            _buildSocialLinkRow(
              icon: FontAwesomeIcons.twitter,
              handle: widget.socials["twitter"],
            ),
            _buildSocialLinkRow(
              icon: FontAwesomeIcons.link,
              handle: widget.socials["other"],
            ),
            if (widget.isAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => setState(() => _isEditing = true),
                  icon: const Icon(Icons.edit),
                  label: const Text("Edit"),
                  style: TextButton.styleFrom(
                    foregroundColor: textColor,
                  ),
                ),
              ),
          ] else ...[
            _buildTextField("Instagram", _instagramController),
            const SizedBox(height: 8),
            _buildTextField("Twitter", _twitterController),
            const SizedBox(height: 8),
            _buildTextField("Other", _otherController),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _saveEdits,
                icon: const Icon(Icons.save),
                label: const Text("Save"),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.green,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSocialLinkRow({
    required IconData icon,
    required dynamic handle,
  }) {
    if (handle == null || (handle as String).trim().isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            FaIcon(
              icon,
              color: widget.isDarkMode ? Colors.white70 : Colors.grey,
            ),
            const SizedBox(width: 10),
            Text(
              "Type Handle (after @)",
              style: TextStyle(
                color: widget.isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      );
    }

    final raw = handle.trim();
    return InkWell(
      onTap: () => _launchURL(icon, raw),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Row(
          children: [
            FaIcon(
              icon,
              color: widget.isDarkMode ? Colors.white70 : Colors.black87,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                raw,
                style: TextStyle(
                  color: widget.isDarkMode ? Colors.blue[300] : Colors.blue,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      style: TextStyle(
        color: widget.isDarkMode ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: widget.isDarkMode ? Colors.white70 : Colors.black54,
        ),
        filled: true,
        fillColor: widget.isDarkMode
            ? Colors.white.withOpacity(0.05)
            : Colors.grey[200],
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
