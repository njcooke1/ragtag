import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// These pages depend on data structures from Firestore; they also
// rely on Flutter’s Material widgets, so we import them.
class AdminPanelPage extends StatelessWidget {
  final String clubId;
  final String clubName;

  const AdminPanelPage({Key? key, required this.clubId, required this.clubName})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$clubName Admin Panel'),
      ),
      body: Center(
        child: Text('Admin Panel for $clubName (ID: $clubId)'),
      ),
    );
  }
}

class MemberSettingsPage extends StatelessWidget {
  final String clubId;
  final String clubName;

  const MemberSettingsPage({
    Key? key,
    required this.clubId,
    required this.clubName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$clubName Member Settings'),
      ),
      body: Center(
        child: Text('Member Settings for $clubName (ID: $clubId)'),
      ),
    );
  }
}

class StoryViewPage extends StatefulWidget {
  final List<String> stories;
  const StoryViewPage({Key? key, required this.stories}) : super(key: key);

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    if (index == widget.stories.length - 1) {
      // Auto-close after last story
      Future.delayed(const Duration(seconds: 2), () {
        Navigator.pop(context, true);
      });
    }
  }

  bool _isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = _isDarkMode(context);

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        title: Text(
          'Stories',
          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.close,
                color: isDarkMode ? Colors.white : Colors.black, size: 30),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.stories.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, i) {
              final imgUrl = widget.stories[i];
              return CachedNetworkImage(
                imageUrl: imgUrl,
                fit: BoxFit.contain,
                placeholder: (_, __) =>
                    const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.error, color: Colors.red)),
              );
            },
          ),
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.stories.length,
              backgroundColor: isDarkMode ? Colors.white24 : Colors.black12,
              valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode ? Colors.white : Colors.blue),
            ),
          ),
        ],
      ),
    );
  }
}
