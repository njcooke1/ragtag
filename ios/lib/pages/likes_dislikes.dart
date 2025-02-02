import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:confetti/confetti.dart';

/// Ensures @username format
class UsernameInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final txt = newValue.text;
    if (!txt.startsWith('@')) {
      return TextEditingValue(
        text: '@${txt.replaceAll('@', '')}',
        selection: TextSelection.collapsed(offset: newValue.selection.end + 1),
      );
    }
    if (txt.indexOf('@', 1) != -1) {
      return oldValue;
    }
    return newValue;
  }
}

class LikesDislikesPage extends StatefulWidget {
  const LikesDislikesPage({Key? key}) : super(key: key);

  @override
  State<LikesDislikesPage> createState() => _LikesDislikesPageState();
}

class _LikesDislikesPageState extends State<LikesDislikesPage>
    with TickerProviderStateMixin {
  /// Up to 3 "Likes"
  final List<Map<String, dynamic>> likeOptions = [
    {
      'title': 'Academic / Subject-Based',
      'icon': Icons.book_outlined,
      'description': 'Focus on academic pursuits',
      'color': Colors.orangeAccent,
    },
    {
      'title': 'Professional Development',
      'icon': Icons.work_outline,
      'description': 'Build your career & skills',
      'color': Colors.greenAccent,
    },
    {
      'title': 'Cultural',
      'icon': Icons.flag_outlined,
      'description': 'Celebrate heritage & traditions',
      'color': Colors.blueAccent,
    },
    {
      'title': 'Creative Expression',
      'icon': Icons.brush,
      'description': 'Art, music, dance, etc.',
      'color': Colors.purpleAccent,
    },
    {
      'title': 'Service / Philanthropy',
      'icon': Icons.volunteer_activism,
      'description': 'Volunteer & give back',
      'color': Colors.redAccent,
    },
    {
      'title': 'Sports / Wellness',
      'icon': Icons.sports_soccer,
      'description': 'Fitness & healthy living',
      'color': Colors.tealAccent,
    },
    {
      'title': 'Faith / Religious',
      'icon': Icons.auto_awesome,
      'description': 'Faith-based gatherings',
      'color': Colors.amberAccent,
    },
    {
      'title': 'Political / Advocacy',
      'icon': Icons.campaign_outlined,
      'description': 'Promote civic initiatives',
      'color': Colors.pinkAccent,
    },
    {
      'title': 'Leadership / Student Gov',
      'icon': Icons.account_balance,
      'description': 'Student councils, etc.',
      'color': Colors.indigoAccent,
    },
    {
      'title': 'Hobby',
      'icon': Icons.toys_outlined,
      'description': 'Fun, casual interests',
      'color': Colors.limeAccent,
    },
  ];

  // Selections
  final List<String> selectedLikes = []; // up to 3
  final List<String> dislikes = [];      // up to 3
  final TextEditingController _dislikeController = TextEditingController();

  // Dark mode
  bool isDarkMode = true;
  bool _isLoading = false;

  // For PFP
  File? _profileImage;

  // Username
  final TextEditingController _usernameController = TextEditingController();

  // Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String get userId => _auth.currentUser?.uid ?? '';

  // We'll store just the first name
  String firstName = '';

  // For confetti
  late ConfettiController _confettiController;

  // For the animated confetti emoji
  late AnimationController _emojiAnimController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _fetchProfile();

    // Confetti for 2 seconds
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 2));

    // Start animation for the emoji
    _emojiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // scale from 1.0 to 1.2
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _emojiAnimController, curve: Curves.easeInOut),
    );
    // tilt from 0.0 to -0.2
    _rotationAnimation = Tween<double>(begin: 0.0, end: -0.2).animate(
      CurvedAnimation(parent: _emojiAnimController, curve: Curves.easeInOut),
    );

    // Let’s do a short forward => reverse
    _emojiAnimController.forward().then((_) => _emojiAnimController.reverse());

    // Start confetti after a small delay
    Future.delayed(const Duration(milliseconds: 300), () {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _emojiAnimController.dispose();
    super.dispose();
  }

  /// Load user doc => parse out just the first name
  Future<void> _fetchProfile() async {
    if (userId.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final docSnap = await _firestore.collection('users').doc(userId).get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        _usernameController.text = data['username'] ?? '';

        final fullName = (data['fullName'] ?? '').trim();
        if (fullName.isNotEmpty) {
          final splitted = fullName.split(' ');
          firstName = splitted.first;
        }
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Let user pick from gallery
  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  /// Upload pfp => get URL
  Future<String?> _uploadProfileImage(File file) async {
    try {
      final fname = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('profileImages')
          .child(userId)
          .child(fname);

      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading pfp: $e');
      return null;
    }
  }

  /// Validate => must have @username != '' + at least 1 like
  Future<void> _saveAndContinue() async {
    if (userId.isEmpty) {
      _snack('No user logged in.');
      return;
    }
    final username = _usernameController.text.trim();
    if (username.isEmpty || username == '@') {
      _snack('Please enter a valid @username.');
      return;
    }
    if (selectedLikes.isEmpty) {
      _snack('Please select at least one “Like.”');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 1) Check if username is already claimed
      final userQuery = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      // If we found a doc for this username and it isn't *this* user, block them
      if (userQuery.docs.isNotEmpty && userQuery.docs.first.id != userId) {
        _snack('Sorry, that @username is already taken.');
        setState(() => _isLoading = false);
        return;
      }

      // 2) If not taken, proceed with upload
      String? imageUrl;
      if (_profileImage != null) {
        imageUrl = await _uploadProfileImage(_profileImage!);
      }

      final docData = {
        'username': username,
        'likes': selectedLikes,
        'dislikes': dislikes,
        if (imageUrl != null) 'photoUrl': imageUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('users')
          .doc(userId)
          .set(docData, SetOptions(merge: true));

      _snack('Profile saved!');

      debugPrint('Navigating to /first-choice with "fromLikesDislikes"');
      Navigator.pushNamed(
        context,
        '/first-choice',
        arguments: 'fromLikesDislikes',
      );
    } catch (e) {
      debugPrint('Error saving profile: $e');
      _snack('Error saving profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// Build the black circle pfp
  Widget _buildProfileCircle() {
    return GestureDetector(
      onTap: _pickProfileImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.black,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: ClipOval(
          child: (_profileImage != null)
              ? Image.file(_profileImage!, fit: BoxFit.cover)
              : const Icon(Icons.person, color: Colors.white70, size: 50),
        ),
      ),
    );
  }

  /// The top lines => confetti emoji anim, and "Nice To Meet You, <firstName>" in Lovelo
  Widget _buildTopLines() {
    final nameToShow = firstName.isNotEmpty ? firstName : 'Friend';
    return Column(
      children: [
        // The confetti emoji with scale+tilt animation
        AnimatedBuilder(
          animation: _emojiAnimController,
          builder: (ctx, child) {
            final scale = _scaleAnimation.value;
            final rotation = _rotationAnimation.value;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..scale(scale, scale)
                ..rotateZ(rotation),
              child: const Text(
                '🎉',
                style: TextStyle(fontSize: 48),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Nice To Meet You, $nameToShow',
          style: TextStyle(
            fontFamily: 'Lovelo',
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          "Let's get things started",
          style: TextStyle(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// The username textfield
  Widget _buildUsernameField() {
    return TextField(
      controller: _usernameController,
      maxLength: 30,
      inputFormatters: [UsernameInputFormatter()],
      style: TextStyle(
        color: isDarkMode ? Colors.white : Colors.black,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: 'Username',
        labelStyle: TextStyle(
          color: isDarkMode ? Colors.white70 : Colors.black54,
        ),
        counterText: "",
        filled: true,
        fillColor: isDarkMode
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.04),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDarkMode ? Colors.white10 : Colors.black12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: isDarkMode ? Colors.white70 : Colors.black54),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintText: '@YourUsername',
        hintStyle: TextStyle(
          color: isDarkMode ? Colors.white54 : Colors.black54,
        ),
      ),
    );
  }

  /// The horizontal "Likes" => up to 3
  Widget _buildLikesCarousel() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: likeOptions.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (ctx, i) {
          final cat = likeOptions[i];
          final title = cat['title'] as String;
          final iconData = cat['icon'] as IconData;
          final desc = cat['description'] as String;
          final accentColor = cat['color'] as Color;

          final isSelected = selectedLikes.contains(title);
          final glowColor = accentColor.withOpacity(0.4);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  selectedLikes.remove(title);
                } else {
                  if (selectedLikes.length < 3) {
                    selectedLikes.add(title);
                  } else {
                    _snack('You can select up to 3 Likes.');
                  }
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.06)
                    : Colors.black.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : (isDarkMode ? Colors.white10 : Colors.black12),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconData,
                    size: 28,
                    color: isSelected ? accentColor : Colors.white70,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? accentColor
                          : (isDarkMode ? Colors.white : Colors.black),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.2,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Dislikes => up to 3
  Widget _buildDislikesSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Anything you’d rather skip?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add up to three “dislikes.” Keep it short & sweet!',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dislikeController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Crowded events',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54,
                    ),
                    filled: true,
                    fillColor: isDarkMode
                        ? Colors.white.withOpacity(0.04)
                        : Colors.black.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.white10 : Colors.black12,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _addDislike,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Add',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (dislikes.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: dislikes.map((dk) {
                return Chip(
                  label: Text(dk),
                  backgroundColor: Colors.white,
                  labelStyle: const TextStyle(color: Colors.black87),
                  deleteIconColor: Colors.black54,
                  onDeleted: () {
                    setState(() {
                      dislikes.remove(dk);
                    });
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  void _addDislike() {
    final text = _dislikeController.text.trim();
    if (text.isEmpty) return;
    if (dislikes.length >= 3) {
      _snack('You can add up to 3 Dislikes.');
      return;
    }
    setState(() {
      dislikes.add(text);
      _dislikeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          onPressed: _saveAndContinue,
          child: const Icon(Icons.arrow_forward),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: SafeArea(
          top: true,
          child: Stack(
            children: [
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              // The confetti, aligned near top
              Positioned(
                top: 5,
                left: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: 4.7,
                    emissionFrequency: 0.06,
                    numberOfParticles: 25,
                    maxBlastForce: 10,
                    minBlastForce: 5,
                    gravity: 0.2,
                    colors: const [
                      Colors.redAccent,
                      Colors.greenAccent,
                      Colors.blueAccent,
                      Colors.orangeAccent,
                      Colors.purpleAccent,
                    ],
                  ),
                ),
              ),
              // The main scroll
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 70),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // top bar => back + dark toggle
                    Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDarkMode
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.1),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              color: isDarkMode ? Colors.white : Colors.black,
                              size: 18,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.black54 : Colors.white,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: IconButton(
                            icon: Icon(
                              isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            onPressed: () {
                              setState(() => isDarkMode = !isDarkMode);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Top lines => emoji + "Nice To Meet You, <firstName>" + subtext
                    Center(child: _buildTopLines()),
                    const SizedBox(height: 24),
                    // The black circle pfp
                    Center(child: _buildProfileCircle()),
                    const SizedBox(height: 24),
                    // Username
                    _buildUsernameField(),
                    const SizedBox(height: 16),
                    // Up to 3 Likes
                    Text(
                      'Pick Up to 3 Likes',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLikesCarousel(),
                    const SizedBox(height: 20),
                    // Dislikes => up to 3
                    _buildDislikesSection(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
