import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
// (We keep the Cupertino import in case you still use Cupertino widgets anywhere)
import 'package:flutter/cupertino.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart' as iPicker;
import 'package:http/http.dart' as http;

import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'club_drawer_page.dart';
import 'all_organizations.dart';
import 'clubs_subpages.dart';

class ClubsProfilePage extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic> communityData;
  final String userId;

  const ClubsProfilePage({
    Key? key,
    required this.communityId,
    required this.communityData,
    required this.userId,
  }) : super(key: key);

  @override
  State<ClubsProfilePage> createState() => _ClubsProfilePageState();
}

class _ClubsProfilePageState extends State<ClubsProfilePage>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late String clubId;
  late Map<String, dynamic> clubData;

  bool _isFollowing = false;
  bool _isAdmin = false;
  bool _isLoading = false;
  bool _showAdditionalInfo = false;
  bool _isDarkMode = true;

  int _currentImageIndex = 0;
  List<String> _slidingPictures = [];

  late String currentUserId;

  late AnimationController _titleAnimationController;
  late Animation<double> _titleAnimation;

  // Member data
  List<Map<String, dynamic>> _members = [];
  int _memberCount = 0;
  String _lastActivity = "No recent activity";

  // Socials map
  Map<String, dynamic> _socials = {
    "instagram": "",
    "twitter": "",
    "other": "",
  };

  bool _isEditingSocials = false;
  late TextEditingController _igController;
  late TextEditingController _twController;
  late TextEditingController _otherController;

  // Club event-related
  List<Map<String, dynamic>> _clubEvents = [];
  DateTime? _chosenEventDate;
  TimeOfDay? _chosenEventTime;

  // For notifications
  bool _notifyAllMembers = true;
  File? _notifImageFile;

  // For random code generation
  final _random = Random();

  // Attendance
  Map<String, dynamic>? _activeAttendance;

  // New: For Event Flyer
  File? _eventFlyerFile;

  @override
  void initState() {
    super.initState();
    clubId = widget.communityId;
    clubData = widget.communityData;
    currentUserId = widget.userId;

    _titleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleAnimation = CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeOutBack,
    );
    _titleAnimationController.forward();

    _igController = TextEditingController();
    _twController = TextEditingController();
    _otherController = TextEditingController();

    _fetchClubDocData();
    _fetchMembersFromFirebase();
    _checkUserRole();
    _fetchClubEvents();

    if (currentUserId.isEmpty) {
      _getCurrentUserId();
    }
  }

  @override
  void dispose() {
    _titleAnimationController.dispose();
    _igController.dispose();
    _twController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // 1) FETCHING
  // ---------------------------------------------------------
  Future<void> _fetchClubDocData() async {
    if (clubId.isEmpty) return;
    try {
      final clubDoc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .get();
      if (clubDoc.exists) {
        final data = clubDoc.data();
        if (data != null) {
          if (data.containsKey('pfpUrl')) {
            setState(() => clubData['pfpUrl'] = data['pfpUrl'] ?? '');
          }
          if (data.containsKey('slidingPictures')) {
            final pics = data['slidingPictures'] as List<dynamic>;
            setState(() {
              _slidingPictures = pics.map((e) => e.toString()).toList();
            });
          }
          if (data.containsKey('socials')) {
            setState(() => _socials = data['socials'] as Map<String, dynamic>);
          }
          if (data.containsKey('lastActivity')) {
            setState(() => _lastActivity = data['lastActivity'] ?? "N/A");
          }
        }
      }
      // Set initial text fields
      _igController.text = _socials["instagram"] ?? "";
      _twController.text = _socials["twitter"] ?? "";
      _otherController.text = _socials["other"] ?? "";
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching club data: $e'),
          backgroundColor: Colors.grey.shade800,
        ),
      );
    }
  }

  Future<void> _fetchClubEvents() async {
    if (clubId.isEmpty) return;
    try {
      setState(() => _isLoading = true);
      final eventsSnap = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _clubEvents = eventsSnap.docs.map((doc) {
          final data = doc.data();
          return {
            ...data,
            'id': doc.id,
          };
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching events: $e'),
          backgroundColor: Colors.grey.shade800,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentUserId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() => currentUserId = user.uid);
    }
  }

  /// -------------------- store & display member's pfp
  Future<void> _fetchMembersFromFirebase() async {
    if (clubId.isEmpty) return;
    try {
      final membersSnap = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('members')
          .get();

      setState(() {
        _members = membersSnap.docs.map((doc) {
          final data = doc.data();
          return {
            'name': data['fullName'] ?? 'No Name',
            'photoUrl': data['photoUrl'] ?? '',
          };
        }).toList();
        _memberCount = _members.length;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching members: $e'),
          backgroundColor: Colors.grey.shade800,
        ),
      );
    }
  }

  Future<void> _checkUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? widget.userId;
    if (uid.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final adminDoc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('admins')
          .doc(uid)
          .get();
      if (adminDoc.exists) {
        setState(() {
          _isAdmin = true;
          _isFollowing = true;
        });
      } else {
        final memberDoc = await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('members')
            .doc(uid)
            .get();
        if (memberDoc.exists) {
          setState(() {
            _isAdmin = false;
            _isFollowing = true;
          });
        } else {
          setState(() {
            _isAdmin = false;
            _isFollowing = false;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking user role: $e'),
          backgroundColor: Colors.grey.shade800,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? currentUserId;
    if (uid.isEmpty) return;

    setState(() => _isFollowing = !_isFollowing);
    final memberDocRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .collection('members')
        .doc(uid);

    if (_isFollowing) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data = userDoc.data() ?? {};
        final fullName = data['fullName'] ?? "No full name set";
        final userFcmToken = data['fcmToken'] ?? "";
        final username = data['username'] ?? "(no username)";
        final photoUrl = data['photoUrl'] ?? "";

        await memberDocRef.set({
          'fullName': fullName,
          'uid': uid,
          'username': username,
          'joinedAt': FieldValue.serverTimestamp(),
          'fcmToken': userFcmToken,
          'photoUrl': photoUrl,
        }, SetOptions(merge: true));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are now following this club!')),
        );
        await _fetchMembersFromFirebase();
      } catch (e) {
        setState(() => _isFollowing = !_isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to follow: $e')),
        );
      }
    } else {
      try {
        await memberDocRef.delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You unfollowed this club.')),
        );
        await _fetchMembersFromFirebase();
      } catch (e) {
        setState(() => _isFollowing = !_isFollowing);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unfollow: $e')),
        );
      }
    }
  }

  Future<void> _saveSocialsToFirebase() async {
    try {
      await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
        'socials.instagram': _igController.text.trim(),
        'socials.twitter': _twController.text.trim(),
        'socials.other': _otherController.text.trim(),
      });
      setState(() {
        _socials["instagram"] = _igController.text.trim();
        _socials["twitter"] = _twController.text.trim();
        _socials["other"] = _otherController.text.trim();
        _isEditingSocials = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Socials updated!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating socials: $e')),
      );
    }
  }

  // ---------------------------------------------------------
  // Helper for building social link
  // ---------------------------------------------------------
  String _buildFullLink(String label, String handle) {
    final raw = handle.trim().toLowerCase();
    if (raw.isEmpty || raw == "not provided") {
      return "Not Provided";
    }
    if (label == "Instagram") {
      if (!raw.contains("instagram.com")) {
        return "https://instagram.com/${handle.trim()}";
      }
      return raw.startsWith("http") ? handle.trim() : "https://$raw";
    } else if (label == "Twitter") {
      if (!raw.contains("twitter.com")) {
        return "https://twitter.com/${handle.trim()}";
      }
      return raw.startsWith("http") ? handle.trim() : "https://$raw";
    } else {
      if (!raw.startsWith("http://") && !raw.startsWith("https://")) {
        return "https://${handle.trim()}";
      }
      return handle.trim();
    }
  }

  Future<void> _launchURL(String url) async {
    if (url.trim().isEmpty || url == "Not Provided") return;
    final uri = Uri.parse(url.trim());
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Could not launch $url");
    }
  }

  // ---------------------------------------------------------
  // 2) UI: TOP HEADER
  // ---------------------------------------------------------
  Widget _buildTopHeader(String clubName) {
    final pfpUrl = clubData['pfpUrl'] ??
        'https://via.placeholder.com/150/000000/FFFFFF/?text=NoPic';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: _isDarkMode
            ? const LinearGradient(
                colors: [Color(0xFF1F1F1F), Color(0xFF2C2C2C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                colors: [Colors.white, Colors.grey],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AllOrganizationsPage()),
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: _isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 16),
          // PFP
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: pfpUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade300),
              errorWidget: (_, __, ___) => Container(color: Colors.grey),
            ),
          ),
          const SizedBox(width: 16),
          // Club Name
          Expanded(
            child: ScaleTransition(
              scale: _titleAnimation,
              child: Text(
                clubName,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Light/Dark toggle
          GestureDetector(
            onTap: () => setState(() => _isDarkMode = !_isDarkMode),
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0),
              child: Icon(
                _isDarkMode ? Icons.wb_sunny : Icons.nights_stay,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          // REPORT ICON
          IconButton(
            icon: const Icon(Icons.flag, color: Colors.grey),
            onPressed: _showReportDialog,
            tooltip: "Report Community",
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 4) MIDDLE NAV BAR
  // ---------------------------------------------------------
  Widget _buildMiddleNavBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // HOME
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AllOrganizationsPage()),
                ),
                child: Icon(
                  Icons.home_filled,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  size: 28,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "HOME",
                style: TextStyle(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black87.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Center triple icons
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFAF7B), Color(0xFFD76D77), Color(0xFF1C6971)],
              ),
            ),
            padding: const EdgeInsets.all(2.4),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(23),
                color: _isDarkMode ? Colors.grey.shade900 : Colors.white,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Calendar
                  GestureDetector(
                    onTap: _showCalendarPopup,
                    child: Icon(
                      Icons.calendar_month,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 32),

                  // Drawer or Follow
                  GestureDetector(
                    onTap: () async {
                      if (_isAdmin) {
                        _scaffoldKey.currentState?.openDrawer();
                      } else if (!_isFollowing) {
                        await _toggleFollow(clubId);
                      } else {
                        _scaffoldKey.currentState?.openDrawer();
                      }
                    },
                    child: _isAdmin
                        ? Icon(
                            Icons.design_services,
                            color:
                                _isDarkMode ? Colors.white : Colors.black87,
                            size: 28,
                          )
                        : _isFollowing
                            ? Icon(
                                Icons.menu,
                                color:
                                    _isDarkMode ? Colors.white : Colors.black87,
                                size: 28,
                              )
                            : Icon(
                                Icons.add,
                                color:
                                    _isDarkMode ? Colors.white : Colors.black87,
                                size: 28,
                              ),
                  ),
                  const SizedBox(width: 32),

                  // Members
                  GestureDetector(
                    onTap: () {
                      _showMembersModal(
                        clubId,
                        clubData['name'] ?? 'No Name',
                      );
                    },
                    child: Icon(
                      Icons.group,
                      color: _isDarkMode ? Colors.white : Colors.black87,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CHAT
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/club-chat',
                    arguments: {
                      'clubId': clubId,
                      'clubName': clubData['name'] ?? 'No Name'
                    },
                  );
                },
                child: Icon(
                  Icons.chat_bubble_outline,
                  color: _isDarkMode ? Colors.white : Colors.black87,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "CHAT",
                style: TextStyle(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.8)
                      : Colors.black87.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // 4B) THE CALENDAR POPUP
  // ---------------------------------------------------------
  void _showCalendarPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return StatefulBuilder(
              builder: (context, setStateModal) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        "Club Calendar",
                        style: GoogleFonts.workSans(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount: _clubEvents.length,
                          itemBuilder: (context, index) {
                            final event = _clubEvents[index];
                            final title = event['title'] ?? "Untitled Event";
                            final dateTime = event['dateTime'] ?? "";
                            final location = event['location'] ?? "";
                            final flyerUrl = event['flyerUrl'] ?? "";

                            return Card(
                              color: _isDarkMode
                                  ? Colors.grey[850]
                                  : Colors.grey[100],
                              elevation: 1,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    // If there's a flyer, show a small preview:
                                    if (flyerUrl.isNotEmpty)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: flyerUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(
                                            color: Colors.grey.shade300,
                                          ),
                                          errorWidget: (_, __, ___) =>
                                              Container(color: Colors.grey),
                                        ),
                                      ),
                                    if (flyerUrl.isNotEmpty)
                                      const SizedBox(width: 12),

                                    // Title, date, location
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: GoogleFonts.workSans(
                                              color: _isDarkMode
                                                  ? Colors.grey[200]
                                                  : Colors.grey[800],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          if (dateTime.isNotEmpty)
                                            Text(
                                              "When: $dateTime",
                                              style: GoogleFonts.workSans(
                                                color: _isDarkMode
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                          if (location.isNotEmpty)
                                            Text(
                                              "Where: $location",
                                              style: GoogleFonts.workSans(
                                                color: _isDarkMode
                                                    ? Colors.grey[400]
                                                    : Colors.grey[600],
                                                fontSize: 13,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (_isAdmin)
                                      IconButton(
                                        icon: Icon(
                                          Icons.close,
                                          color: Colors.pinkAccent[100],
                                        ),
                                        onPressed: () async {
                                          await _deleteEvent(event['id']);
                                          setStateModal(() {});
                                        },
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      if (_isAdmin)
                        // MAKE ICON/TEXT WHITE:
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white, // text/icon = white
                          ),
                          onPressed: () => _showAddEventDialog(setStateModal),
                          icon: const Icon(Icons.add),
                          label: const Text("Add Event"),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    if (clubId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .doc(eventId)
          .delete();

      setState(() {
        _clubEvents.removeWhere((ev) => ev['id'] == eventId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event deleted!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting event: $e")),
      );
    }
  }

  /// -------------- "Add New Event" DIALOG (Two-Step, Always Dark) --------------
  void _showAddEventDialog(void Function(void Function()) setStateModal) {
    int _currentStep = 1;

    final titleController = TextEditingController();
    final locationController = TextEditingController();
    final descController = TextEditingController();

    // Reset each time
    _eventFlyerFile = null;
    _chosenEventDate = null;
    _chosenEventTime = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        // Hardcode a permanently dark theme
        const Color bgColor = Color(0xFF222222);
        const Color textColor = Colors.white;
        const Color hintColor = Colors.white54;
        final fillColor = Colors.grey[850];

        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            /// Step 1 => Flyer, Title, Location
            Widget stepOneContent() {
              return Container(
                width: MediaQuery.of(context).size.width - 24,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade900,
                      Colors.grey.shade800,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The flyer area
                    GestureDetector(
                      onTap: () async {
                        final pickedFile = await iPicker.ImagePicker()
                            .pickImage(source: iPicker.ImageSource.gallery);
                        if (pickedFile != null) {
                          setStateDialog(() {
                            _eventFlyerFile = File(pickedFile.path);
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade800,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          image: _eventFlyerFile == null
                              ? null
                              : DecorationImage(
                                  image: FileImage(_eventFlyerFile!),
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: Stack(
                          children: [
                            if (_eventFlyerFile == null)
                              Center(
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: const Icon(
                                    Icons.image,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              )
                            else
                              Container(
                                color: Colors.black.withOpacity(0.15),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Title & Location => each with a simple underline
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      child: Column(
                        children: [
                          // Title textfield
                          TextField(
                            controller: titleController,
                            style: const TextStyle(color: textColor, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: "Event Title *",
                              hintStyle: const TextStyle(color: hintColor),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white24,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(0xFFFFA200),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Location
                          TextField(
                            controller: locationController,
                            style: const TextStyle(color: textColor, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: "Location *",
                              hintStyle: const TextStyle(color: hintColor),
                              enabledBorder: const UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: Colors.white24,
                                ),
                              ),
                              focusedBorder: UnderlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(0xFFFFA200),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            /// Step 2 => short description plus date/time
            Widget stepTwoContent() {
              String dateTimeLabel = "No date/time selected yet.";
              if (_chosenEventDate != null) {
                dateTimeLabel =
                    "${_chosenEventDate!.month}/${_chosenEventDate!.day}/${_chosenEventDate!.year}";
                if (_chosenEventTime != null) {
                  dateTimeLabel += " @ ${_chosenEventTime!.format(context)}";
                }
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descController,
                    style: const TextStyle(color: textColor),
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: "Short Description *",
                      labelStyle: const TextStyle(color: hintColor),
                      filled: true,
                      fillColor: fillColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date / Time picks
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final now = DateTime.now();
                            final result = await showDatePicker(
                              context: context,
                              initialDate: now,
                              firstDate: now,
                              lastDate: DateTime(now.year + 5),
                              builder: (ctx, child) {
                                return Theme(
                                  data: ThemeData.dark(),
                                  child: child!,
                                );
                              },
                            );
                            if (result != null) {
                              setStateDialog(() => _chosenEventDate = result);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: fillColor,
                            foregroundColor: textColor,
                          ),
                          child: Text(
                            _chosenEventDate == null
                                ? "Choose Date *"
                                : "Date: ${_chosenEventDate!.month}/${_chosenEventDate!.day}/${_chosenEventDate!.year}",
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final timeResult = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                              builder: (ctx, child) {
                                return Theme(
                                  data: ThemeData.dark(),
                                  child: child!,
                                );
                              },
                            );
                            if (timeResult != null) {
                              setStateDialog(() => _chosenEventTime = timeResult);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: fillColor,
                            foregroundColor: textColor,
                          ),
                          child: Text(
                            _chosenEventTime == null
                                ? "Time *"
                                : "Time: ${_chosenEventTime!.format(context)}",
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Selected date/time:\n$dateTimeLabel",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                ],
              );
            }

            // The step circles
            Widget stepCircles() {
              const Color circleActive = Color(0xFFFFA200);
              final Color circleInactive = Colors.grey.shade500;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _currentStep == 1 ? circleActive : circleInactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _currentStep == 2 ? circleActive : circleInactive,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              );
            }

            return AlertDialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                  color: Colors.white12,
                  width: 1.3,
                ),
              ),
              titlePadding: EdgeInsets.zero,
              title: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF3A3A3A),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(14),
                  ),
                ),
                child: const Center(
                  child: Text(
                    "Host a New Event",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Step label
                    Text(
                      _currentStep == 1
                          ? "Flyer, Title & Location"
                          : "Description & Date/Time",
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_currentStep == 1) stepOneContent() else stepTwoContent(),
                    const SizedBox(height: 14),
                    stepCircles(),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (_currentStep == 1) {
                      // Step1 => Validate
                      final flyerOk = _eventFlyerFile != null;
                      final titleOk = titleController.text.trim().isNotEmpty;
                      final locOk = locationController.text.trim().isNotEmpty;
                      if (!flyerOk || !titleOk || !locOk) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Please pick a flyer, title, and location for Step 1.",
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      setStateDialog(() => _currentStep = 2);
                    } else {
                      // Step2 => finalize
                      final descOk = descController.text.trim().isNotEmpty;
                      final dateSelected = _chosenEventDate != null;
                      final timeSelected = _chosenEventTime != null;
                      if (!descOk || !dateSelected || !timeSelected) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Please fill out description & pick a date/time.",
                              style: TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(dialogCtx);
                      setState(() => _isLoading = true);

                      // build final date/time
                      final dateString =
                          "${_chosenEventDate!.month}/${_chosenEventDate!.day}/${_chosenEventDate!.year}";
                      final timeString = _chosenEventTime!.format(context);
                      final dateTimeString = "$dateString @ $timeString";

                      final newEvent = {
                        "title": titleController.text.trim(),
                        "location": locationController.text.trim(),
                        "description": descController.text.trim(),
                        "dateTime": dateTimeString,
                        "createdAt": FieldValue.serverTimestamp(),
                        "isNew": true,
                        "flyerUrl": "",
                      };

                      // upload flyer
                      String flyerDownloadUrl = "";
                      try {
                        final flyerRef = FirebaseStorage.instance
                            .ref()
                            .child('eventFlyers')
                            .child(clubId)
                            .child(
                                '${newEvent["title"]}-${DateTime.now().millisecondsSinceEpoch}.png');
                        final snapshot = await flyerRef.putFile(_eventFlyerFile!);
                        flyerDownloadUrl = await snapshot.ref.getDownloadURL();
                      } catch (e) {
                        debugPrint("Error uploading flyer: $e");
                      }
                      newEvent["flyerUrl"] = flyerDownloadUrl;

                      try {
                        final docRef = await FirebaseFirestore.instance
                            .collection('clubs')
                            .doc(clubId)
                            .collection('events')
                            .add(newEvent);
                        newEvent["id"] = docRef.id;

                        setState(() {
                          _clubEvents.insert(0, newEvent);
                          _isLoading = false;
                        });
                        setStateModal(() {});

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Your event is now official!",
                              style: TextStyle(color: Color(0xFFFFA200)),
                            ),
                            backgroundColor: Color(0xFF3A3A3A),
                          ),
                        );
                      } catch (e) {
                        setState(() => _isLoading = false);
                        debugPrint("Error saving event: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Failed to create event: $e")),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: const Color(0xFFFFA200),
                  ),
                  child: Text(_currentStep == 1 ? "Next" : "Create Event"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------
  // 5) BODY
  // ---------------------------------------------------------
  Widget _buildHeroSectionWrapper({required Widget child}) {
    final borderRadius = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: Border.all(
          width: 2.0,
          style: BorderStyle.solid,
          color: _isDarkMode
              ? Colors.white30
              : const Color(0xFFD76D77).withOpacity(0.5),
        ),
      ),
      child: child,
    );
  }

  // NEW: handle adding sliding picture
  Future<void> _handleAddSlidingPicture() async {
    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only admins can add new pictures!'),
        ),
      );
      return;
    }
    if (_slidingPictures.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Max 5 pictures allowed. Remove one before adding.'),
        ),
      );
      return;
    }

    final pickedFile = await iPicker.ImagePicker()
        .pickImage(source: iPicker.ImageSource.gallery, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);
    try {
      final file = File(pickedFile.path);
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('clubs')
          .child(clubId)
          .child('slidingPictures')
          .child('${DateTime.now().millisecondsSinceEpoch}.png');
      final snapshot = await storageRef.putFile(file);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
        'slidingPictures': FieldValue.arrayUnion([downloadUrl]),
      });
      setState(() {
        _slidingPictures.add(downloadUrl);
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New picture added!'),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding picture: $e'),
        ),
      );
    }
  }

  // NEW: let admin reorder or delete images
  void _showManageImages() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        // Make a copy to reorder
        final tempList = List<String>.from(_slidingPictures);

        return StatefulBuilder(
          builder: (context, setStateModal) {
            // Reorder callback
            void onReorder(int oldIndex, int newIndex) {
              if (newIndex > tempList.length) newIndex = tempList.length;
              if (oldIndex < newIndex) {
                newIndex--;
              }
              final item = tempList.removeAt(oldIndex);
              tempList.insert(newIndex, item);
              setStateModal(() {});
            }

            // Save changes to Firestore
            Future<void> saveChanges() async {
              // Overwrite the 'slidingPictures' array with the new order
              setState(() => _isLoading = true);
              Navigator.pop(ctx); // close bottom sheet
              try {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .update({
                  'slidingPictures': tempList,
                });

                setState(() {
                  _slidingPictures = tempList;
                  _isLoading = false;
                });

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pictures updated!')),
                );
              } catch (e) {
                setState(() => _isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }

            // Remove item
            Future<void> removePicture(String imageUrl) async {
              tempList.remove(imageUrl);
              setStateModal(() {});
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.75,
              maxChildSize: 0.95,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Rearrange / Delete Pictures",
                      style: TextStyle(
                        color: _isDarkMode ? Colors.white : Colors.black87,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ReorderableListView.builder(
                        itemCount: tempList.length,
                        onReorder: onReorder,
                        itemBuilder: (context, index) {
                          final imgUrl = tempList[index];
                          return ListTile(
                            key: ValueKey(imgUrl),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: imgUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    Container(color: Colors.grey.shade300),
                                errorWidget: (_, __, ___) =>
                                    Container(color: Colors.grey),
                              ),
                            ),
                            title: Text(
                              "Image ${index + 1}",
                              style: TextStyle(
                                color: _isDarkMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: _isDarkMode
                                    ? Colors.redAccent
                                    : Colors.redAccent.shade400,
                              ),
                              onPressed: () => removePicture(imgUrl),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: saveChanges,
                      icon: const Icon(Icons.save),
                      label: const Text("Save Changes"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isDarkMode ? Colors.white12 : Colors.black87,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

// ONLY the updated portion of _buildImagesCarousel()

Widget _buildImagesCarousel() {
  // If no pictures, show a Stack with "No images" + possible add button.
  if (_slidingPictures.isEmpty) {
    return Stack(
      children: [
        Container(
          color: _isDarkMode ? Colors.grey.shade900 : Colors.grey.shade200,
          child: Center(
            child: Text(
              'No Images Available',
              style: TextStyle(
                color: _isDarkMode ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ),
        ),
        // Add button for admin
        if (_isAdmin)
          Positioned(
            top: 16,
            left: 16,
            child: GestureDetector(
              onTap: _handleAddSlidingPicture,
              child: Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: _isDarkMode
                      ? Colors.white.withOpacity(0.1)
                      : Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  color: _isDarkMode ? Colors.white : Colors.black,
                  size: 24,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // If we have pictures, build the normal stacked PageView + add icon
  final displayed = _slidingPictures.take(5).toList();
  return Stack(
    children: [
      PageView.builder(
        itemCount: displayed.length,
        onPageChanged: (index) => setState(() => _currentImageIndex = index),
        itemBuilder: (context, index) {
          final imageUrl = displayed[index];
          // Long press => let admin reorder or delete
          return GestureDetector(
            onLongPress: () {
              if (_isAdmin) {
                _showManageImages();
              }
            },
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.grey.shade300),
              errorWidget: (_, __, ___) => Container(color: Colors.grey),
            ),
          );
        },
      ),
      Positioned(
        bottom: 16,
        left: 0,
        right: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(displayed.length, (idx) {
            final isActive = (idx == _currentImageIndex);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 10,
              height: 3,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFD76D77)
                    : (_isDarkMode ? Colors.grey : Colors.grey.shade400),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ),
      // Add icon => pick/upload more images (if admin)
      if (_isAdmin)
        Positioned(
          top: 16,
          left: 16,
          child: GestureDetector(
            onTap: _handleAddSlidingPicture,
            child: Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: _isDarkMode
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isDarkMode ? Colors.white70 : Colors.black54,
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add,
                color: _isDarkMode ? Colors.white : Colors.black,
                size: 24,
              ),
            ),
          ),
        ),
    ],
  );
}

  Widget _buildExpandableDescription(String description) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey.shade900 : Colors.white,
        border: Border.all(
          color: _isDarkMode ? Colors.white30 : Colors.grey.shade300,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 15,
            ),
            maxLines: _showAdditionalInfo ? null : 3,
            overflow:
                _showAdditionalInfo ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () =>
                  setState(() => _showAdditionalInfo = !_showAdditionalInfo),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _showAdditionalInfo ? "Show Less" : "Learn More",
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    _showAdditionalInfo
                        ? Icons.arrow_drop_up
                        : Icons.arrow_drop_down,
                    color: _isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // TAGS SECTION
  // ---------------------------------------------------------
  Widget _buildTagsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isDarkMode ? Colors.white30 : Colors.grey.shade400,
          width: 1.5,
        ),
      ),
      child: _isAdmin
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tags",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Create a notification entry for your members or just your admin team.",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<bool>(
                        value: true,
                        groupValue: _notifyAllMembers,
                        onChanged: (val) {
                          setState(() => _notifyAllMembers = val ?? true);
                        },
                        title: Text(
                          "Notify All Members",
                          style: TextStyle(
                            color: _isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        activeColor: Colors.greenAccent,
                      ),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    // color of text/icon = white:
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black,
                    ),
                    onPressed: _showSendNotificationDialog,
                    child: const Text("Create Tag Notification"),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tags",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Important alerts posted by Admin.",
                  style: TextStyle(
                    color: _isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
    );
  }

  void _showSendNotificationDialog() {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    _notifImageFile = null;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final Color bgColor = _isDarkMode ? Colors.black : Colors.white;

        return StatefulBuilder(
          builder: (ctx, setStateModal) {
            return AlertDialog(
              backgroundColor: bgColor,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                "Create Tag Notification",
                style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(
                      controller: titleCtrl,
                      style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Title",
                        labelStyle: TextStyle(
                          color: _isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 3,
                      style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        labelText: "Body",
                        labelStyle: TextStyle(
                          color: _isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.white70),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _notifImageFile == null
                                ? "No image"
                                : "Image Selected",
                            style: TextStyle(
                              color:
                                  _isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            // *** Force icon & text to be white:
                            foregroundColor: Colors.white,
                            // Keep or adjust background if you wish:
                            backgroundColor: _isDarkMode
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                          onPressed: () async {
                            final pickedFile = await iPicker.ImagePicker()
                                .pickImage(source: iPicker.ImageSource.gallery);
                            if (pickedFile == null) return;
                            setStateModal(() {
                              _notifImageFile = File(pickedFile.path);
                            });
                          },
                          icon: const Icon(Icons.upload),
                          label: const Text("Pick Image"),
                        )
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(dialogCtx);

                    final notifTitle = titleCtrl.text.trim();
                    final notifBody = bodyCtrl.text.trim();
                    String? uploadedImageUrl;

                    if (_notifImageFile != null) {
                      setState(() => _isLoading = true);
                      try {
                        final storageRef = FirebaseStorage.instance
                            .ref()
                            .child('notifications')
                            .child(clubId)
                            .child(
                                '$notifTitle-${DateTime.now().millisecondsSinceEpoch}.png');
                        final snapshot =
                            await storageRef.putFile(_notifImageFile!);
                        uploadedImageUrl = await snapshot.ref.getDownloadURL();
                      } catch (e) {
                        debugPrint("Error uploading notification image: $e");
                        uploadedImageUrl = null;
                      } finally {
                        setState(() => _isLoading = false);
                      }
                    }

                    try {
                      final tagData = {
                        "title": notifTitle.isNotEmpty ? notifTitle : "New Tag",
                        "message": notifBody,
                        "createdAt": FieldValue.serverTimestamp(),
                        "notifyAll": _notifyAllMembers,
                        if (uploadedImageUrl != null)
                          "imageUrl": uploadedImageUrl,
                      };

                      await FirebaseFirestore.instance
                          .collection('clubs')
                          .doc(clubId)
                          .collection('tagNotifications')
                          .add(tagData);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Tag Notification doc created!"),
                        ),
                      );
                    } catch (e) {
                      debugPrint("Error creating tag doc: $e");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
                  child: Text(
                    "SAVE",
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------
  // MEMBERS MODAL
  // ---------------------------------------------------------
  void _showMembersModal(String clubId, String clubName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? const Color(0xFF2C2C2C) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return FutureBuilder<void>(
          future: _fetchMembersFromFirebase(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: MediaQuery.of(ctx).size.height * 0.75,
                child: Center(
                  child: Text(
                    "Error fetching members: ${snapshot.error}",
                    style: TextStyle(
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              );
            }
            final allMembers = _members;
            final searchCtrl = TextEditingController();

            return StatefulBuilder(
              builder: (modalCtx, setStateModal) {
                final filtered = allMembers.where((m) {
                  final n = (m['name'] ?? '').toLowerCase();
                  return n.contains(searchCtrl.text.toLowerCase().trim());
                }).toList();

                return Container(
                  height: MediaQuery.of(ctx).size.height * 0.75,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "$clubName Members",
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchCtrl,
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                        ),
                        decoration: InputDecoration(
                          hintText: "Search members...",
                          hintStyle: TextStyle(
                            color:
                                _isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                          filled: true,
                          fillColor: _isDarkMode
                              ? const Color(0xFF1F1F1F)
                              : Colors.grey.shade200,
                          prefixIcon: Icon(Icons.search,
                              color: _isDarkMode
                                  ? Colors.white54
                                  : Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (val) {
                          setStateModal(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  "No members found.",
                                  style: TextStyle(
                                    color: _isDarkMode
                                        ? Colors.white70
                                        : Colors.black54,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (_, i) {
                                  final name =
                                      filtered[i]['name'] ?? 'Member';
                                  final photoUrl =
                                      filtered[i]['photoUrl'] ?? '';

                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _isDarkMode
                                          ? Colors.white24
                                          : Colors.black12,
                                      backgroundImage: photoUrl.isNotEmpty
                                          ? NetworkImage(photoUrl)
                                          : null,
                                      child: photoUrl.isNotEmpty
                                          ? null
                                          : Text(
                                              name.isNotEmpty
                                                  ? name[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                    title: Text(
                                      name,
                                      style: TextStyle(
                                        color: _isDarkMode
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAdditionalDetails() {
    final clubName = clubData['name'] ?? 'No Name';
    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.people,
            color: _isDarkMode ? Colors.white70 : Colors.black54,
          ),
          title: Text(
            "View Members",
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          onTap: () => _showMembersModal(clubId, clubName),
        ),
        if (_isAdmin)
          ListTile(
            leading: Icon(
              Icons.admin_panel_settings,
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
            title: Text(
              "Admin Panel",
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdminPanelPage(clubId: clubId, clubName: clubName),
              ),
            ),
          )
        else if (_isFollowing)
          ListTile(
            leading: Icon(
              Icons.settings,
              color: _isDarkMode ? Colors.white70 : Colors.black54,
            ),
            title: Text(
              "Member Settings",
              style: TextStyle(
                color: _isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MemberSettingsPage(
                  clubId: clubId,
                  clubName: clubName,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------
  //  BOTTOM ACTION CARDS (PINNED / STUCK)
  // ---------------------------------------------------------
  Widget _buildBottomActionRow() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 120,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.black54 : Colors.white70,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 6,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildBottomActionCard(
              icon: Icons.poll,
              label: "Polls",
              onTap: _handlePolls,
            ),
            _buildBottomActionCard(
              icon: Icons.how_to_reg,
              label: "Attendance",
              onTap: _handleAttendance,
            ),
            _buildBottomActionCard(
              icon: Icons.feedback,
              label: "Feedback",
              onTap: _handleAnonymousFeedback,
            ),
          ],
        ),
      ),
    );
  }

Widget _buildBottomActionCard({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(12),
      // no width property
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: _isDarkMode ? Colors.black : Colors.white),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _isDarkMode ? Colors.black : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    ),
  );
}

  // ---------------------------------------------------------
  //  POLLS LOGIC
  // ---------------------------------------------------------
  void _handlePolls() {
    // If admin => create poll, else => show poll list & let members vote
    if (_isAdmin) {
      _showCreatePollDialog();
    } else {
      _showPollsList();
    }
  }

  void _showCreatePollDialog() {
    final titleCtrl = TextEditingController();
    final List<TextEditingController> optionCtrls = [
      TextEditingController(),
      TextEditingController(),
    ];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            final alertBgColor = _isDarkMode ? Colors.grey[900] : Colors.white;
            final textColor = _isDarkMode ? Colors.white : Colors.black87;
            final hintColor = _isDarkMode ? Colors.white54 : Colors.black54;

            return AlertDialog(
              backgroundColor: alertBgColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                "Create Poll",
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    // Poll Title
                    Container(
                      decoration: BoxDecoration(
                        color:
                            _isDarkMode ? Colors.grey[800] : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: titleCtrl,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Poll Title",
                          hintStyle: TextStyle(color: hintColor),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Poll Options
                    Column(
                      children: List.generate(optionCtrls.length, (index) {
                        // *** Wrap each option in a Dismissible:
                        return Dismissible(
                          key: ValueKey('option_$index'),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (direction) async {
                            // Prevent dropping below 2 total
                            if (optionCtrls.length <= 2) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Cannot remove. Minimum 2 options required.',
                                  ),
                                ),
                              );
                              return false;
                            }
                            return true;
                          },
                          background: Container(
                            color: const Color(0xFFFF073A), // "neon red"
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: const Icon(Icons.delete,
                                color: Colors.white, size: 30),
                          ),
                          onDismissed: (direction) {
                            setStateDialog(() {
                              optionCtrls.removeAt(index);
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: _isDarkMode
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TextField(
                              controller: optionCtrls[index],
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(
                                hintText: "Option ${index + 1}",
                                hintStyle: TextStyle(color: hintColor),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    // plus arrow below the options
                    if (optionCtrls.length < 10)
                      GestureDetector(
                        onTap: () {
                          setStateDialog(() {
                            optionCtrls.add(TextEditingController());
                          });
                        },
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _isDarkMode
                                ? Colors.grey[700]
                                : Colors.grey[300],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            color: textColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final pollTitle = titleCtrl.text.trim();
                    if (pollTitle.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Poll must have a title.")),
                      );
                      return;
                    }

                    final List<Map<String, dynamic>> pollOptions = [];
                    for (var c in optionCtrls) {
                      final text = c.text.trim();
                      if (text.isNotEmpty) {
                        pollOptions.add({"option": text, "votes": 0});
                      }
                    }
                    if (pollOptions.length < 2) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("At least 2 options are required.")),
                      );
                      return;
                    }

                    final now = DateTime.now();
                    final endsAt = now.add(const Duration(minutes: 15));
                    final pollData = {
                      "title": pollTitle,
                      "createdAt": FieldValue.serverTimestamp(),
                      "endsAt": endsAt.millisecondsSinceEpoch,
                      "isClosed": false,
                      "options": pollOptions,
                      "votes": {},
                    };

                    try {
                      await FirebaseFirestore.instance
                          .collection('clubs')
                          .doc(clubId)
                          .collection('polls')
                          .add(pollData);

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Poll created!")),
                      );
                    } catch (e) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: $e")),
                      );
                    }
                  },
                  child: Text(
                    "Create",
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPollsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('clubs')
              .doc(clubId)
              .collection('polls')
              .orderBy('createdAt', descending: true)
              .get(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return SizedBox(
                height: 200,
                child: Center(
                  child: Text("Error: ${snapshot.error}"),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text("No polls found.")),
              );
            }

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              builder: (_, controller) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        "Available Polls",
                        style: TextStyle(
                          color: _isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: controller,
                          itemCount: docs.length,
                          itemBuilder: (ctx, i) {
                            final data = docs[i].data() as Map<String, dynamic>;
                            final title = data["title"] ?? "No Title";
                            bool isClosed = data["isClosed"] == true;

                            final endsAt = data["endsAt"] ?? 0;
                            if (DateTime.now().millisecondsSinceEpoch > endsAt) {
                              isClosed = true;
                            }

                            return ListTile(
                              title: Text(
                                title,
                                style: TextStyle(
                                  color: _isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                              trailing: isClosed
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          "Closed",
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.circle,
                                            color: Colors.grey.shade500,
                                            size: 10),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          "Active",
                                          style: TextStyle(
                                              color: Colors.greenAccent),
                                        ),
                                        SizedBox(width: 6),
                                        Icon(Icons.circle,
                                            color: Colors.greenAccent, size: 10),
                                      ],
                                    ),
                              onTap: isClosed
                                  ? null
                                  : () {
                                      final pollId = docs[i].id;
                                      _showVoteDialog(pollId, data);
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
          },
        );
      },
    );
  }

  void _showVoteDialog(String pollId, Map<String, dynamic> pollData) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? currentUserId;
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be logged in to vote.")),
      );
      return;
    }

    final Map<String, dynamic> existingVotes =
        (pollData["votes"] ?? {}) as Map<String, dynamic>;
    if (existingVotes.containsKey(uid)) {
      final votedIndex = existingVotes[uid];
      final chosenOption = pollData["options"][votedIndex]["option"];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You already voted for '$chosenOption'.")),
      );
      return;
    }

    final List options = pollData["options"] ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        int selectedIndex = -1;

        return StatefulBuilder(
          builder: (dialogCtx, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.white, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(
                pollData["title"] ?? "No Title",
                style: const TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  children: List.generate(options.length, (index) {
                    final optionText = options[index]["option"] ?? "No text";
                    return RadioListTile<int>(
                      activeColor: Colors.greenAccent,
                      value: index,
                      groupValue: selectedIndex,
                      onChanged: (val) {
                        if (val == null) return;
                        setStateDialog(() {
                          selectedIndex = val;
                        });
                      },
                      title: Text(
                        optionText,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    if (selectedIndex < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please select an option.")),
                      );
                      return;
                    }
                    Navigator.pop(ctx);

                    try {
                      final pollRef = FirebaseFirestore.instance
                          .collection('clubs')
                          .doc(clubId)
                          .collection('polls')
                          .doc(pollId);

                      await FirebaseFirestore.instance
                          .runTransaction((transaction) async {
                        final snap = await transaction.get(pollRef);
                        if (!snap.exists) return;

                        final data = snap.data() as Map<String, dynamic>;
                        final Map<String, dynamic> votes =
                            (data["votes"] ?? {}) as Map<String, dynamic>;
                        final List<dynamic> updatedOptions = data["options"] ?? [];

                        if (votes.containsKey(uid)) return;

                        votes[uid] = selectedIndex;
                        updatedOptions[selectedIndex]["votes"] =
                            (updatedOptions[selectedIndex]["votes"] ?? 0) + 1;

                        transaction.update(pollRef, {
                          "votes": votes,
                          "options": updatedOptions,
                        });
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Thanks for voting!")),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error saving vote: $e")),
                      );
                    }
                  },
                  child:
                      const Text("Vote", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------
  void _handleAttendance() {
    if (!_isAdmin) {
      _showEnterAttendanceCodeDialog();
    } else {
      _showCreateAttendanceDialog();
    }
  }

  void _showCreateAttendanceDialog() {
    final titleCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          title:
              const Text("Create Attendance", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: "Attendance Title",
              hintStyle: TextStyle(color: Colors.white70),
              labelText: "Attendance Title",
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.pop(ctx),
            ),
            TextButton(
              child: const Text("Go Live",
                  style: TextStyle(color: Colors.greenAccent)),
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Title can't be empty.")),
                  );
                  return;
                }
                final code = _random.nextInt(900) + 100;
                final docId = title.replaceAll(' ', '_') +
                    "_${DateTime.now().millisecondsSinceEpoch}";

                final attendanceData = {
                  "title": title,
                  "code": code,
                  "isLive": true,
                  "startedAt": FieldValue.serverTimestamp(),
                };

                try {
                  final docRef = FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('attendance')
                      .doc(docId);

                  await docRef.set(attendanceData);

                  setState(() {
                    _activeAttendance = {
                      "docId": docId,
                      ...attendanceData,
                    };
                  });

                  Navigator.pop(ctx);
                  _showAttendanceLiveOverlay();
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showAttendanceLiveOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final attendanceCode = _activeAttendance?['code'] ?? 000;
        final eventTitle = _activeAttendance?['title'] ?? "No Title";
        return Dialog(
          backgroundColor: _isDarkMode ? Colors.grey[850] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: Container(
                width: 300,
                padding: const EdgeInsets.all(30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _isDarkMode ? Colors.white : Colors.black87,
                        ),
                        strokeWidth: 8,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "$attendanceCode",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Lovelo',
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Live: $eventTitle",
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'Lovelo',
                        color: _isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => _endAttendanceSession(ctx),
                      child: const Text("End Attendance"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _endAttendanceSession(BuildContext dialogCtx) async {
    if (_activeAttendance == null) {
      Navigator.pop(dialogCtx);
      return;
    }
    try {
      final docId = _activeAttendance!['docId'];
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('attendance')
          .doc(docId)
          .update({"isLive": false});

      _activeAttendance = null;
      Navigator.pop(dialogCtx);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Attendance ended!")),
      );
    } catch (e) {
      Navigator.pop(dialogCtx);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error ending attendance: $e")),
      );
    }
  }

  void _showEnterAttendanceCodeDialog() {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Text("Enter Attendance Code",
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: codeCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Code",
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                final entered = int.tryParse(codeCtrl.text.trim()) ?? 0;
                final sessionsSnap = await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .collection('attendance')
                    .where('code', isEqualTo: entered)
                    .where('isLive', isEqualTo: true)
                    .get();

                if (sessionsSnap.docs.isEmpty) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid or inactive code.")),
                  );
                  return;
                }

                final doc = sessionsSnap.docs.first;
                final docId = doc.id;
                final uid =
                    FirebaseAuth.instance.currentUser?.uid ?? currentUserId;

                try {
                  final userDoc = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .get();
                  final userData = userDoc.data() ?? {};
                  final fullName = userData['fullName'] ?? "No Name";
                  final username = userData['username'] ?? "(unknown)";

                  // Save in subcollection "attendees"
                  await FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('attendance')
                      .doc(docId)
                      .collection('attendees')
                      .doc(uid)
                      .set({
                    'fullName': fullName,
                    'username': username,
                    'checkedInAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Attendance marked!")),
                  );
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              child: const Text("Submit", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------
  // Anonymous Feedback
  // ---------------------------------------------------------
  void _handleAnonymousFeedback() {
    _showFeedbackDialog();
  }

  void _showFeedbackDialog() {
    final feedbackCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.white, width: 1.5),
            borderRadius: BorderRadius.circular(12),
          ),
          title:
              const Text("Anonymous Feedback", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: feedbackCtrl,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Type feedback here...",
              labelStyle: TextStyle(color: Colors.white70),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white70),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                final feedbackTxt = feedbackCtrl.text.trim();
                if (feedbackTxt.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }

                final feedbackData = {
                  "feedback": feedbackTxt,
                  "createdAt": FieldValue.serverTimestamp(),
                };

                try {
                  await FirebaseFirestore.instance
                      .collection('clubs')
                      .doc(clubId)
                      .collection('anonymousFeedback')
                      .add(feedbackData);

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Thanks for your feedback!")),
                  );
                } catch (e) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              },
              child: const Text("Send", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final clubName = clubData['name'] ?? 'No Name';
    final description = clubData['description'] ?? 'No description available.';

    return Scaffold(
      key: _scaffoldKey,
      drawer: ClubDrawerPage(
        clubId: clubId,
        clubName: clubData['name'] ?? 'No Name',
        pfpUrl: clubData['pfpUrl'] ?? '',
        isDarkMode: _isDarkMode,
        isAdmin: _isAdmin,
        memberCount: _memberCount,
        socials: _socials,

        // Callback when user leaves club:
        onUserLeftClub: () {
          setState(() => _isFollowing = false);
          setState(() => _isAdmin = false);
        },
      ),
      backgroundColor:
          _isDarkMode ? const Color(0xFF121212) : Colors.grey.shade100,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildTopHeader(clubName),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 10,
                    ),
                    child: _buildHeroSectionWrapper(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          height: 240,
                          child: _buildImagesCarousel(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildExpandableDescription(description),
                  _buildMiddleNavBar(),
                  const SizedBox(height: 12),
                  _buildTagsSection(),
                  const SizedBox(height: 180),
                  if (_showAdditionalInfo) _buildAdditionalDetails(),
                ],
              ),
            ),
            _buildBottomActionRow(),
            if (_isLoading)
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

  // ---------------------------------------------------------
  // REPORT FLOW
  // ---------------------------------------------------------
  void _showReportDialog() {
    final List<String> reportCategories = [
      "Hate Speech",
      "Harassment",
      "Spam",
      "NSFW Content",
      "Impersonation",
    ];
    String selectedCategory = reportCategories.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Report Community"),
          content: StatefulBuilder(
            builder: (context, setStateSB) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select a reason for reporting this content:",
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: selectedCategory,
                    icon: const Icon(Icons.arrow_drop_down),
                    onChanged: (val) {
                      if (val != null) setStateSB(() => selectedCategory = val);
                    },
                    items: reportCategories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
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
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _confirmReport(selectedCategory);
              },
              child: const Text("Next"),
            ),
          ],
        );
      },
    );
  }

  void _confirmReport(String category) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Confirm Report"),
          content: Text(
            'Are you sure you want to report this content for "$category"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("No"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _submitReport(category);
              },
              child: const Text("Yes, Report"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitReport(String category) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to report.')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'clubId': clubId,
        'reporterId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'category': category,
      });
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Report Received'),
          content: const Text('Thanks! We have received your report.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint("Error submitting report: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Report failed: $e')),
      );
    }
  }
}

// Stub admin panel page
class AdminPanelPage extends StatelessWidget {
  final String clubId;
  final String clubName;
  const AdminPanelPage({Key? key, required this.clubId, required this.clubName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin Panel: $clubName")),
      body: const Center(child: Text("Admin Panel Content")),
    );
  }
}

// Stub member settings page
class MemberSettingsPage extends StatelessWidget {
  final String clubId;
  final String clubName;
  const MemberSettingsPage(
      {Key? key, required this.clubId, required this.clubName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Member Settings: $clubName")),
      body: const Center(child: Text("Member Settings Content")),
    );
  }
}
