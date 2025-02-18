// find_community_helpers.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart'; // For CombineLatestStream

class FindCommunityPage extends StatefulWidget {
  const FindCommunityPage({Key? key}) : super(key: key);

  @override
  State<FindCommunityPage> createState() => _FindCommunityPageState();
}

class _FindCommunityPageState extends State<FindCommunityPage> {
  bool isDarkMode = false;

  // We'll fetch the userInstitution from Firestore
  String? userInstitution;
  bool isLoadingInstitution = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserInstitution();
  }

  /// Dynamically fetch from Firestore
  void _fetchUserInstitution() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        isLoadingInstitution = false;
        errorMessage = 'No logged-in user found.';
      });
      return;
    }

    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (docSnapshot.exists) {
        final data = docSnapshot.data();
        setState(() {
          userInstitution = data?['institution'] ?? '';
          isLoadingInstitution = false;
        });
      } else {
        setState(() {
          isLoadingInstitution = false;
          errorMessage = 'User profile not found in Firestore.';
        });
      }
    } catch (e) {
      setState(() {
        isLoadingInstitution = false;
        errorMessage = 'Error fetching user institution: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;

    if (isLoadingInstitution) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        body: Center(
          child: Text(errorMessage!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    // If userInstitution is found, we can load communities
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLogo(topPadding),
                const SizedBox(height: 20),

                // "New" section, merges clubs, interestGroups, openForums
                buildNewSection(context, userInstitution!),

                const SizedBox(height: 20),

                // "Discover by Mood & Culture" or any other sections
                buildDiscoverByMoodAndCulture(isDarkMode),

                const SizedBox(height: 20),
              ],
            ),
          ),
          Positioned(
            top: topPadding + 20,
            right: 10,
            child: _buildDarkModeAndSettingsRow(),
          ),
        ],
      ),
      bottomNavigationBar: buildFooter(context),
    );
  }

  Widget _buildLogo(double topPadding) {
    return Padding(
      padding: EdgeInsets.only(top: topPadding + 40, left: 20),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Image.asset(
          isDarkMode ? 'assets/flatlogo.png' : 'assets/flatlogoblack.png',
          height: 55,
          width: 160,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Center(
              child: Text('Image not found', style: TextStyle(color: Colors.red)),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDarkModeAndSettingsRow() {
    return Row(
      children: [
        IconButton(
          icon: Icon(isDarkMode ? Icons.wb_sunny : Icons.nights_stay),
          onPressed: () => setState(() => isDarkMode = !isDarkMode),
        ),
      ],
    );
  }

  Widget buildFooter(BuildContext context) {
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
          color: Colors.black,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Far left icon => Admin Dashboard
            GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/admin-dashboard');
              },
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 40),

            // Middle icons
            _buildFooterIcon(
              icon: Icons.explore,
              onTap: () => Navigator.pushNamed(context, '/explore'),
            ),
            GestureDetector(
              onTap: () {
                Navigator.pushReplacementNamed(context, '/openingLandingPage');
              },
              child: Image.asset(
                'assets/ragtaglogo.png',
                height: 40,
              ),
            ),
            _buildFooterIcon(
              icon: Icons.add,
              onTap: () => Navigator.pushNamed(context, '/start-community'),
            ),
            const SizedBox(width: 40),

            // Right icon => go to profile page
            _buildFooterIcon(
              icon: Icons.person,
              onTap: () {
                Navigator.pushNamed(context, '/profilePage');
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Updated footer icon builder to accept onTap callback
  Widget _buildFooterIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(
          icon,
          color: Colors.white,
          size: 40,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // "New" Section: merges clubs, interestGroups, openForums
  // ---------------------------------------------------------------------------
  Widget buildNewSection(BuildContext context, String institution) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.new_releases, color: Colors.blueAccent, size: 28),
              const SizedBox(width: 8),
              const Text(
                "New",
                style: TextStyle(
                  fontSize: 22,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Combined stream from 3 collections (example: only clubs here for brevity)
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: fetchNewCommunitiesStream(institution),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  "Error loading new communities",
                  style: TextStyle(color: Colors.red),
                ),
              );
            }

            final newCommunities = snapshot.data ?? [];
            if (newCommunities.isEmpty) {
              return const Center(
                child: Text(
                  "No new communities found",
                  style: TextStyle(
                    color: Colors.black,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }

            return buildNewCommunitiesCarousel(
              PageController(viewportFraction: 0.8),
              newCommunities,
            );
          },
        ),
      ],
    );
  }

  /// Merges clubs, interestGroups, and openForums, randomizes, and returns 6
  Stream<List<Map<String, dynamic>>> fetchNewCommunitiesStream(String institution) {
    final clubsStream = _fetchCollection('clubs', institution);
    // If you want to add interestGroups and openForums, create streams similarly & add to CombineLatestStream.

    // Combine them with rxdart's CombineLatestStream
    return CombineLatestStream.list<List<Map<String, dynamic>>>([
      clubsStream,
      // interestGroupsStream,
      // openForumsStream,
    ]).map((lists) {
      // Flatten
      final combined = <Map<String, dynamic>>[];
      for (final list in lists) {
        combined.addAll(list);
      }
      // Shuffle & take 6
      combined.shuffle();
      return combined.take(6).toList();
    });
  }

  /// Helper for streaming one collection filtered by `institution`
  Stream<List<Map<String, dynamic>>> _fetchCollection(String collectionName, String institution) {
    return FirebaseFirestore.instance
        .collection(collectionName)
        .where('institution', isEqualTo: institution)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();
        });
  }

  /// A PageView carousel for new communities
  Widget buildNewCommunitiesCarousel(
    PageController pageController,
    List<Map<String, dynamic>> communities,
  ) {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        controller: pageController,
        itemCount: communities.length,
        itemBuilder: (context, index) {
          final comm = communities[index];
          return Container(
            margin: const EdgeInsets.only(left: 4, right: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              image: DecorationImage(
                image: comm['image'] != null
                    ? NetworkImage(comm['image'])
                    : const AssetImage('assets/placeholder.png') as ImageProvider,
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Colors.black87, Colors.transparent],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  left: 20,
                  child: Text(
                    comm['name'] ?? 'Unnamed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // "Discover by Mood and Culture" section
  // ---------------------------------------------------------------------------
  Widget buildDiscoverByMoodAndCulture(bool isDarkMode) {
    final sections = [
      {
        "emoji": "🎨",
        "title": "Feeling Creative?",
        "description": "Find art clubs, design groups, and creativity hubs.",
        "colors": [Colors.purpleAccent, Colors.deepPurpleAccent]
      },
      {
        "emoji": "🤝",
        "title": "Want to Network?",
        "description": "Connect with business, finance, and startup communities.",
        "colors": [Colors.greenAccent, Colors.teal]
      },
      {
        "emoji": "🏆",
        "title": "Ready to Compete?",
        "description": "Discover sports clubs, e-sports leagues, and competitions.",
        "colors": [Colors.redAccent, Colors.orangeAccent]
      },
      {
        "emoji": "🌍",
        "title": "Discover Culture",
        "description": "Join language exchanges, cultural societies, and more.",
        "colors": [Colors.blueAccent, Colors.cyan]
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Discover by Mood",
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Explore clubs and events that match your current vibe.",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 230,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: sections.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              itemBuilder: (context, index) {
                final section = sections[index];
                final gradientColors = section['colors'] as List<Color>;
                return Container(
                  width: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors.last.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      // Navigate or filter results by this mood/culture
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 16,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section['emoji'] as String,
                            style: const TextStyle(fontSize: 40),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            section['title'] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              section['description'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
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
  }
}
