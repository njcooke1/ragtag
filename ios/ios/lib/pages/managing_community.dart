// managing_community.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ManagingCommunityPage extends StatefulWidget {
  final String communityId;
  final Map<String, dynamic> communityData;
  final String userId; // <-- Added userId

  const ManagingCommunityPage({
    Key? key,
    required this.communityId,
    required this.communityData,
    required this.userId, // <-- Include userId in the constructor
  }) : super(key: key);

  @override
  State<ManagingCommunityPage> createState() => _ManagingCommunityPageState();
}

class _ManagingCommunityPageState extends State<ManagingCommunityPage> {
  int _currentImageIndex = 0;
  double _popularityFraction = 0.6; // Adjusted thickness for popularity bar
  bool _notificationsOn = true;

  final List<String> _carouselImages = [
    'https://via.placeholder.com/800x400.png?text=Photo+1',
    'https://via.placeholder.com/800x400.png?text=Photo+2',
    'https://via.placeholder.com/800x400.png?text=Photo+3',
    'https://via.placeholder.com/800x400.png?text=Photo+4',
    'https://via.placeholder.com/800x400.png?text=Photo+5',
  ];

  @override
  Widget build(BuildContext context) {
    final String communityName =
        widget.communityData['name'] ?? 'Unknown Community';
    final String handle = '@${communityName.toLowerCase().replaceAll(' ', '_')}';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            /// ======================
            /// TOP HEADER + POPULARITY
            /// ======================
            _buildTopHeader(context, communityName, handle),

            /// ======================
            /// ROUNDED CAROUSEL
            /// ======================
            _buildRoundedCarousel(),

            /// ======================
            /// CENTER ACTION BAR
            /// ======================
            _buildCenteredActionBar(),

            /// ================================
            /// TAGS & ANNOUNCEMENTS CONTAINER
            /// ================================
            Expanded(child: _buildTagsAndAnnouncements()),
          ],
        ),
      ),
    );
  }

  /// ********************
  /// TOP HEADER WIDGET
  /// ********************
  Widget _buildTopHeader(
      BuildContext context, String communityName, String handle) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          /// Community Title & Handle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  communityName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  handle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          /// Share Button
          IconButton(
            icon: const Icon(FontAwesomeIcons.paperPlane),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share button pressed')),
              );
            },
          ),

          /// Popularity Gauge
          _buildPopularityGauge(),

          /// Info Button
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showInfoDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildPopularityGauge() {
    Color gaugeColor;
    if (_popularityFraction < 0.3) {
      gaugeColor = Colors.redAccent;
    } else if (_popularityFraction < 0.6) {
      gaugeColor = Colors.orangeAccent;
    } else {
      gaugeColor = Colors.greenAccent;
    }

    return SizedBox(
      width: 60,
      height: 10,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
          FractionallySizedBox(
            widthFactor: _popularityFraction,
            child: Container(
              decoration: BoxDecoration(
                color: gaugeColor,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Community Info'),
        content: const Text('Detailed information about the community.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// ***********************
  /// ROUNDED CAROUSEL
  /// ***********************
  Widget _buildRoundedCarousel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: 250, // Bigger carousel
        child: Stack(
          children: [
            PageView.builder(
              itemCount: _carouselImages.length,
              onPageChanged: (index) {
                setState(() {
                  _currentImageIndex = index;
                });
              },
              itemBuilder: (context, index) {
                return Image.network(
                  _carouselImages[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                );
              },
            ),
            /// Indicator for carousel
            Positioned(
              left: 0,
              right: 0,
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _carouselImages.length,
                  (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 6,
                      width: index == _currentImageIndex ? 30 : 12,
                      decoration: BoxDecoration(
                        color: index == _currentImageIndex
                            ? Colors.grey[300]
                            : Colors.grey[600]!.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ********************
  /// CENTER ACTION BAR
  /// ********************
  Widget _buildCenteredActionBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 255, 0, 128),
            Color.fromARGB(255, 255, 191, 0),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(2), // Gradient border
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _centerBarItem(icon: Icons.calendar_today, label: 'CALENDAR'),
            _centerBarItem(icon: Icons.build, label: 'TOOLS'),
            _centerBarItem(icon: Icons.contacts, label: 'CONTACTS'),
          ],
        ),
      ),
    );
  }

  Widget _centerBarItem({required IconData icon, required String label}) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label tapped!')),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: Colors.white),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// ********************
  /// TAGS & ANNOUNCEMENTS
  /// ********************
  Widget _buildTagsAndAnnouncements() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color.fromARGB(255, 255, 0, 128),
            Color.fromARGB(255, 255, 191, 0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        margin: const EdgeInsets.all(3), // Border gap
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Column(
          children: [
            /// Title + Notifications Icon
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Text(
                    'Tags   Announcements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      _notificationsOn
                          ? Icons.notifications
                          : Icons.notifications_off,
                      color: _notificationsOn ? Colors.orange : Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _notificationsOn = !_notificationsOn;
                      });
                    },
                  ),
                ],
              ),
            ),

            /// Announcements Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _buildAnnouncementCard(),
                  _buildAnnouncementCard(),
                  // Add more as needed
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Single Announcement Card
  Widget _buildAnnouncementCard() {
    final String meetingTitle = 'Meeting at Talley (3pm)';
    final String announcementDescription =
        'Join us at Talley to learn more about the Rag 4 Tag cause!';
    final String meetingDate = '11/21/2024';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meetingTitle,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                'https://via.placeholder.com/600x300.png?text=Talley+Student+Union',
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              announcementDescription,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[300],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              meetingDate,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
