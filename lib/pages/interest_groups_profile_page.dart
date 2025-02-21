import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ragtagrevived/pages/all_organizations.dart';

/// A redesigned interest (or class) groups page showing group details, events, resources, etc.
class RedesignedInterestGroupsPage extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic> communityData;
  final String userId;
  final String collectionName; // can pass "classGroups" if needed

  const RedesignedInterestGroupsPage({
    Key? key,
    required this.communityId,
    required this.communityData,
    required this.userId,
    this.collectionName = 'interestGroups',
  }) : super(key: key);

  @override
  State<RedesignedInterestGroupsPage> createState() =>
      _RedesignedInterestGroupsPageState();
}

class _RedesignedInterestGroupsPageState
    extends State<RedesignedInterestGroupsPage> with TickerProviderStateMixin {
  late String communityId;
  late Map<String, dynamic> communityData;
  late String userId;
  late String collectionName;

  bool isAdmin = false;
  bool isMember = false;
  bool isDarkMode = true;
  bool isGhostMode = false;

  // We'll store certain data in local state
  List<Map<String, dynamic>> eventList = [];
  List<Map<String, dynamic>> resourceList = [];

  // Group tasks
  List<Map<String, dynamic>> _groupTodos = [];
  // Each user’s check state for those tasks
  Map<String, bool> _myTodoStatus = {};

  int memberCount = 0;
  bool isLoading = false;

  // We'll hold the *full* list of members here so we can display them in a popup
  List<Map<String, dynamic>> _membersList = [];

  // Animations (hero + tab fade)
  late AnimationController _heroController;
  late Animation<double> _heroAnimation;
  late AnimationController _tabController;

  // We'll keep user-chosen date/time in these variables when creating a new event
  DateTime? _chosenEventDate;
  TimeOfDay? _chosenEventTime;

  // A gradient for outlines
  final LinearGradient ragtagGradient = const LinearGradient(
    colors: [
      Color(0xFFFFAF7B),
      Color(0xFFD76D77),
      Color(0xFF1C6971),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Members can add if:
  ///   - The group is a "classGroups" doc
  ///   - The user is a member
  ///   - Or the user is an admin
  bool get canAddCalendar =>
      isAdmin || (isMember && collectionName == 'classGroups');
  bool get canAddTodo =>
      isAdmin || (isMember && collectionName == 'classGroups');

  /// Let admins OR class group members edit/delete events/tasks
  bool get canEditOrDelete =>
      isAdmin || (isMember && collectionName == 'classGroups');

  @override
  void initState() {
    super.initState();

    // Extract the constructor arguments
    communityId = widget.communityId;
    communityData = widget.communityData;
    userId = widget.userId;
    collectionName = widget.collectionName;

    // Hero animation
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _heroAnimation = CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutQuad,
    );

    // Tab fade animation
    _tabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Kick off hero animation
    _heroController.forward();

    // Once hero animation is done, fetch data, then do tab fade
    _fetchAllData().then((_) {
      _tabController.forward();
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  //  1) DATA FETCHING
  // ---------------------------------------------------------------------------
  Future<void> _fetchAllData() async {
    if (communityId.isEmpty) return;

    setState(() => isLoading = true);
    try {
      // Basic group info
      await _fetchGroupInfo();

      // Are we an admin?
      await _checkIfUserIsAdmin();

      // Are we a member?
      await _fetchMembershipSubcollection();

      // Get events + resources
      await _fetchEventsAndResources();

      // Group todos
      await _fetchGroupTodos();

      // My personal "todo" status
      await _fetchMyTodoStatus();
    } catch (e) {
      _showSnack("Error fetching data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchGroupInfo() async {
    final docRef =
        FirebaseFirestore.instance.collection(collectionName).doc(communityId);
    final snapshot = await docRef.get();
    final data = snapshot.data();

    if (data != null) {
      setState(() {
        communityData['name'] = data['name'] ?? '';
        communityData['pfpUrl'] = data['pfpUrl'] ?? '';
        communityData['pfpType'] = data['pfpType'] ?? '';
        communityData['pfpText'] = data['pfpText'] ?? '';
        communityData['backgroundColor'] = data['backgroundColor'] ?? '';
        communityData['description'] = data['description'] ?? '';
        communityData['isGhostMode'] = data['isGhostMode'] ?? false;
        isGhostMode = communityData['isGhostMode'];
      });
    } else {
      _showSnack("This group does not exist in Firestore ($collectionName).");
    }
  }

  Future<void> _checkIfUserIsAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final adminDocRef = FirebaseFirestore.instance
        .collection(collectionName)
        .doc(communityId)
        .collection('admins')
        .doc(uid);

    final adminDocSnap = await adminDocRef.get();
    setState(() => isAdmin = adminDocSnap.exists);
  }

  /// Subcollection-based membership:
  /// {collectionName}/{communityId}/members/{uid}
  Future<void> _fetchMembershipSubcollection() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final memberDocRef = FirebaseFirestore.instance
        .collection(collectionName)
        .doc(communityId)
        .collection('members')
        .doc(uid);

    final memberSnap = await memberDocRef.get();
    setState(() => isMember = memberSnap.exists);

    // For counting total members, read entire subcollection
    final membersSnap = await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(communityId)
        .collection('members')
        .get();

    // We also store the entire member list so we can show them in a popup
    final allMembers = membersSnap.docs.map((doc) {
      return {
        ...doc.data(),
        'id': doc.id,
      };
    }).toList();

    setState(() {
      memberCount = membersSnap.size;
      _membersList = allMembers;
    });
  }

  Future<void> _fetchEventsAndResources() async {
    final eventsSnap = await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(communityId)
        .collection('events')
        .get();

    final resourcesSnap = await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(communityId)
        .collection('resources')
        .get();

    setState(() {
      eventList = eventsSnap.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
      resourceList = resourcesSnap.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    });
  }

  Future<void> _fetchGroupTodos() async {
    final todosSnap = await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(communityId)
        .collection('todos')
        .get();

    setState(() {
      _groupTodos = todosSnap.docs
          .map((doc) => {
                ...doc.data(),
                'id': doc.id,
              })
          .toList();
    });
  }

  /// Each user has a subcollection of their todo statuses:
  /// {collectionName}/{communityId}/members/{uid}/todosStatus/{todoId}
  Future<void> _fetchMyTodoStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance
        .collection(collectionName)
        .doc(communityId)
        .collection('members')
        .doc(uid)
        .collection('todosStatus');

    final querySnap = await docRef.get();

    final Map<String, bool> statuses = {};
    for (var doc in querySnap.docs) {
      statuses[doc.id] = doc.data()['checked'] == true;
    }

    setState(() {
      _myTodoStatus = statuses;
    });
  }

  // ---------------------------------------------------------------------------
  //  2) JOIN / LEAVE GROUP
  // ---------------------------------------------------------------------------
  Future<void> _toggleMembership() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (communityId.isEmpty) return;

    setState(() => isLoading = true);

    final memberDocRef = FirebaseFirestore.instance
        .collection(collectionName)
        .doc(communityId)
        .collection('members')
        .doc(uid);

    if (isMember) {
      // Already in subcollection => remove
      try {
        await memberDocRef.delete();
        setState(() {
          isMember = false;
          if (memberCount > 0) {
            memberCount--;
          }
          _membersList.removeWhere((member) => member['uid'] == uid);
        });
        _showSnack("You left the group.");
      } catch (e) {
        _showSnack("Error leaving group: $e");
      }
    } else {
      // Not in subcollection => add
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final fullName = userDoc.data()?['fullName'] ?? 'UnknownUser';

        await memberDocRef.set({
          'uid': uid,
          'fullName': fullName,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          isMember = true;
          memberCount++;
          _membersList.add({
            'uid': uid,
            'fullName': fullName,
          });
        });
        _showSnack("Welcome to the group!");
      } catch (e) {
        _showSnack("Error joining group: $e");
      }
    }

    setState(() => isLoading = false);
  }

  // ---------------------------------------------------------------------------
  //  3) TOGGLE GHOST MODE
  // ---------------------------------------------------------------------------
  Future<void> _toggleGhostMode(bool value) async {
    // Let admins or class group members do it
    if (!(isAdmin || (isMember && collectionName == 'classGroups'))) {
      _showSnack("Only admins or class group members can toggle Ghost Mode.");
      return;
    }
    if (communityId.isEmpty) return;

    setState(() {
      isGhostMode = value;
    });

    final groupDoc =
        FirebaseFirestore.instance.collection(collectionName).doc(communityId);
    await groupDoc.update({'isGhostMode': value});

    // Show popup only when turning it on
    if (value) {
      _showGhostModePopup();
    }
  }

  void _showGhostModePopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 80,
                child: Image.asset(
                  'assets/icons/ghost.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Boo! You're in Ghost Mode",
                style: GoogleFonts.workSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Only members can see this group. Outsiders won't find or join without an invite.",
                style: GoogleFonts.workSans(
                  fontSize: 15,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey[200] : Colors.grey[800],
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Understood"),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  //  4) BUILD UI
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final groupName = communityData['name'] ?? '';

    return Scaffold(
      backgroundColor:
          isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF8F8F8),
      // FABs pinned at bottom in a Row
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "Add Event" FAB
          if (canAddCalendar)
            FloatingActionButton.extended(
              heroTag: "fab_add_event",
              // For dark mode → button is white, text black
              // For light mode → button is black, text white
              backgroundColor: isDarkMode ? Colors.white : Colors.black,
              foregroundColor: isDarkMode ? Colors.black : Colors.white,
              icon: const Icon(Icons.event),
              label: const Text("Add Event"),
              onPressed: _showAddEventDialogDirect,
            ),
          const SizedBox(width: 12),
          // "Add Task" FAB
          if (canAddTodo)
            FloatingActionButton.extended(
              heroTag: "fab_add_task",
              backgroundColor: isDarkMode ? Colors.white : Colors.black,
              foregroundColor: isDarkMode ? Colors.black : Colors.white,
              icon: const Icon(Icons.add_task),
              label: const Text("Add Task"),
              onPressed: _showAddTodoDialogDirect,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1) Hero Banner
            _buildHeroBanner(groupName),

            // 2) Fade in rest
            FadeTransition(
              opacity: _tabController,
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildTopActions(),
                  const SizedBox(height: 16),

                  // 3-button row (Calendar / Chat / To-Do)
                  _buildButtonsRow(),
                  const SizedBox(height: 20),

                  // Description
                  if ((communityData['description'] ?? '').isNotEmpty)
                    _buildDescriptionCard(communityData['description']!),

                  // Ghost Mode
                  if (isAdmin || (isMember && collectionName == 'classGroups'))
                    _buildGhostModeTile(),

                  // Join / leave
                  _buildMemberActionCard(),
                ],
              ),
            ),

            // 3) We'll put the “Upcoming Events” & “To-Do” side by side,
            // and the “Resources” below them, each in its own scrollable block.
            Expanded(
              child: FadeTransition(
                opacity: _tabController,
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // Side-by-side row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Left half: Upcoming Events
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(
                                    'Upcoming Events',
                                    Icons.event_outlined,
                                  ),
                                  Container(
                                    height: 200,
                                    child: _buildEventsListScroll(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Right half: To-Do
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle(
                                    'To-Do',
                                    Icons.checklist_outlined,
                                  ),
                                  Container(
                                    height: 200,
                                    child: _buildInlineTodoListScroll(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Resources
                      if (resourceList.isNotEmpty) ...[
                        _buildSectionTitle('Resources', Icons.link_outlined),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            height: 150,
                            child: _buildResourcesListScroll(),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // If loading, overlay
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

  // ---------------------------------------------------------------------------
  //  4A) Hero Banner
  // ---------------------------------------------------------------------------
  Widget _buildHeroBanner(String groupName) {
    final pfpUrl = communityData['pfpUrl'] ?? '';
    final pfpType = communityData['pfpType'] ?? '';
    final pfpText = communityData['pfpText'] ?? '';
    final backgroundColorHex = communityData['backgroundColor'] ?? '';

    return AnimatedBuilder(
      animation: _heroAnimation,
      builder: (context, child) {
        final scaleValue = 1.0 + 0.03 * _heroAnimation.value;

        final bool isTextAvatar = (pfpType == 'textAvatar') &&
            pfpText.isNotEmpty &&
            backgroundColorHex.isNotEmpty;

        if (isTextAvatar) {
          Color bgColor;
          try {
            final colorVal = int.parse(backgroundColorHex);
            bgColor = Color(colorVal);
          } catch (_) {
            bgColor = Colors.grey.shade700;
          }

          return SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(
              children: [
                Container(color: bgColor),
                Container(color: Colors.black45),
                Align(
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: scaleValue,
                    child: Text(
                      groupName,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 32,
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
              ],
            ),
          );
        }

        if (pfpUrl.isNotEmpty) {
          return SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(pfpUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Container(color: Colors.black.withOpacity(0.35)),
                Align(
                  alignment: Alignment.center,
                  child: Transform.scale(
                    scale: scaleValue,
                    child: Text(
                      groupName,
                      style: GoogleFonts.workSans(
                        color: Colors.white,
                        fontSize: 32,
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
              ],
            ),
          );
        }

        // fallback
        return SizedBox(
          height: 260,
          width: double.infinity,
          child: Stack(
            children: [
              Container(color: Colors.grey.shade700),
              Container(color: Colors.black45),
              Align(
                alignment: Alignment.center,
                child: Transform.scale(
                  scale: scaleValue,
                  child: Text(
                    groupName,
                    style: GoogleFonts.workSans(
                      color: Colors.white,
                      fontSize: 32,
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
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  //  4B) TOP ACTIONS
  // ---------------------------------------------------------------------------
  Widget _buildTopActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          InkWell(
            // Modified back button to navigate to AllOrganizationsPage instead of simply popping.
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (context) => AllOrganizationsPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.arrow_back,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          const Spacer(),

          // Dark/Light Mode Toggle
          _buildIconAction(
            icon: isDarkMode
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
            onTap: () => setState(() => isDarkMode = !isDarkMode),
            tooltip: "Toggle Dark Mode",
          ),

          // Report
          _buildIconAction(
            icon: Icons.flag,
            onTap: _showReportDialog,
            tooltip: "Report This Group",
          ),

          // Members
          _buildIconAction(
            icon: Icons.people_outline,
            onTap: _showMembersList,
            tooltip: "View Members",
          ),

          // If Admin: “Edit Group”
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.only(left: 4.0),
              child: InkWell(
                onTap: () {
                  // Navigation example - adjust as needed
                  Navigator.pushNamed(context, '/admin-dashboard');
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.edit,
                        size: 18,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Edit Group',
                        style: GoogleFonts.workSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
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

  Widget _buildIconAction({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isDarkMode ? Colors.white70 : Colors.black87,
        ),
        tooltip: tooltip,
        onPressed: onTap,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  4C) 3-button row  (Calendar, Chat, To-Do)
  // ---------------------------------------------------------------------------
  Widget _buildButtonsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: Icons.calendar_today_outlined,
              label: 'Calendar',
              onTap: _showCalendarPopup,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionCard(
              icon: Icons.chat_outlined,
              label: 'Chat',
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/group-chat',
                  arguments: {
                    'communityId': communityId,
                    'communityName': communityData['name'],
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionCard(
              icon: Icons.checklist_outlined,
              label: 'To-Do',
              onTap: _showTodoPopup,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: _buildGradientOutline(
        SizedBox(
          height: 120,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.workSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOutline(Widget child) {
    return Container(
      decoration: BoxDecoration(
        gradient: ragtagGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  4D) DESCRIPTION & GHOST MODE & MEMBER COUNT
  // ---------------------------------------------------------------------------
  Widget _buildDescriptionCard(String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            description,
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGhostModeTile() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: SwitchListTile(
          title: Text(
            'Ghost Mode',
            style: GoogleFonts.workSans(
              fontWeight: FontWeight.w500,
              fontSize: 16,
              color: isDarkMode ? Colors.grey[200] : Colors.black87,
            ),
          ),
          subtitle: Text(
            isGhostMode
                ? "Currently invisible to outsiders"
                : "Group is publicly visible",
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
          activeColor: Colors.grey[600],
          value: isGhostMode,
          onChanged: (value) => _toggleGhostMode(value),
        ),
      ),
    );
  }

  Widget _buildMemberActionCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                Icons.people_outline,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                '$memberCount members',
                style: GoogleFonts.workSans(
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isMember ? Colors.grey[700] : Colors.grey[400],
                  foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                onPressed: _toggleMembership,
                child: Text(isMember ? 'Leave Group' : 'Join Group'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  4E) EVENTS LIST (scrollable) with onLongPress to edit/delete
  // ---------------------------------------------------------------------------
  Widget _buildEventsListScroll() {
    if (eventList.isEmpty) {
      return Center(
        child: Text(
          "No events",
          style: GoogleFonts.workSans(
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: eventList.length,
      itemBuilder: (context, index) {
        final eventData = eventList[index];
        return _buildEventTile(eventData);
      },
    );
  }

  Widget _buildEventTile(Map<String, dynamic> eventData) {
    final title = eventData['title'] ?? '';
    final dateTime = eventData['dateTime'] ?? '';
    final location = eventData['location'] ?? '';

    return Card(
      color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        // We'll show Edit/Delete on long press if canEditOrDelete
        onLongPress: canEditOrDelete
            ? () => _showEventActionsBottomSheet(eventData)
            : null,
        title: Text(
          title,
          style: GoogleFonts.workSans(
            color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (dateTime.isNotEmpty)
              Text(
                "When: $dateTime",
                style: GoogleFonts.workSans(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 13,
                ),
              ),
            if (location.isNotEmpty)
              Text(
                "Where: $location",
                style: GoogleFonts.workSans(
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 13,
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEventActionsBottomSheet(Map<String, dynamic> eventData) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Edit Event"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditEventDialog(eventData);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text("Delete Event"),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteEvent(eventData['id']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text("Cancel"),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditEventDialog(Map<String, dynamic> eventData) {
    final eventId = eventData['id'] as String;
    final titleController = TextEditingController(text: eventData['title'] ?? '');
    final locationController =
        TextEditingController(text: eventData['location'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final Color bgColor =
            isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

        return AlertDialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Edit Event",
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: GoogleFonts.workSans(
                  color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                ),
                decoration: InputDecoration(
                  labelText: "Title",
                  labelStyle: GoogleFonts.workSans(
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.grey[800]
                      : Colors.grey[200]?.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                style: GoogleFonts.workSans(
                  color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                ),
                decoration: InputDecoration(
                  labelText: "Location",
                  labelStyle: GoogleFonts.workSans(
                    color: isDarkMode ? Colors.white70 : Colors.grey[700],
                  ),
                  filled: true,
                  fillColor: isDarkMode
                      ? Colors.grey[800]
                      : Colors.grey[200]?.withOpacity(0.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey[200] : Colors.grey[800],
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[600],
                foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final location = locationController.text.trim();

                try {
                  await FirebaseFirestore.instance
                      .collection(collectionName)
                      .doc(communityId)
                      .collection('events')
                      .doc(eventId)
                      .update({
                    "title": title,
                    "location": location,
                  });

                  // Update local state
                  setState(() {
                    for (var ev in eventList) {
                      if (ev['id'] == eventId) {
                        ev['title'] = title;
                        ev['location'] = location;
                        break;
                      }
                    }
                  });
                  _showSnack("Event updated successfully!");
                } catch (e) {
                  _showSnack("Failed to update event: $e");
                }

                Navigator.pop(dialogCtx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteEvent(String eventId) async {
    if (communityId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(communityId)
          .collection('events')
          .doc(eventId)
          .delete();

      setState(() {
        eventList.removeWhere((ev) => ev['id'] == eventId);
      });
      _showSnack("Event deleted");
    } catch (e) {
      _showSnack("Error deleting event: $e");
    }
  }

  // ---------------------------------------------------------------------------
  //  4F) TODOS LIST (scrollable) with onLongPress to edit/delete
  // ---------------------------------------------------------------------------
  Widget _buildInlineTodoListScroll() {
    if (_groupTodos.isEmpty) {
      return Center(
        child: Text(
          "No tasks",
          style: GoogleFonts.workSans(
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _groupTodos.length,
      itemBuilder: (context, index) {
        final todo = _groupTodos[index];
        return _buildTodoTile(todo);
      },
    );
  }

  Widget _buildTodoTile(Map<String, dynamic> todo) {
    final todoId = todo['id'];
    final todoTitle = todo['title'] ?? '';
    final isChecked = _myTodoStatus[todoId] == true;

    return GestureDetector(
      onLongPress:
          canEditOrDelete ? () => _showTaskActionsBottomSheet(todo) : null,
      child: Card(
        color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        child: CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(
            todoTitle,
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
          value: isChecked,
          onChanged: (val) async {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            if (uid == null) return;

            final newValue = val ?? false;
            setState(() {
              _myTodoStatus[todoId] = newValue;
            });
            try {
              await FirebaseFirestore.instance
                  .collection(collectionName)
                  .doc(communityId)
                  .collection('members')
                  .doc(uid)
                  .collection('todosStatus')
                  .doc(todoId)
                  .set({"checked": newValue});
            } catch (e) {
              _showSnack("Could not update to-do status: $e");
            }
          },
        ),
      ),
    );
  }

  void _showTaskActionsBottomSheet(Map<String, dynamic> todo) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Edit Task"),
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditTaskDialog(todo);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text("Delete Task"),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteTodo(todo['id']);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text("Cancel"),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditTaskDialog(Map<String, dynamic> todo) {
    final todoId = todo['id'] as String;
    final titleController = TextEditingController(text: todo['title'] ?? '');

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final Color bgColor =
            isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

        return AlertDialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Edit Task",
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: TextField(
            controller: titleController,
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
            ),
            decoration: InputDecoration(
              labelText: "Task Description",
              labelStyle: GoogleFonts.workSans(
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
              filled: true,
              fillColor: isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[200]?.withOpacity(0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey[200] : Colors.grey[800],
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[600],
                foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final newTitle = titleController.text.trim();

                try {
                  await FirebaseFirestore.instance
                      .collection(collectionName)
                      .doc(communityId)
                      .collection('todos')
                      .doc(todoId)
                      .update({
                    "title": newTitle,
                  });

                  // Update local state
                  setState(() {
                    for (var t in _groupTodos) {
                      if (t['id'] == todoId) {
                        t['title'] = newTitle;
                        break;
                      }
                    }
                  });
                  _showSnack("Task updated successfully!");
                } catch (e) {
                  _showSnack("Failed to update task: $e");
                }

                Navigator.pop(dialogCtx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTodo(String todoId) async {
    if (communityId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(communityId)
          .collection('todos')
          .doc(todoId)
          .delete();

      setState(() {
        _groupTodos.removeWhere((td) => td['id'] == todoId);
      });
      _showSnack("Task removed!");
    } catch (e) {
      _showSnack("Failed to delete task: $e");
    }
  }

  // ---------------------------------------------------------------------------
  //  4G) RESOURCES LIST (scrollable)
  // ---------------------------------------------------------------------------
  Widget _buildResourcesListScroll() {
    return ListView.builder(
      itemCount: resourceList.length,
      itemBuilder: (context, index) {
        final resourceData = resourceList[index];
        final title = resourceData['title'] ?? '';
        final link = resourceData['link'] ?? '';

        return Card(
          color: isDarkMode ? Colors.grey[850] : Colors.grey[100],
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.link_outlined,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            title: (title.isNotEmpty)
                ? Text(
                    title,
                    style: GoogleFonts.workSans(
                      color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                    ),
                  )
                : null,
            subtitle: (link.isNotEmpty) ? Text(link) : null,
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          Icon(
            icon,
            color: isDarkMode ? Colors.white70 : Colors.black54,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.workSans(
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  VIEW MEMBERS
  // ---------------------------------------------------------------------------
  void _showMembersList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Group Members",
                    style: GoogleFonts.workSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: _membersList.length,
                      itemBuilder: (context, index) {
                        final member = _membersList[index];
                        final name = member['fullName'] ?? 'User $index';
                        return Card(
                          color:
                              isDarkMode ? Colors.grey[850] : Colors.grey[200],
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isDarkMode
                                  ? Colors.grey[700]
                                  : Colors.grey[500],
                              child: Icon(
                                Icons.person,
                                color:
                                    isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.workSans(
                                color: isDarkMode
                                    ? Colors.grey[200]
                                    : Colors.grey[800],
                              ),
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
  }

  // ---------------------------------------------------------------------------
  //  ADD / EDIT EVENT (via FAB)
  // ---------------------------------------------------------------------------
  void _showAddEventDialogDirect() {
    final titleController = TextEditingController();
    final locationController = TextEditingController();
    _chosenEventDate = null;
    _chosenEventTime = null;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final Color bgColor =
            isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

        return AlertDialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Add New Event",
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              String dateTimeLabel = "No date/time selected";
              if (_chosenEventDate != null) {
                final dateString =
                    "${_chosenEventDate!.month}/${_chosenEventDate!.day}/${_chosenEventDate!.year}";
                if (_chosenEventTime != null) {
                  dateTimeLabel =
                      "$dateString @ ${_chosenEventTime!.format(context)}";
                } else {
                  dateTimeLabel = dateString;
                }
              }

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      style: GoogleFonts.workSans(
                        color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                      ),
                      decoration: InputDecoration(
                        labelText: "Title",
                        labelStyle: GoogleFonts.workSans(
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[200]?.withOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final now = DateTime.now();
                        final result = await showDatePicker(
                          context: context,
                          initialDate: now,
                          firstDate: now,
                          lastDate: DateTime(now.year + 5),
                          builder: (ctx, child) {
                            return Theme(
                              data: _buildMinimalPickerTheme(isDarkMode),
                              child: child!,
                            );
                          },
                        );
                        if (result != null) {
                          setState(() {
                            _chosenEventDate = result;
                          });
                          setStateDialog(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDarkMode ? Colors.grey[800] : Colors.grey[300],
                        foregroundColor:
                            isDarkMode ? Colors.white : Colors.black87,
                      ),
                      child: Text(
                        _chosenEventDate == null
                            ? "Choose Date"
                            : "Date: ${_chosenEventDate!.month}/${_chosenEventDate!.day}/${_chosenEventDate!.year}",
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final timeResult = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (ctx, child) {
                            return Theme(
                              data: _buildMinimalPickerTheme(isDarkMode),
                              child: child!,
                            );
                          },
                        );
                        if (timeResult != null) {
                          setState(() {
                            _chosenEventTime = timeResult;
                          });
                          setStateDialog(() {});
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDarkMode ? Colors.grey[800] : Colors.grey[300],
                        foregroundColor:
                            isDarkMode ? Colors.white : Colors.black87,
                      ),
                      child: Text(
                        _chosenEventTime == null
                            ? "Choose Time"
                            : "Time: ${_chosenEventTime!.format(context)}",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: locationController,
                      style: GoogleFonts.workSans(
                        color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
                      ),
                      decoration: InputDecoration(
                        labelText: "Location",
                        labelStyle: GoogleFonts.workSans(
                          color: isDarkMode ? Colors.white70 : Colors.grey[700],
                        ),
                        filled: true,
                        fillColor: isDarkMode
                            ? Colors.grey[800]
                            : Colors.grey[200]?.withOpacity(0.6),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Current Selection:\n$dateTimeLabel",
                      style: GoogleFonts.workSans(
                        color:
                            isDarkMode ? Colors.grey[100] : Colors.grey[800],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey[200] : Colors.grey[800],
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[600],
                foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final title = titleController.text.trim();
                final location = locationController.text.trim();

                String dateTimeString = "";
                if (_chosenEventDate != null) {
                  dateTimeString =
                      "${_chosenEventDate!.month}/${_chosenEventDate!.day}/${_chosenEventDate!.year}";
                  if (_chosenEventTime != null) {
                    dateTimeString +=
                        " @ ${_chosenEventTime!.format(context)}";
                  }
                }

                final newEvent = {
                  "title": title,
                  "dateTime": dateTimeString,
                  "location": location,
                  "createdAt": FieldValue.serverTimestamp(),
                };

                if (communityId.isNotEmpty && title.isNotEmpty) {
                  final docRef = await FirebaseFirestore.instance
                      .collection(collectionName)
                      .doc(communityId)
                      .collection('events')
                      .add(newEvent);

                  newEvent['id'] = docRef.id;
                  setState(() {
                    eventList.add(newEvent);
                  });
                  _showSnack("New event added!");
                }
                Navigator.pop(dialogCtx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  //  ADD TASK (via FAB)
  // ---------------------------------------------------------------------------
  void _showAddTodoDialogDirect() {
    final todoController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final Color bgColor =
            isDarkMode ? const Color(0xFF2A2A2A) : Colors.white;

        return AlertDialog(
          backgroundColor: bgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            "Add New Task",
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: TextField(
            controller: todoController,
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
            ),
            decoration: InputDecoration(
              labelText: "Task Description",
              labelStyle: GoogleFonts.workSans(
                color: isDarkMode ? Colors.white70 : Colors.grey[700],
              ),
              filled: true,
              fillColor: isDarkMode
                  ? Colors.grey[800]
                  : Colors.grey[200]?.withOpacity(0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey[200] : Colors.grey[800],
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[600],
                foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                final newTask = {
                  "title": todoController.text.trim(),
                  "createdAt": FieldValue.serverTimestamp(),
                };

                if (communityId.isNotEmpty &&
                    newTask["title"].toString().isNotEmpty) {
                  final docRef = await FirebaseFirestore.instance
                      .collection(collectionName)
                      .doc(communityId)
                      .collection('todos')
                      .add(newTask);

                  final docId = docRef.id;
                  newTask['id'] = docId;

                  setState(() {
                    _groupTodos.add(newTask);
                  });
                  _showSnack("New task added to the group!");
                }
                Navigator.pop(dialogCtx);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  //  Minimal black/white theme for date/time pickers
  // ---------------------------------------------------------------------------
  ThemeData _buildMinimalPickerTheme(bool isDark) {
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: isDark ? Colors.white70 : Colors.black87,
        secondary: isDark ? Colors.white70 : Colors.black87,
        onSurface: isDark ? Colors.white : Colors.black87,
      ),
      dialogBackgroundColor: isDark ? const Color(0xFF303030) : Colors.white,
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  //  UTILS
  // ---------------------------------------------------------------------------
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ---------------------------------------------------------------------------
  //  REPORT FLOW
  // ---------------------------------------------------------------------------
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
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: const Text("Report This Group"),
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
                      if (val != null) {
                        setStateSB(() => selectedCategory = val);
                      }
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
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey[200] : Colors.grey[800],
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[600],
                foregroundColor: isDarkMode ? Colors.white : Colors.black87,
              ),
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
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: const Text("Confirm Report"),
          content: Text(
            'Are you sure you want to report this group for "$category"?',
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey[200] : Colors.grey[800],
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text("No"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDarkMode ? Colors.grey[800] : Colors.grey[600],
                foregroundColor: isDarkMode ? Colors.white : Colors.black87,
              ),
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
      _showSnack("You must be logged in to report.");
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'groupId': communityId,
        'reporterId': user.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'category': category,
        'collectionName': collectionName,
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          title: const Text('Report Received'),
          content: Text(
            'Thanks! We have received your report.',
            style: GoogleFonts.workSans(
              color: isDarkMode ? Colors.grey[200] : Colors.grey[800],
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor:
                    isDarkMode ? Colors.grey[200] : Colors.grey[800],
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnack("Report failed: $e");
    }
  }

  // ---------------------------------------------------------------------------
  //  UPDATED: CALENDAR POPUP & TODO POPUP with "X" close button
  // ---------------------------------------------------------------------------

  /// Show a bottom sheet listing all upcoming events in a scrollable view,
  /// partially filling screen, with an X to close.
  void _showCalendarPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return Column(
              children: [
                // Header row with label + X button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        "All Events",
                        style: GoogleFonts.workSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color:
                              isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color:
                              isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // The scrollable list of events
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: eventList.length,
                    itemBuilder: (context, index) {
                      final eventData = eventList[index];
                      return _buildEventTile(eventData);
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

  /// Show a bottom sheet listing all tasks in a scrollable view,
  /// partially filling screen, with an X to close.
  void _showTodoPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return Column(
              children: [
                // Header row with label + X button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: Row(
                    children: [
                      Text(
                        "All To-Do Items",
                        style: GoogleFonts.workSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color:
                              isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          Icons.close,
                          color:
                              isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // The scrollable list of tasks
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _groupTodos.length,
                    itemBuilder: (context, index) {
                      final todo = _groupTodos[index];
                      return _buildTodoTile(todo);
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
}
