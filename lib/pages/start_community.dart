import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

// Import your pages if needed
import 'package:ragtagrevived/pages/clubs_profile_page.dart';
import 'package:ragtagrevived/pages/interest_groups_profile_page.dart';
import 'package:ragtagrevived/pages/open_forums_profile_page.dart';

class StartCommunityPage extends StatefulWidget {
  const StartCommunityPage({Key? key}) : super(key: key);

  @override
  State<StartCommunityPage> createState() => _StartCommunityPageState();
}

class _StartCommunityPageState extends State<StartCommunityPage> {
  // Common fields
  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // Community Type Data
  final List<Map<String, dynamic>> communityTypes = [
    {
      'title': 'Club',
      'collectionName': 'clubs',
      'icon': Icons.group,
      'description': 'A close-knit circle with shared events.',
      'color': Colors.orangeAccent,
    },
    {
      'title': 'Interest Group',
      'collectionName': 'interestGroups',
      'icon': Icons.lightbulb,
      'description': 'Unite over a common passion.',
      'color': Colors.greenAccent,
    },
    {
      'title': 'Open Forum',
      'collectionName': 'openForums',
      'icon': Icons.forum,
      'description': 'Discuss freely, share openly.',
      'color': Colors.blueAccent,
    },
  ];
  int? selectedTypeIndex;

  // Category Selection (up to 2)
  final List<Map<String, dynamic>> categoryOptions = [
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
      'description': 'Civic initiatives',
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
  List<String> selectedCategories = [];

  // Profile Image
  File? _profileImageFile;
  String? _profileImageUrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebase();
    _initializeFCM();
  }

  Future<void> _initializeFirebase() async {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  }

  Future<void> _initializeFCM() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      String? token = await _getFcmToken();
      debugPrint('FCM Token: $token');
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        debugPrint('FCM Token refreshed: $newToken');
      });
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(message.notification!.title ?? 'New Notification'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      });
    } else {
      debugPrint('User declined or has not accepted permission');
    }
  }

  Future<String?> _getFcmToken() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      return await messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  Future<void> _pickProfileImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile =
        await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfileImage(File imageFile, String orgId) async {
    try {
      final String timeStamp =
          DateTime.now().millisecondsSinceEpoch.toString();
      final firebase_storage.Reference ref = firebase_storage
          .FirebaseStorage.instance
          .ref()
          .child('communityProfileImages')
          .child(orgId)
          .child('$timeStamp.jpg');
      await ref.putFile(imageFile);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }

  // ---------- Categories Grid (5 columns) ----------
  Widget _buildCategoryGrid() {
    return GridView.builder(
      itemCount: categoryOptions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (ctx, i) {
        final cat = categoryOptions[i];
        final title = cat['title'] as String;
        final iconData = cat['icon'] as IconData;
        final accentColor = cat['color'] as Color;

        final isSelected = selectedCategories.contains(title);
        final glowColor = accentColor.withOpacity(0.4);

        return GestureDetector(
          onTap: () {
            setState(() {
              if (isSelected) {
                selectedCategories.remove(title);
              } else {
                if (selectedCategories.length < 2) {
                  selectedCategories.add(title);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('You can select at most 2 categories.'),
                    ),
                  );
                }
              }
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? accentColor : Colors.white24,
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconData,
                    size: 26,
                    color: isSelected ? accentColor : Colors.white70,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? accentColor : Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- Check if the form is complete ----------
  bool get isFormComplete {
    return selectedTypeIndex != null &&
        nameController.text.trim().isNotEmpty &&
        selectedCategories.isNotEmpty &&
        _profileImageFile != null;
  }

  // ---------- Create Community ----------
  void start_community() async {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();

    // Must select a type
    if (selectedTypeIndex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a community type!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Must have a name
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a community name.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Must have at least 1 category
    if (selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose at least 1 category.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Must have a profile image
    if (_profileImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please pick a profile image first.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final selectedType = communityTypes[selectedTypeIndex!];
    final collectionName = selectedType['collectionName'] as String;
    final typeTitle = selectedType['title'] as String;

    setState(() => _isLoading = true);

    try {
      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User not authenticated.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      final userId = currentUser.uid;

      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(userId);
      final userDoc = await userDocRef.get();
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User profile not found in Firestore.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      final userData = userDoc.data()!;
      final userInstitution = userData['institution'] ?? '';

      final docRef =
          FirebaseFirestore.instance.collection(collectionName).doc();
      final orgId = docRef.id;

      // Upload the chosen profile image
      final pfpUrl = await _uploadProfileImage(_profileImageFile!, orgId);
      if (pfpUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error uploading profile image.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }
      setState(() => _profileImageUrl = pfpUrl);

      // Build the document data
      final Map<String, dynamic> communityData = {
        'name': name,
        'description': description,
        'type': typeTitle,
        'creatorId': userId,
        'members': { userId: 'admin' },
        'admins': [userId],
        'createdAt': FieldValue.serverTimestamp(),
        'institution': userInstitution,
        'categories': selectedCategories,
        'pfpUrl': pfpUrl,
      };

      // Save to Firestore
      await docRef.set(communityData);

      // Save admin document with FCM token
      String? fcmToken = await _getFcmToken();
      await docRef.collection('admins').doc(userId).set({
        'joinedAt': FieldValue.serverTimestamp(),
        'fcmToken': fcmToken ?? '',
      });

      // Update user document with organizations
      if (userDoc.exists) {
        await userDocRef.update({
          'organizations.$orgId': 'admin',
        });
      } else {
        await userDocRef.set({
          'username': currentUser.displayName ?? 'Unnamed User',
          'email': currentUser.email ?? 'No Email',
          'institution': userInstitution,
          'organizations': { orgId: 'admin' },
        });
      }

      // Navigate based on the community type
      if (typeTitle == 'Club') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClubsProfilePage(
              communityId: orgId,
              communityData: communityData,
              userId: userId,
            ),
          ),
        );
      } else if (typeTitle == 'Interest Group') {
        Navigator.pushNamed(
          context,
          '/interest-groups-profile',
          arguments: {
            'communityId': orgId,
            'communityData': communityData,
            'userId': userId,
          },
        );
      } else if (typeTitle == 'Open Forum') {
        Navigator.pushNamed(
          context,
          '/open-forums-profile',
          arguments: {
            'communityId': orgId,
            'communityData': communityData,
            'userId': userId,
          },
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Community "$name" created successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating community: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF171717),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFF0A0A0A);
    const textColor = Colors.white;
    final cardBorderColor = Colors.white24;

    final selectedType =
        selectedTypeIndex != null ? communityTypes[selectedTypeIndex!] : null;
    final dynamicHeader = selectedType != null
        ? '${selectedType['title']} Details'
        : 'Community Details';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 90,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: TextButton.icon(
            onPressed: _isLoading ? null : () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.transparent,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.cyanAccent,
              size: 18,
            ),
            label: const Text(" ",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ),
        title: const Text(
          'Create Community',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Pick a profile image
                GestureDetector(
                  onTap: _pickProfileImage,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: _profileImageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _profileImageFile!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 36,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 30),

                // ---------- Community Types in a horizontal carousel ----------
                Text(
                  'Choose a Community Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: communityTypes.length,
                    separatorBuilder: (ctx, i) => const SizedBox(width: 16),
                    itemBuilder: (ctx, index) {
                      final type = communityTypes[index];
                      final isSelected = (selectedTypeIndex == index);
                      final accentColor = type['color'] as Color;
                      final selectedGlowColor = accentColor.withOpacity(0.5);

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedTypeIndex = index;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          width: 160,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color:
                                  isSelected ? accentColor : cardBorderColor,
                              width: 1.5,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: selectedGlowColor,
                                      blurRadius: 15,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 0),
                                    )
                                  ]
                                : [],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                type['icon'],
                                size: 40,
                                color: isSelected ? accentColor : textColor,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                type['title'],
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? accentColor : textColor,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                type['description'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.3,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),

                // ---------- Community Details ----------
                Text(
                  dynamicHeader,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: nameController,
                  label: 'Name',
                  hint: 'e.g. "CyberHaven"',
                ),
                const SizedBox(height: 15),
                _buildTextField(
                  controller: descriptionController,
                  label: 'Description',
                  hint: 'A brief tagline or purpose...',
                  maxLines: 3,
                ),
                const SizedBox(height: 30),

                // ---------- Categories (5-column grid) ----------
                Text(
                  'Choose Up to 2 Categories',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                _buildCategoryGrid(),
                const SizedBox(height: 60),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : start_community,
        icon: const Icon(
          Icons.arrow_forward,
          color: Color(0xFF0A0A0A),
        ),
        label: Text(
          isFormComplete ? 'Finish' : 'Next',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.cyanAccent,
      ),
    );
  }
}
