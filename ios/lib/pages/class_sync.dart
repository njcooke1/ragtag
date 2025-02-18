import 'dart:math'; // For random color picking
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For FilteringTextInputFormatter
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:confetti/confetti.dart'; // For confetti

class ClassSyncPage extends StatefulWidget {
  const ClassSyncPage({Key? key}) : super(key: key);

  @override
  State<ClassSyncPage> createState() => _ClassSyncPageState();
}

class _ClassSyncPageState extends State<ClassSyncPage>
    with SingleTickerProviderStateMixin {
  // Controllers for text fields
  final TextEditingController _classCodeController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();
  final TextEditingController _profFirstNameController =
      TextEditingController();
  final TextEditingController _profLastNameController = TextEditingController();

  // List of “pending” class groups the user is adding
  final List<Map<String, dynamic>> _pendingGroups = [];

  // Day-selection set, e.g. {'M','W','F'}
  final Set<String> _selectedDays = {};

  // For basic UI animations
  late final AnimationController _titleAnimationController;
  late final Animation<double> _titleAnimation;

  // Show a loading indicator while we check/create each group
  bool _isWorking = false;

  // For the max classes limit
  static const int _maxClasses = 6;

  // Confetti + success check controller
  late final ConfettiController _confettiController;

  /// “Nice” (smooth-ish) random color list for new groups — expanded to cover a wide
  /// range of attractive colors (mid-saturation) so white text stays readable.
  final List<Color> _niceColors = const [
    Color(0xFFE53935), // Red 600
    Color(0xFFD81B60), // Pink 600
    Color(0xFF8E24AA), // Purple 600
    Color(0xFF5E35B1), // Deep Purple 600
    Color(0xFF3949AB), // Indigo 600
    Color(0xFF1E88E5), // Blue 600
    Color(0xFF039BE5), // Light Blue 600
    Color(0xFF00ACC1), // Cyan 600
    Color(0xFF00897B), // Teal 600
    Color(0xFF43A047), // Green 600
    Color(0xFF7CB342), // Light Green 600
    Color(0xFFC0CA33), // Lime 600
    Color(0xFFFFB300), // Amber 600
    Color(0xFFFB8C00), // Orange 600
    Color(0xFFF4511E), // Deep Orange 600
    Color(0xFF6D4C41), // Brown 600
    Color(0xFF546E7A), // Blue Grey 600
  ];

  @override
  void initState() {
    super.initState();

    // Title fade/scale animation
    _titleAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleAnimation = CurvedAnimation(
      parent: _titleAnimationController,
      curve: Curves.easeInOut,
    );
    _titleAnimationController.forward();

    // Confetti controller (shorter duration)
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 1));

    // Show the "how it works" dialog right after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showHowItWorksDialog();
    });
  }

  @override
  void dispose() {
    _titleAnimationController.dispose();
    _classCodeController.dispose();
    _sectionController.dispose();
    _profFirstNameController.dispose();
    _profLastNameController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  /// Displays a modern & playful dialog describing how Class Sync works.
  void _showHowItWorksDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF007D93),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white, width: 2),
          ),
          title: Row(
            children: const [
              Icon(Icons.school, color: Colors.white, size: 26),
              SizedBox(width: 8),
              Text('Class Sync', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Text(
            'Add up to 6 classes.\n\n'
            'We’ll check if your class group exists.\n'
            'If it does, you’re in! If not, we’ll create it!\n\n'
            'Note: Each class group expires in ~5 months.',
            style: TextStyle(color: Colors.white, height: 1.35),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Got it!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Called when user taps "Add Class."
  /// Checks/creates a "class group" (in 'classGroups'), then stores it in _pendingGroups.
  Future<void> _addClass() async {
    // Stop if we already have 6 classes
    if (_pendingGroups.length >= _maxClasses) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot add more than 6 classes!')),
      );
      return;
    }

    // Gather text inputs
    final classCode = _classCodeController.text.trim();
    final section = _sectionController.text.trim();
    final profFirstName = _profFirstNameController.text.trim();
    final profLastName = _profLastNameController.text.trim();

    // Validate text fields
    if (classCode.isEmpty ||
        section.isEmpty ||
        profFirstName.isEmpty ||
        profLastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields (no spaces allowed).'),
        ),
      );
      return;
    }

    // Validate “no spaces”
    final noSpacesRegex = RegExp(r'^\S+$');
    if (!noSpacesRegex.hasMatch(classCode) ||
        !noSpacesRegex.hasMatch(section) ||
        !noSpacesRegex.hasMatch(profFirstName) ||
        !noSpacesRegex.hasMatch(profLastName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No spaces allowed in any field!')),
      );
      return;
    }

    // Validate day selection
    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one day (M, T, W, Th, F).'),
        ),
      );
      return;
    }
    final daysString = _selectedDays.join(''); // e.g. "MWF"

    setState(() => _isWorking = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user is logged in!')),
        );
        setState(() => _isWorking = false);
        return;
      }
      final userId = user.uid;

      // Grab user's institution for the group doc
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No user document found!')),
        );
        setState(() => _isWorking = false);
        return;
      }

      final userData = userDoc.data()!;
      final userInstitution = userData['institution'] ?? '';

      // 1) Check if group already exists in "classGroups" (including days)
      final existingGroupQuery = await FirebaseFirestore.instance
          .collection('classGroups')
          .where('name', isEqualTo: classCode)
          .where('section', isEqualTo: section)
          .where('profFirstName', isEqualTo: profFirstName)
          .where('profLastName', isEqualTo: profLastName)
          .where('days', isEqualTo: daysString) // new day check
          .where('institution', isEqualTo: userInstitution)
          .limit(1)
          .get();

      String? finalDocId;
      Map<String, dynamic>? finalDocData;

      if (existingGroupQuery.docs.isNotEmpty) {
        // Group found, ensure user is a member
        final docRef = existingGroupQuery.docs.first.reference;
        final docId = docRef.id;
        final docData = existingGroupQuery.docs.first.data();

        final membersMap = Map<String, dynamic>.from(
          docData['members'] as Map<String, dynamic>? ?? {},
        );
        if (!membersMap.containsKey(userId)) {
          membersMap[userId] = 'member';
          await docRef.update({'members': membersMap});

          // Also add to user’s doc under "classGroups"
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .set(
            {
              'classGroups': {docId: 'member'}
            },
            SetOptions(merge: true),
          );
        }

        finalDocId = docId;
        finalDocData = docData;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Joined existing class group: $classCode - $section ($daysString)'),
          ),
        );
      } else {
        // 2) Otherwise, create a new "class group" doc
        final docRef =
            FirebaseFirestore.instance.collection('classGroups').doc();
        final docId = docRef.id;

        // 5 months from now -> ~150 days
        final DateTime expiresDate =
            DateTime.now().add(const Duration(days: 150));

        // Generate a random “nice color” for the group
        final randomColor =
            _niceColors[Random().nextInt(_niceColors.length)];
        // Convert to ARGB string, e.g. "0xFF64B5F6"
        final colorHex =
            '0xFF${(randomColor.value & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

        // We store the day info in the doc, plus a new "displayName" for convenience
        final groupData = {
          'name': classCode, // The short name (e.g. "ST303")
          'section': section,
          'profFirstName': profFirstName,
          'profLastName': profLastName,
          'days': daysString, // new field for "MTW" etc.
          'displayName': '$classCode - $profLastName - $daysString',
          'pfpType': 'textAvatar',
          'pfpText': classCode,
          'backgroundColor': colorHex,
          'admins': [userId],
          'members': {userId: 'admin'},
          'institution': userInstitution,
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(expiresDate),
        };

        await docRef.set(groupData);

        // Also track the new group in user’s doc
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .set({
          'classGroups': {docId: 'admin'}
        }, SetOptions(merge: true));

        finalDocId = docId;
        finalDocData = groupData;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Created new class group: $classCode - $section ($daysString)'),
          ),
        );
      }

      // If we found or created the group, add it to our local pending list
      if (finalDocId != null && finalDocData != null) {
        setState(() {
          _pendingGroups.add({
            'groupId': finalDocId,
            'classCode': classCode,
            'section': section,
            'profFirstName': profFirstName,
            'profLastName': profLastName,
            'days': daysString,
            'communityData': finalDocData,
          });
        });
      }

      // Reset inputs and day selection
      _classCodeController.clear();
      _sectionController.clear();
      _profFirstNameController.clear();
      _profLastNameController.clear();
      _selectedDays.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isWorking = false);
    }
  }

  /// When "Done" is pressed, show confetti + check, then allow user to go to "Find Community."
  void _handleDone() {
    if (_pendingGroups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have not added any classes yet!')),
      );
      return;
    }
    _showSuccessAnimation();
  }

  /// Shows a dark overlay with confetti, a big check, “Success!” text, and an “All Finished!” button.
  Future<void> _showSuccessAnimation() async {
    // Start confetti
    _confettiController.play();

    // Show a fullscreen overlay
    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54, // Dark semi-transparent
      builder: (BuildContext context) {
        return Material(
          color: Colors.transparent, // so we see the dark overlay
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Confetti
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                emissionFrequency: 0.15,
                numberOfParticles: 30,
                gravity: 0.4,
                colors: [
                  Colors.white,
                  Colors.blue,
                  Colors.pink,
                  Colors.green,
                  Colors.orange,
                ],
              ),
              // Center content
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_circle,
                    size: 140,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Success!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close overlay
                      Navigator.pushNamed(context, '/find_community');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007D93),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    ),
                    child: const Text(
                      'All Finished!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    // Small delay in case user closes instantly
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF007D93),
        elevation: 2,
        centerTitle: true,
        title: FadeTransition(
          opacity: _titleAnimation,
          child: ScaleTransition(
            scale: _titleAnimation,
            child: const Text(
              'Class Sync',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Lovelo', // ensure the font is added to your project
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Add up to 6 Classes',
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0x22007D93), // Slight teal overlay
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: _buildClassInputSection(),
                    ),
                    const SizedBox(height: 24),
                    if (_pendingGroups.isNotEmpty) _buildPendingClasses(),
                  ],
                ),
              ),
            ),
          ),
          // Loading overlay
          if (_isWorking)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: ElevatedButton(
          onPressed: _handleDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF007D93),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the text fields + day selection row + "Add Class" button
  Widget _buildClassInputSection() {
    final noSpacesFilter = [
      FilteringTextInputFormatter.deny(RegExp(r'\s')), // no whitespace
    ];

    return Column(
      children: [
        // Class Code
        TextField(
          controller: _classCodeController,
          inputFormatters: noSpacesFilter,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.class_, color: Color(0xFF007D93)),
            labelText: 'Class Abbreviation *',
            labelStyle: const TextStyle(color: Colors.black54),
            hintText: 'e.g. CS101',
            hintStyle: const TextStyle(color: Colors.black38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black45),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF007D93)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Section
        TextField(
          controller: _sectionController,
          inputFormatters: noSpacesFilter,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.code, color: Color(0xFF007D93)),
            labelText: 'Section *',
            labelStyle: const TextStyle(color: Colors.black54),
            hintText: 'e.g. A, B, 01, etc.',
            hintStyle: const TextStyle(color: Colors.black38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black45),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF007D93)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Professor’s First Name
        TextField(
          controller: _profFirstNameController,
          inputFormatters: noSpacesFilter,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person, color: Color(0xFF007D93)),
            labelText: 'Professor’s First Name *',
            labelStyle: const TextStyle(color: Colors.black54),
            hintText: 'e.g. Anthony',
            hintStyle: const TextStyle(color: Colors.black38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black45),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF007D93)),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Professor’s Last Name
        TextField(
          controller: _profLastNameController,
          inputFormatters: noSpacesFilter,
          style: const TextStyle(color: Colors.black),
          decoration: InputDecoration(
            prefixIcon:
                const Icon(Icons.person_outline, color: Color(0xFF007D93)),
            labelText: 'Professor’s Last Name *',
            labelStyle: const TextStyle(color: Colors.black54),
            hintText: 'e.g. Solari',
            hintStyle: const TextStyle(color: Colors.black38),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.black45),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF007D93)),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Day Selection Bubbles
        _buildDaySelector(),
        const SizedBox(height: 20),

        // "Add Class" Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isWorking ? null : _addClass,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007D93),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text(
              'Add Class',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Simple row of clickable "bubble" chips for M, T, W, Th, F with better visibility.
  Widget _buildDaySelector() {
    final dayOptions = ['M', 'T', 'W', 'Th', 'F'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: dayOptions.map((day) {
        final isSelected = _selectedDays.contains(day);
        return ChoiceChip(
          label: Text(
            day,
            style: TextStyle(
              fontSize: 16.0,
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedDays.add(day);
              } else {
                _selectedDays.remove(day);
              }
            });
          },
          selectedColor: const Color(0xFF007D93),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: isSelected
                ? BorderSide.none
                : const BorderSide(color: Color(0xFF007D93), width: 2),
          ),
        );
      }).toList(),
    );
  }

  /// Shows a list of classes the user has added (max 6).
  Widget _buildPendingClasses() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0x22007D93),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pending Classes',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          ..._pendingGroups.map((grp) {
            final code = grp['classCode'];
            final section = grp['section'];
            final profF = grp['profFirstName'];
            final profL = grp['profLastName'];

            return Column(
              children: [
                const Divider(color: Colors.black26),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                  leading:
                      const Icon(Icons.menu_book, color: Color(0xFF007D93)),
                  title: Text(
                    'Professor $profF $profL',
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '$code ($section)',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
