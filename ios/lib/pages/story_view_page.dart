// lib/pages/story_view_page.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A custom story viewer page that displays a list of image URLs as stories.
class StoryViewPage extends StatefulWidget {
  /// List of image URLs to display as stories.
  final List<String> stories;

  /// Optional: Callback when all stories have been viewed.
  final VoidCallback? onComplete;

  const StoryViewPage({
    Key? key,
    required this.stories,
    this.onComplete,
  }) : super(key: key);

  @override
  State<StoryViewPage> createState() => _StoryViewPageState();
}

class _StoryViewPageState extends State<StoryViewPage> {
  late PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;
  bool _isPaused = false;

  static const Duration storyDuration = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(storyDuration, (timer) {
      if (_isPaused) return;
      if (_currentPage < widget.stories.length - 1) {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      } else {
        timer.cancel();
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
        Navigator.of(context).pop();
      }
    });
  }

  void _onTapDown(TapDownDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < screenWidth / 2) {
      // Tapped on the left half - go to previous story
      if (_currentPage > 0) {
        _currentPage--;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Tapped on the right half - go to next story
      if (_currentPage < widget.stories.length - 1) {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
    _startTimer(); // Restart the timer on user interaction
  }

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() {
      _isPaused = false;
    });
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildProgressIndicators() {
    return Positioned(
      top: 40,
      left: 10,
      right: 10,
      child: Row(
        children: widget.stories.asMap().entries.map((entry) {
          int idx = entry.key;
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 3,
              decoration: BoxDecoration(
                color: idx < _currentPage
                    ? Colors.white
                    : idx == _currentPage
                        ? Colors.white
                        : Colors.white54,
                borderRadius: BorderRadius.circular(1.5),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: _onTapDown,
        onLongPressStart: _onLongPressStart,
        onLongPressEnd: _onLongPressEnd,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.stories.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
                _startTimer();
              },
              itemBuilder: (context, index) {
                final imageUrl = widget.stories[index];
                return CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade900,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child:
                          Icon(Icons.broken_image, color: Colors.white54),
                    ),
                  ),
                );
              },
            ),
            _buildProgressIndicators(),
            // Close button
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
