import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

class EditCommunityPage extends StatefulWidget {
  const EditCommunityPage({Key? key}) : super(key: key);

  @override
  State<EditCommunityPage> createState() => _EditCommunityPageState();
}

class _EditCommunityPageState extends State<EditCommunityPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late String docId;
  late String name;
  late String description;
  late String imageUrl; // the community's PFP
  late String type;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  // PFP changes
  File? _selectedPfpFile;

  // For Clubs only => sliding pictures
  List<String> slidingPictures = [];
  File? _selectedSlidingImage;

  // For members (from a subcollection)
  List<Map<String, dynamic>> members = [];
  // Up to 2 categories
  List<String> selectedCategories = [];

  /// Horizontal carousel data
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

  bool _isLoading = false;
  bool isDarkMode = true; // allow toggling

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    docId = args['id'];
    name = args['name'];
    description = args['description'];
    imageUrl = args['imageUrl'] ?? '';
    type = args['type'] ?? 'Unknown';

    nameController.text = name;
    descriptionController.text = description;

    _fetchCommunityDetails();
    _fetchMembersFromSubcollection();
    if (type == 'Club') _fetchSlidingPictures();
  }

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  /// Picks an image from the gallery
  Future<File?> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) return File(picked.path);
    return null;
  }

  /// Decide which Firestore collection to use
  String _getCollectionName(String t) {
    switch (t) {
      case 'Club':
        return 'clubs';
      case 'Interest Group':
        return 'interestGroups';
      case 'Open Forum':
        return 'openForums';
      case 'Ragtag Sparks':
        return 'ragtagSparks';
      default:
        return 'unknownCollection';
    }
  }

  /// Fetch details => categories, pfp
  Future<void> _fetchCommunityDetails() async {
    setState(() => _isLoading = true);
    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      final docSnap = await _firestore.collection(col).doc(docId).get();
      if (!docSnap.exists) return;

      final data = docSnap.data() as Map<String, dynamic>;

      final catList = data['categories'] as List<dynamic>? ?? [];
      selectedCategories = List<String>.from(catList);
      imageUrl = data['pfpUrl'] ?? imageUrl;
    } catch (e) {
      debugPrint('Error fetchCommunityDetails: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// For clubs => fetch sliding pictures
  Future<void> _fetchSlidingPictures() async {
    setState(() => _isLoading = true);
    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      final docSnap = await _firestore.collection(col).doc(docId).get();
      if (!docSnap.exists) return;
      final data = docSnap.data() as Map<String, dynamic>;

      slidingPictures = List<String>.from(data['slidingPictures'] ?? []);
    } catch (e) {
      debugPrint('Error fetchSlidingPictures: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Fetch members from subcollection => docRef.collection("members")
  Future<void> _fetchMembersFromSubcollection() async {
    setState(() => _isLoading = true);
    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      final querySnap = await _firestore
          .collection(col)
          .doc(docId)
          .collection('members')
          .get();

      members = querySnap.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id, // docId is user id
          'role': data['role'] ?? 'member', // or data['whatever']
        };
      }).toList();
    } catch (e) {
      debugPrint('Error fetchMembersFromSubcollection: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Save basic info => name, description, categories, pfp
  Future<void> _updateBasicInfo() async {
    setState(() => _isLoading = true);
    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      await _firestore.collection(col).doc(docId).update({
        'name': nameController.text.trim(),
        'description': descriptionController.text.trim(),
        'categories': selectedCategories,
        'pfpUrl': imageUrl,
      });

      name = nameController.text.trim();
      description = descriptionController.text.trim();

      // Also refetch members
      await _fetchMembersFromSubcollection();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All changes saved!')),
      );
    } catch (e) {
      debugPrint('Error saving basic info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving changes: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Upload pfp if _selectedPfpFile != null
  Future<void> _updatePfpImage() async {
    if (_selectedPfpFile == null) return;
    setState(() => _isLoading = true);

    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      final url = await _uploadImage(_selectedPfpFile!, 'communityPfps');
      if (url == null) return;

      imageUrl = url;
      await _firestore.collection(col).doc(docId).update({'pfpUrl': url});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Updated community profile picture.')),
      );
    } catch (e) {
      debugPrint('Error updating PFP: $e');
    } finally {
      setState(() {
        _selectedPfpFile = null;
        _isLoading = false;
      });
    }
  }

  /// Generic image upload => return URL
  Future<String?> _uploadImage(File file, String folder) async {
    try {
      final fname = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = firebase_storage.FirebaseStorage.instance
          .ref()
          .child(folder)
          .child(docId)
          .child('$fname.jpg');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error _uploadImage: $e');
      return null;
    }
  }

  /// Add sliding picture
  Future<void> _addSlidingPicture() async {
    if (_selectedSlidingImage == null) return;
    setState(() => _isLoading = true);

    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      final url = await _uploadImage(_selectedSlidingImage!, 'slidingPictures');
      if (url == null) return;

      final docRef = _firestore.collection(col).doc(docId);
      final snap = await docRef.get();
      if (!snap.exists) return;

      final data = snap.data() as Map<String, dynamic>;
      final pics = List<String>.from(data['slidingPictures'] ?? []);

      if (pics.length >= 5) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Max 5 sliding pictures allowed.')),
        );
      } else {
        pics.add(url);
        await docRef.update({'slidingPictures': pics});
        setState(() => slidingPictures = pics);
      }
    } catch (e) {
      debugPrint('Error addSlidingPicture: $e');
    } finally {
      setState(() {
        _selectedSlidingImage = null;
        _isLoading = false;
      });
    }
  }

  /// Remove a user from the subcollection
  Future<void> _removeMember(String userId) async {
    setState(() => _isLoading = true);
    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      // Just remove doc from subcollection
      final docRef = _firestore.collection(col).doc(docId);
      await docRef.collection('members').doc(userId).delete();

      // If you also store 'members' in the main doc => remove from it
      await docRef.update({
        'members.$userId': FieldValue.delete(),
        'admins': FieldValue.arrayRemove([userId]),
      });

      // Also remove from user's organizations if needed
      await _firestore.collection('users').doc(userId).update({
        'organizations.$docId': FieldValue.delete(),
      });

      await _fetchMembersFromSubcollection();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Member removed.')),
      );
    } catch (e) {
      debugPrint('Error removing member: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing member: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Block user => show warning dialog => if confirm => permanently block them
  Future<void> _blockMember(String userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Text(
            'Block User Permanently?',
            style: TextStyle(
              color: Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This is an urgent action. Once blocked, the user cannot rejoin this community without an admin override.\n\nProceed?',
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Block'),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm != true) return; // user canceled

    // Actually block them
    setState(() => _isLoading = true);
    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      // 1) Remove from subcollection
      final docRef = _firestore.collection(col).doc(docId);
      await docRef.collection('members').doc(userId).delete().catchError((_) {});

      // 2) Remove from main doc => 'members' field / 'admins'
      await docRef.update({
        'members.$userId': FieldValue.delete(),
        'admins': FieldValue.arrayRemove([userId]),
        'blockedUsers': FieldValue.arrayUnion([userId]), // store in 'blockedUsers'
      });

      // 3) Remove from user's organizations
      await _firestore.collection('users').doc(userId).update({
        'organizations.$docId': FieldValue.delete(),
      });

      await _fetchMembersFromSubcollection();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User blocked & removed.'),
          backgroundColor: Colors.red[700],
        ),
      );
    } catch (e) {
      debugPrint('Error blocking member: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error blocking member: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Delete the entire community
  Future<void> _deleteCommunity() async {
    setState(() => _isLoading = true);
    try {
      final col = _getCollectionName(type);
      if (col == 'unknownCollection') return;

      await _firestore.collection(col).doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Community deleted successfully.')),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error deleting community: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting community: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Glassy container
  BoxDecoration _buildGlassyContainer() {
    return BoxDecoration(
      color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDarkMode ? Colors.white10 : Colors.black12,
        width: 1,
      ),
    );
  }

  /// Wrap content in "glassy" card
  Widget _buildGlassyCard({required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: _buildGlassyContainer(),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  /// Horizontal category carousel (select up to 2)
  Widget _buildCategoryCarousel() {
    return SizedBox(
      height: 160,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categoryOptions.length,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemBuilder: (ctx, i) {
          final cat = categoryOptions[i];
          final title = cat['title'] as String;
          final iconData = cat['icon'] as IconData;
          final desc = cat['description'] as String;
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
                      const SnackBar(content: Text('You can select at most 2 categories.')),
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

  /// Basic Info section: PFP on top, more square, slightly rounded
  Widget _buildBasicInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _buildGlassyContainer(),
      child: Column(
        children: [
          // PFP on top
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12), // soften corners
              child: (imageUrl.isNotEmpty)
                  ? Image.network(
                      imageUrl,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return Container(
                          width: 120,
                          height: 120,
                          color: Colors.grey.shade800,
                          child: const Icon(Icons.broken_image,
                              color: Colors.white54),
                        );
                      },
                    )
                  : Container(
                      width: 120,
                      height: 120,
                      color: Colors.grey.shade900,
                      child: Icon(
                        Icons.photo_camera_back,
                        color: isDarkMode ? Colors.white54 : Colors.black54,
                        size: 40,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          // Button to change PFP
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : () async {
                    final picked = await _pickImage();
                    if (picked != null) {
                      setState(() => _selectedPfpFile = picked);
                      await _updatePfpImage();
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Change PFP'),
          ),
          const SizedBox(height: 16),

          // Name
          TextField(
            controller: nameController,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: 'Community Name',
              labelStyle: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              filled: true,
              fillColor: isDarkMode
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04),
              enabledBorder: OutlineInputBorder(
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 10),

          // Description
          TextField(
            controller: descriptionController,
            maxLines: 3,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              filled: true,
              fillColor: isDarkMode
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.04),
              enabledBorder: OutlineInputBorder(
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// If type == "Club" => sliding pictures
  Widget _buildSlidingPicsSection() {
    if (type != 'Club') return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sliding Pictures (Club only)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: slidingPictures.length + 1,
            itemBuilder: (ctx, i) {
              if (i == slidingPictures.length) {
                // add button
                return GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () async {
                          final picked = await _pickImage();
                          if (picked != null) {
                            setState(() => _selectedSlidingImage = picked);
                            await _addSlidingPicture();
                          }
                        },
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: _buildGlassyContainer(),
                    child: const Icon(
                      Icons.add_a_photo,
                      color: Colors.white70,
                      size: 26,
                    ),
                  ),
                );
              }
              final url = slidingPictures[i];
              return Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: NetworkImage(url),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.15),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              try {
                                final ref =
                                    firebase_storage.FirebaseStorage.instance
                                        .refFromURL(url);
                                await ref.delete();

                                final col = _getCollectionName(type);
                                if (col == 'unknownCollection') return;

                                final docRef = _firestore.collection(col).doc(docId);
                                final snap = await docRef.get();
                                if (!snap.exists) return;

                                final data = snap.data() as Map<String, dynamic>;
                                final pics = List<String>.from(data['slidingPictures'] ?? []);
                                pics.remove(url);
                                await docRef.update({'slidingPictures': pics});

                                setState(() => slidingPictures = pics);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Sliding picture removed.'),
                                  ),
                                );
                              } catch (e) {
                                debugPrint('Error removing pic: $e');
                              } finally {
                                setState(() => _isLoading = false);
                              }
                            },
                      child: const CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Member management (with permanent block)
  Widget _buildMemberManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Member Management',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: members.length,
          itemBuilder: (ctx, i) {
            final userId = members[i]['userId'];
            final role = members[i]['role'];

            return FutureBuilder<DocumentSnapshot>(
              future: _firestore.collection('users').doc(userId).get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildGlassyCard(
                    child: const ListTile(
                      title: Text('Loading...', style: TextStyle(color: Colors.white)),
                    ),
                  );
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return _buildGlassyCard(
                    child: const ListTile(
                      title: Text('Unknown User', style: TextStyle(color: Colors.white)),
                    ),
                  );
                }
                final data = snapshot.data!.data() as Map<String, dynamic>;
                final username = data['username'] ?? 'No Username';

                return _buildGlassyCard(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.white12,
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(username, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(role, style: const TextStyle(color: Colors.white70)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // block user => show warning
                        IconButton(
                          icon: const Icon(Icons.block, color: Colors.redAccent),
                          tooltip: "Block user permanently",
                          onPressed: () => _blockMember(userId),
                        ),
                        // remove user
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white54),
                          tooltip: "Remove user",
                          onPressed: () => _removeMember(userId),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  /// Neon-red button => delete the entire community
  Widget _buildDeleteButton() {
    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          minimumSize: const Size(double.infinity, 48),
        ),
        onPressed: _isLoading
            ? null
            : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) {
                    return AlertDialog(
                      backgroundColor: isDarkMode ? Colors.black87 : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(
                        'Delete Community?',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        'This action is irreversible. Proceed?',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      actions: [
                        TextButton(
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                          onPressed: () => Navigator.of(ctx).pop(false),
                        ),
                        TextButton(
                          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                          onPressed: () => Navigator.of(ctx).pop(true),
                        ),
                      ],
                    );
                  },
                );
                if (confirm == true) {
                  await _deleteCommunity();
                }
              },
        child: const Text(
          'DELETE COMMUNITY',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // Neon-green FAB => calls _updateBasicInfo
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.greenAccent,
          foregroundColor: Colors.black,
          onPressed: _updateBasicInfo,
          child: const Icon(Icons.check_circle_sharp),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,

        body: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // top row => back button + dark mode toggle
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
                            onPressed: () => setState(() => isDarkMode = !isDarkMode),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Basic Info
                    _buildBasicInfoSection(),
                    const SizedBox(height: 20),

                    // Horizontal Category Carousel
                    Text(
                      'Choose Up to 2 Categories',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildCategoryCarousel(),
                    const SizedBox(height: 20),

                    // If Club => sliding pictures
                    _buildSlidingPicsSection(),
                    if (type == 'Club') const SizedBox(height: 20),

                    // Member management
                    _buildMemberManagementSection(),
                    const SizedBox(height: 40),

                    // DELETE
                    _buildDeleteButton(),
                    const SizedBox(height: 60),
                  ],
                ),
              ),

              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
