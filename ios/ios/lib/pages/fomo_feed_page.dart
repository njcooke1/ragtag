import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';

// If you actually need File references, import 'dart:io'; 
// but removing here if not used.

// -------------- 1) Ticket path + clippers + painter --------------
Path buildTicketPath({
  required Size size,
  required double cornerRadius,
  required double notchRadius,
}) {
  final path = Path();

  // top-left corner
  path.moveTo(0, cornerRadius);
  path.quadraticBezierTo(0, 0, cornerRadius, 0);

  // top edge
  path.lineTo(size.width - cornerRadius, 0);
  // top-right corner
  path.quadraticBezierTo(size.width, 0, size.width, cornerRadius);

  // right notch
  path.lineTo(size.width, (size.height / 2) - notchRadius);
  path.arcToPoint(
    Offset(size.width, (size.height / 2) + notchRadius),
    clockwise: false,
    radius: Radius.circular(notchRadius),
  );

  // bottom-right corner
  path.lineTo(size.width, size.height - cornerRadius);
  path.quadraticBezierTo(
    size.width,
    size.height,
    size.width - cornerRadius,
    size.height,
  );

  // bottom edge
  path.lineTo(cornerRadius, size.height);
  // bottom-left corner
  path.quadraticBezierTo(0, size.height, 0, size.height - cornerRadius);

  // left notch
  path.lineTo(0, (size.height / 2) + notchRadius);
  path.arcToPoint(
    Offset(0, (size.height / 2) - notchRadius),
    clockwise: false,
    radius: Radius.circular(notchRadius),
  );

  // up to top-left
  path.lineTo(0, cornerRadius);
  path.close();
  return path;
}

class TicketClipper extends CustomClipper<Path> {
  final double cornerRadius;
  final double notchRadius;

  TicketClipper({
    this.cornerRadius = 20,
    this.notchRadius = 10,
  });

  @override
  Path getClip(Size size) {
    return buildTicketPath(
      size: size,
      cornerRadius: cornerRadius,
      notchRadius: notchRadius,
    );
  }

  @override
  bool shouldReclip(TicketClipper oldClipper) =>
      oldClipper.cornerRadius != cornerRadius ||
      oldClipper.notchRadius != notchRadius;
}

class TicketOutlinePainter extends CustomPainter {
  final double cornerRadius;
  final double notchRadius;
  final Color outlineColor;
  final double outlineWidth;

  TicketOutlinePainter({
    required this.cornerRadius,
    required this.notchRadius,
    required this.outlineColor,
    required this.outlineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = buildTicketPath(
      size: size,
      cornerRadius: cornerRadius,
      notchRadius: notchRadius,
    );
    final paintOutline = Paint()
      ..color = outlineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = outlineWidth;

    canvas.drawPath(path, paintOutline);
  }

  @override
  bool shouldRepaint(TicketOutlinePainter oldDelegate) {
    return oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.notchRadius != notchRadius ||
        oldDelegate.outlineColor != outlineColor ||
        oldDelegate.outlineWidth != outlineWidth;
  }
}

// -------------- 2) ModernTicketCard --------------
class ModernTicketCard extends StatelessWidget {
  final bool isDarkMode;
  final String hostName;
  final String title;
  final String dateTimeString;
  final String location;
  final String flyerUrl;
  final String description; // not shown in bottom half
  final bool isNew;
  final VoidCallback onTapViewFlyer;

  // RSVP props
  final String? rsvpSelection;   // "yes", "maybe", "no", or null
  final bool showRsvpOptions;    // if true => row of yes/idk/no
  final VoidCallback onToggleRsvpOptions;
  final ValueChanged<String> onSelectRsvp;

  const ModernTicketCard({
    Key? key,
    required this.isDarkMode,
    required this.hostName,
    required this.title,
    required this.dateTimeString,
    required this.location,
    required this.flyerUrl,
    required this.description,
    required this.isNew,
    required this.onTapViewFlyer,
    required this.rsvpSelection,
    required this.showRsvpOptions,
    required this.onToggleRsvpOptions,
    required this.onSelectRsvp,
  }) : super(key: key);

  static const double ticketHeight = 250;
  static const double cornerRadius = 20;
  static const double notchRadius = 10;
  static const double outlineWidth = 2.2;

  Widget _buildRsvpInner() {
    // If user hasn't chosen anything
    if (rsvpSelection == null) {
      if (!showRsvpOptions) {
        // single "RSVP" orange button
        return ElevatedButton(
          key: const ValueKey('rsvpButton'),
          onPressed: onToggleRsvpOptions,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF9800),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          child: const Text(
            "RSVP",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        );
      } else {
        // row => yes / IDK / no
        return Row(
          key: const ValueKey('rsvpRow'),
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              iconSize: 26,
              icon: const Icon(Icons.check, color: Color(0xFF39FF14)),
              onPressed: () => onSelectRsvp('yes'),
            ),
            GestureDetector(
              onTap: () => onSelectRsvp('maybe'),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Text("IDK", style: TextStyle(color: Colors.white)),
              ),
            ),
            IconButton(
              iconSize: 26,
              icon: const Icon(Icons.clear, color: Color(0xFFFF073A)),
              onPressed: () => onSelectRsvp('no'),
            ),
          ],
        );
      }
    }

    // If user has chosen something
    Widget chosenIcon;
    Color bgColor;
    switch (rsvpSelection) {
      case 'yes':
        chosenIcon = const Icon(Icons.check, color: Colors.white, size: 24);
        bgColor = const Color(0xFF39FF14); // neon green
        break;
      case 'maybe':
        chosenIcon = const Text(
          "IDK",
          style: TextStyle(color: Colors.white, fontSize: 15),
        );
        bgColor = Colors.grey;
        break;
      case 'no':
        chosenIcon = const Icon(Icons.clear, color: Colors.white, size: 24);
        bgColor = const Color(0xFFFF073A);
        break;
      default:
        chosenIcon = const Icon(Icons.help, color: Colors.white, size: 24);
        bgColor = Colors.grey;
    }

    return GestureDetector(
      key: const ValueKey('rsvpChosen'),
      onTap: onToggleRsvpOptions,         // re-open
      onLongPress: () => onSelectRsvp('null'), // revert
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: chosenIcon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outlineColor = isDarkMode ? Colors.white : Colors.black;

    return SizedBox(
      width: double.infinity,
      height: ticketHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Outline
          CustomPaint(
            size: const Size(double.infinity, ticketHeight),
            painter: TicketOutlinePainter(
              cornerRadius: cornerRadius,
              notchRadius: notchRadius,
              outlineColor: outlineColor,
              outlineWidth: outlineWidth,
            ),
          ),

          // Clipped container
          ClipPath(
            clipper: TicketClipper(
              cornerRadius: cornerRadius,
              notchRadius: notchRadius,
            ),
            child: Container(
              color: isDarkMode ? Colors.grey[900] : Colors.white,
              child: Column(
                children: [
                  // top half => partial flyer
                  Expanded(
                    child: Stack(
                      children: [
                        flyerUrl.isEmpty
                            ? Container(
                                color: isDarkMode
                                    ? Colors.grey[700]
                                    : Colors.grey[300],
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: Colors.white54,
                                ),
                              )
                            : Image.network(
                                flyerUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.grey,
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                        // "View Flyer" button (still present)
                        Positioned(
                          bottom: 10,
                          right: 10,
                          child: ElevatedButton(
                            onPressed: onTapViewFlyer,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            child: const Text(
                              "View Flyer",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // bottom half => forced dark color
                  Expanded(
                    child: Stack(
                      children: [
                        Container(color: Colors.grey[900]),
                        Container(color: Colors.black.withOpacity(0.35)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          child: Stack(
                            children: [
                              // host name center top
                              Positioned(
                                top: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Text(
                                    hostName.isEmpty
                                        ? "Unknown Club"
                                        : hostName,
                                    style: const TextStyle(
                                      fontFamily: 'Lovelo',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // bottom-left => event title, date/time, location
                              Positioned(
                                bottom: 0,
                                left: 0,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title.isEmpty
                                          ? "Untitled Event"
                                          : title,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    if (dateTimeString.isNotEmpty)
                                      Text(
                                        "When: $dateTimeString",
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white70,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    if (location.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 3.0),
                                        child: Text(
                                          "Where: $location",
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // RSVP => bottom-right
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return SizeTransition(
                                      sizeFactor: animation,
                                      axis: Axis.horizontal,
                                      child: FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _buildRsvpInner(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // NEW banner outside the clip
          if (isNew)
            Positioned(
              top: -4,
              left: -10,
              child: Transform.rotate(
                angle: -0.15,
                child: SizedBox(
                  width: 87,
                  child: Image.asset(
                    'assets/newbanner.png',
                    fit: BoxFit.fill,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// -------------- 3) PressableModernTicket --------------
class PressableModernTicket extends StatefulWidget {
  final Map<String, dynamic> eventData;
  final bool isDarkMode;
  final String? currentUserId;

  const PressableModernTicket({
    Key? key,
    required this.eventData,
    required this.isDarkMode,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<PressableModernTicket> createState() => _PressableModernTicketState();
}

class _PressableModernTicketState extends State<PressableModernTicket> {
  bool _isPressed = false;
  String? _rsvpSelection; // "yes", "maybe", "no", or null
  bool _showRsvpOptions = false;

  @override
  void initState() {
    super.initState();
    _fetchRsvpFromFirestore();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.eventData;
    final title = e['title'] ?? 'Untitled Event';

    final shadowColor = Colors.black54;
    final double blur = widget.isDarkMode ? 12 : 8;
    final offset = widget.isDarkMode ? const Offset(0, 5) : const Offset(0, 3);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        // => also opens the flyer dialog, just like the button
        final flyerUrl = e['flyerUrl'] ?? '';
        final desc = e['description'] ?? '';
        if (flyerUrl.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No flyer available.")),
          );
          return;
        }
        _showFlyerDialog(context, flyerUrl, desc);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: _isPressed
            ? const EdgeInsets.only(top: 4, bottom: 4)
            : const EdgeInsets.only(top: 8, bottom: 8),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: _isPressed ? (blur - 4) : blur,
              offset: _isPressed ? Offset(offset.dx, offset.dy - 1) : offset,
            ),
          ],
        ),
        child: ModernTicketCard(
          isDarkMode: widget.isDarkMode,
          hostName: e['hostName'] ?? 'Unknown Club',
          title: title,
          dateTimeString: e['dateTime'] ?? '',
          location: e['location'] ?? '',
          flyerUrl: e['flyerUrl'] ?? '',
          description: e['description'] ?? '',
          isNew: e['isNew'] == true || e['isNew'] == 'true',
          rsvpSelection: _rsvpSelection,
          showRsvpOptions: _showRsvpOptions,
          onToggleRsvpOptions: _toggleRsvpOptions,
          onSelectRsvp: _selectRsvp,
          // The button in ModernTicketCard also calls the same function:
          onTapViewFlyer: () {
            final flyerUrl = e['flyerUrl'] ?? '';
            final desc = e['description'] ?? '';
            if (flyerUrl.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("No flyer available.")),
              );
              return;
            }
            _showFlyerDialog(context, flyerUrl, desc);
          },
        ),
      ),
    );
  }

  void _toggleRsvpOptions() {
    setState(() => _showRsvpOptions = !_showRsvpOptions);
  }

  Future<void> _selectRsvp(String choice) async {
    if (choice == 'null') {
      // revert
      setState(() {
        _rsvpSelection = null;
        _showRsvpOptions = false;
      });
      _saveRsvpToFirestore(null);
    } else {
      setState(() {
        _rsvpSelection = choice;
        _showRsvpOptions = false;
      });
      _saveRsvpToFirestore(choice);
    }
  }

  /// read existing RSVP
  Future<void> _fetchRsvpFromFirestore() async {
    if (widget.currentUserId == null) return;
    final clubId = widget.eventData['clubId'];
    final eventId = widget.eventData['id'];
    if (clubId == null || eventId == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events')
          .doc(eventId)
          .collection('rsvps')
          .doc(widget.currentUserId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final rsvp = data?['rsvp'] as String?;
        if (rsvp != null && rsvp.isNotEmpty) {
          setState(() => _rsvpSelection = rsvp);
        }
      }
    } catch (e) {
      debugPrint("Error fetching RSVP: $e");
    }
  }

  /// write RSVP + store user's fullName
  Future<void> _saveRsvpToFirestore(String? choice) async {
    if (widget.currentUserId == null) return;
    final clubId = widget.eventData['clubId'];
    final eventId = widget.eventData['id'];
    if (clubId == null || eventId == null) return;

    final docRef = FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .collection('events')
        .doc(eventId)
        .collection('rsvps')
        .doc(widget.currentUserId);

    try {
      if (choice == null) {
        // if user reverts, remove their doc
        await docRef.delete().catchError((_) {});
      } else {
        // fetch user doc => retrieve fullName or fallback to username
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.currentUserId)
            .get();
        final userData = userDoc.data() ?? {};
        final fullName = userData['fullName'] ??
            userData['username'] ??
            'Unknown';

        // store rsvp + fullName in subcollection
        await docRef.set({
          'rsvp': choice,
          'fullName': fullName,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error saving RSVP: $e");
    }
  }

  /// Show flyer => plus description
  void _showFlyerDialog(BuildContext context, String flyerUrl, String desc) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black.withOpacity(0.8),
          insetPadding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Flyer image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        flyerUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    // "More prominent" description
                    if (desc.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          desc,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                      ),
                  ],
                ),
                // Close button
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
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
}

// -------------- 4) RagtagFooter --------------
class RagtagFooter extends StatelessWidget {
  final bool isDarkMode;
  final String? currentUserId;
  final String? userProfilePicUrl;

  const RagtagFooter({
    Key? key,
    required this.isDarkMode,
    required this.currentUserId,
    required this.userProfilePicUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
          color: isDarkMode ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Admin icon
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/admin-dashboard'),
                child: Icon(
                  Icons.admin_panel_settings,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 40,
                ),
              ),
            ),
            // Explore -> FOMO Feed replaced with FOMO Feed logo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/fomo_feed'),
                child: Image.asset(
                  isDarkMode
                      ? 'assets/fomofeedlogo.png'
                      : 'assets/fomofeedlogoblack.png',
                  height: 34,
                ),
              ),
            ),
            // Center logo (ragtag)
            GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, '/find_community');
              },
              child: Image.asset(
                isDarkMode
                    ? 'assets/ragtaglogo.png'
                    : 'assets/ragtaglogoblack.png',
                height: 40,
              ),
            ),
            // plus icon -> start community
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/start-community',
                    arguments: currentUserId,
                  );
                },
                child: Icon(
                  Icons.add,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 30,
                ),
              ),
            ),
            // user PFP with shimmer ring => now leads to profile page
            _buildShimmeringUserPfp(context),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmeringUserPfp(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Navigate to profile page
        Navigator.pushNamed(context, '/profilePage');
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
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black,
              backgroundImage: (userProfilePicUrl != null &&
                      userProfilePicUrl!.isNotEmpty)
                  ? NetworkImage(userProfilePicUrl!)
                  : null,
              child: (userProfilePicUrl == null || userProfilePicUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------- 5) FomoFeedPage --------------
class FomoFeedPage extends StatefulWidget {
  const FomoFeedPage({Key? key}) : super(key: key);

  @override
  State<FomoFeedPage> createState() => _FomoFeedPageState();
}

class _FomoFeedPageState extends State<FomoFeedPage> {
  // We default to true now, so the page “naturally” loads in dark mode.
  bool _isDarkMode = true;

  bool _isLoadingInstitution = true;
  String _searchQuery = "";

  String? userInstitution;
  List<Map<String, dynamic>> _allEvents = [];
  String? currentUserId;
  String? userProfilePicUrl;
  String? username;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // fetch user => set institution, pfp, etc.
  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingInstitution = false);
      return;
    }
    currentUserId = user.uid;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        userInstitution = data['institution'] ?? '';
        userProfilePicUrl = data['photoUrl'] ?? '';
        username = data['username'] ?? '@Anonymous';
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
    } finally {
      setState(() => _isLoadingInstitution = false);
      _fetchAllClubEvents();
    }
  }

  Future<void> _fetchAllClubEvents() async {
    if (userInstitution == null || userInstitution!.isEmpty) {
      return;
    }
    try {
      final clubsSnap = await FirebaseFirestore.instance
          .collection('clubs')
          .where('institution', isEqualTo: userInstitution!)
          .get();

      final tempEvents = <Map<String, dynamic>>[];
      for (final cDoc in clubsSnap.docs) {
        final eventsSnap = await cDoc.reference
            .collection('events')
            .orderBy('createdAt', descending: true)
            .get();
        for (final eDoc in eventsSnap.docs) {
          final eData = eDoc.data();
          eData['id'] = eDoc.id;
          eData['clubId'] = cDoc.id;

          // add clubName => hostName
          final clubData = cDoc.data();
          final clubName = clubData['name'] ?? 'Unknown Club';
          eData['hostName'] = clubName;

          eData['title']       = eData['title']       ?? '';
          eData['dateTime']    = eData['dateTime']    ?? '';
          eData['location']    = eData['location']    ?? '';
          eData['flyerUrl']    = eData['flyerUrl']    ?? '';
          eData['description'] = eData['description'] ?? '';
          eData['isNew']       = eData['isNew']       ?? false;

          // -- 30-hour logic here --
          final createdAt = eData['createdAt'];
          if (createdAt is Timestamp) {
            final createdDate = createdAt.toDate();
            final diffInHours =
                DateTime.now().difference(createdDate).inHours;

            if (diffInHours >= 30) {
              eData['isNew'] = false;

              // OPTIONAL: Update Firestore so next fetch won't show "NEW"
              /*
              try {
                await cDoc.reference
                    .collection('events')
                    .doc(eDoc.id)
                    .update({'isNew': false});
              } catch (error) {
                debugPrint("Failed to update isNew: $error");
              }
              */
            }
          }
          tempEvents.add(eData);
        }
      }
      // sort by creationTime desc
      tempEvents.sort((a, b) {
        final aTime = (a['createdAt'] is Timestamp)
            ? (a['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        final bTime = (b['createdAt'] is Timestamp)
            ? (b['createdAt'] as Timestamp).millisecondsSinceEpoch
            : 0;
        return bTime.compareTo(aTime);
      });

      setState(() => _allEvents = tempEvents);
    } catch (e) {
      debugPrint("Error fetching events: $e");
    }
  }

  // search filter
  List<Map<String, dynamic>> get _filteredEvents {
    if (_searchQuery.trim().isEmpty) return _allEvents;
    final q = _searchQuery.trim().toLowerCase();
    return _allEvents.where((ev) {
      final host = (ev['hostName'] ?? '').toLowerCase();
      final title = (ev['title'] ?? '').toLowerCase();
      final loc = (ev['location'] ?? '').toLowerCase();
      return host.contains(q) || title.contains(q) || loc.contains(q);
    }).toList();
  }

  Widget _buildUsernameMenu() {
    final displayName = username ?? "@Loading...";
    final color = _isDarkMode ? Colors.white : Colors.black;
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: _isDarkMode ? Colors.grey[850] : Colors.white,
      onSelected: (value) async {
        if (value == 'signOut') {
          await FirebaseAuth.instance.signOut();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/openingLandingPage');
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isDarkMode ? Colors.black54 : Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // truncated username
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100),
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_drop_down, color: color),
          ],
        ),
      ),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          value: 'signOut',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: const [
              Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20),
              SizedBox(width: 6),
              Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode ? Colors.black54 : Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: IconButton(
        icon: Icon(
          _isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
          color: _isDarkMode ? Colors.white : Colors.black87,
        ),
        onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = _isDarkMode ? ThemeData.dark() : ThemeData.light();
    final textColor = _isDarkMode ? Colors.white : Colors.black;

    return AnimatedTheme(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      data: baseTheme,
      child: Scaffold(
        backgroundColor: _isDarkMode ? Colors.black : Colors.white,
        bottomNavigationBar: RagtagFooter(
          isDarkMode: _isDarkMode,
          currentUserId: currentUserId,
          userProfilePicUrl: userProfilePicUrl,
        ),
        body: SafeArea(
          child: _isLoadingInstitution
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const SizedBox(height: 10),
                    // row => username sign-out + theme toggle
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // sign-out / username
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: _buildUsernameMenu(),
                        ),
                        const SizedBox(width: 10),
                        // theme toggle
                        Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _buildThemeToggle(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // center => flatlogo
                    Center(
                      child: Image.asset(
                        _isDarkMode
                            ? 'assets/flatlogo.png'
                            : 'assets/flatlogoblack.png',
                        height: 38,
                      ),
                    ),
                    // fomo feed
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Image.asset(
                          _isDarkMode
                              ? 'assets/fomofeedwhite.png'
                              : 'assets/fomofeed.png',
                          height: 40,
                        ),
                      ),
                    ),
                    // search bar
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: TextField(
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Never miss out again...",
                          hintStyle: TextStyle(
                            color: _isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                          filled: true,
                          fillColor:
                              _isDarkMode ? Colors.grey[900] : Colors.grey[200],
                          prefixIcon: Icon(
                            Icons.search,
                            color: _isDarkMode ? Colors.white54 : Colors.black54,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _isDarkMode
                                  ? Colors.white12
                                  : Colors.grey.shade300,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: _isDarkMode
                                  ? Colors.white54
                                  : Colors.grey.shade600,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      ),
                    ),

                    // feed
                    Expanded(
                      child: _allEvents.isEmpty
                          ? Center(
                              child: Text(
                                "Displaying Available Events..",
                                style: TextStyle(color: textColor),
                              ),
                            )
                          : ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              itemCount: _filteredEvents.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 20),
                              itemBuilder: (ctx, i) {
                                final e = _filteredEvents[i];
                                return PressableModernTicket(
                                  eventData: e,
                                  isDarkMode: _isDarkMode,
                                  currentUserId: currentUserId,
                                );
                              },
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
