import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LikesDislikesPage extends StatefulWidget {
  const LikesDislikesPage({Key? key}) : super(key: key);

  @override
  State<LikesDislikesPage> createState() => _LikesDislikesPageState();
}

class _LikesDislikesPageState extends State<LikesDislikesPage> {
  /// Dark mode toggle
  bool isDarkMode = true;
  bool _isLoading = false;

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  /// Carousel “like” options (max 3)
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

  /// User’s current selections
  final List<String> _likes = [];
  final List<String> _dislikes = [];

  /// For adding a new "dislike" free-text
  final TextEditingController _dislikeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchLikesAndDislikes();
  }

  /// Load any existing data from Firestore
  Future<void> _fetchLikesAndDislikes() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid);
      final snap = await docRef.get();
      if (snap.exists) {
        final data = snap.data() ?? {};
        final likedList = List<String>.from(data['likes'] ?? []);
        final dislikeList = List<String>.from(data['dislikes'] ?? []);
        _likes.addAll(likedList);
        _dislikes.addAll(dislikeList);
      }
    } catch (e) {
      debugPrint("Error loading likes/dislikes: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Save to Firestore
  Future<void> _saveAll() async {
    if (_currentUser == null) return;
    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid);

      await docRef.update({
        'likes': _likes,
        'dislikes': _dislikes,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Saved your likes & dislikes!")),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error saving likes/dislikes: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// A row with an arrow on the left + a dark-mode toggle on the right
  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 8),
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDarkMode
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDarkMode ? Colors.white : Colors.black,
              size: 18,
            ),
            onPressed: () => Navigator.pop(context),
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
            onPressed: () => setState(() => isDarkMode = !isDarkMode),
          ),
        ),
      ],
    );
  }

  /// Horizontal carousel for _likes
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

          final isSelected = _likes.contains(title);
          final glowColor = accentColor.withOpacity(0.4);

          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _likes.remove(title);
                } else {
                  if (_likes.length < 3) {
                    _likes.add(title);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Max 3 Likes allowed!")),
                    );
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
                  Icon(iconData,
                      size: 28,
                      color: isSelected ? accentColor : Colors.white70),
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

  /// A text field + chips for free-form "dislikes"
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
            'Dislikes (max 3)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dislikeController,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                  decoration: InputDecoration(
                    hintText: "e.g. Crowded events",
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
                  onSubmitted: (_) => _addDislike(),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _addDislike,
                child: const Text("Add"),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_dislikes.isEmpty)
            Text(
              "No dislikes yet...",
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _dislikes.map((dk) {
                return Chip(
                  label: Text(dk),
                  backgroundColor: Colors.white,
                  labelStyle: const TextStyle(color: Colors.black87),
                  deleteIconColor: Colors.black54,
                  onDeleted: () {
                    setState(() => _dislikes.remove(dk));
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  /// Add a new "dislike" if under 3
  void _addDislike() {
    final text = _dislikeController.text.trim();
    if (text.isEmpty) return;
    if (_dislikes.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Max 3 Dislikes allowed!")),
      );
      return;
    }
    setState(() {
      _dislikes.add(text);
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

        body: SafeArea(
          child: Stack(
            children: [
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // top bar => arrow + dark toggle
                    _buildTopBar(context),
                    const SizedBox(height: 16),

                    // Title
                    Center(
                      child: Text(
                        "Likes & Dislikes",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        "Tap categories to pick up to 3 likes.\nAdd free-text dislikes below.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Liked categories
                    Text(
                      "Your Likes (max 3)",
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildLikesCarousel(),
                    const SizedBox(height: 20),

                    // Dislikes
                    _buildDislikesSection(),
                  ],
                ),
              ),

              // bottom "save" button
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent, // button color
                      foregroundColor: Colors.white,        // text color
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _saveAll,
                    icon: const Icon(Icons.check, color: Colors.white), // white check
                    label: const Text(
                      "SAVE",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
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
}
