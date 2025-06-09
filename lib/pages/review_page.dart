import 'dart:math' as math;
import 'package:async/async.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Deep grey used for dark-mode bottom sheets & dialogs.
const _darkSheet = Color(0xFF1C1C1E);

class ReviewPage extends StatefulWidget {
  const ReviewPage({Key? key}) : super(key: key);

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage>
    with SingleTickerProviderStateMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  bool isDarkMode = true;
  String _searchText = '';
  String? _pfpUrl, _institution;

  final TextEditingController _searchCtrl = TextEditingController();
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _initUser();
    _pulseCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
  }

  Future<void> _initUser() async {
    if (_user == null) return;
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(_user!.uid).get();
    if (!snap.exists) return;
    final data = snap.data()!;
    setState(() {
      _pfpUrl = data['photoUrl'] ?? '';
      _institution = data['institution'] ?? '';
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─────────────────── streams & helpers ───────────────────
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _statusStream(
      String status) {
    if (_institution == null) return const Stream.empty();

    final cols = ['clubs', 'interestGroups', 'openForums'];

    final live = cols.map((c) => FirebaseFirestore.instance
        .collection(c)
        .where('institution', isEqualTo: _institution)
        .where('approvalStatus', isEqualTo: status)
        .snapshots());

    final archive = FirebaseFirestore.instance
        .collection('communityReview')
        .where('institution', isEqualTo: _institution)
        .where('approvalStatus', isEqualTo: status)
        .snapshots();

    return StreamZip([...live, archive])
        .map((ls) => ls.expand((d) => d.docs).toList())
        .map((raw) {
      final m = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (var d in raw) m[d.id] = d;
      return m.values.toList();
    });
  }

  Future<void> _archiveDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ref =
        FirebaseFirestore.instance.collection('communityReview').doc(doc.id);
    if ((await ref.get()).exists) return;
    await ref.set({
      ...doc.data(),
      'archivedAt': FieldValue.serverTimestamp(),
    });
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        color: isDarkMode ? Colors.black : Colors.white,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
          floatingActionButton: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black54 : Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: IconButton(
                icon: Icon(isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                    color: isDarkMode ? Colors.white : Colors.black),
                onPressed: () => setState(() => isDarkMode = !isDarkMode),
              ),
            ),
          ),
          body: SafeArea(
            child: Stack(
              children: [
                Column(
                  children: [
                    _topBar(context),
                    const SizedBox(height: 10),
                    _header(),
                    const SizedBox(height: 4),
                    _subHeader(),
                    const SizedBox(height: 8),
                    _addAdminButton(),                // centered pill
                    const SizedBox(height: 16),
                    _searchBar(),
                    const SizedBox(height: 8),
                    TabBar(
                      indicatorColor:
                          isDarkMode ? Colors.white : Colors.black,
                      labelColor: isDarkMode ? Colors.white : Colors.black,
                      unselectedLabelColor:
                          isDarkMode ? Colors.white54 : Colors.black54,
                      tabs: const [
                        Tab(text: 'Pending'),
                        Tab(text: 'Approved'),
                        Tab(text: 'Denied'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: () async => setState(() {}),
                        child: TabBarView(
                          children: [
                            _buildList('pending'),
                            _buildList('approved'),
                            _buildList('declined'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Positioned(bottom: 12, right: 12, child: _educatorBadge())
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────── top bar ─────────────────────
  Widget _topBar(BuildContext ctx) => Row(children: [
        const SizedBox(width: 8),
        _circleBtn(Icons.arrow_back_ios_new,
            onTap: () => Navigator.pop(ctx)),
        const Spacer(),
        const SizedBox(width: 8),
      ]);

  // ───────── centered “Add Administrators” button ─────────
  Widget _addAdminButton() => Center(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: isDarkMode ? Colors.white : Colors.black,
            backgroundColor: isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
            side: BorderSide(
                color: isDarkMode ? Colors.white54 : Colors.black54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          ),
          onPressed: _showAddAdministrator,
          child: const Text('Add Administrators',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  // ───────────── educator badge ─────────────
  Widget _educatorBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withOpacity(0.06) : Colors.black12,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _shimmerPfp(),
          const SizedBox(width: 6),
          Text('Educator',
              style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  // ─────────── Add-Administrator flow (with autofill) ───────────
  Future<String?> _askEmail() async {
    final ctrl = TextEditingController();

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        final radius = BorderRadius.circular(24);

        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          maxChildSize: 0.75,
          minChildSize: 0.35,
          builder: (_, scrollCtrl) {
            return StatefulBuilder(
              builder: (ctx, setInner) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? _darkSheet : Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: radius.topLeft),
                  ),
                  child: ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Add Administrator',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 22,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ctrl,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                            color:
                                isDarkMode ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDarkMode
                              ? Colors.white.withOpacity(0.05)
                              : Colors.black.withOpacity(0.05),
                          hintText: 'user@email.com',
                          hintStyle: TextStyle(
                              color: isDarkMode
                                  ? Colors.white54
                                  : Colors.black54),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (_) => setInner(() {}),
                      ),
                      const SizedBox(height: 12),

                      // suggestions list
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: (_institution == null || ctrl.text.isEmpty)
                            ? const Stream.empty()
                            : FirebaseFirestore.instance
                                .collection('users')
                                .where('institution',
                                    isEqualTo: _institution)
                                .limit(30)
                                .snapshots(),
                        builder: (ctx2, snap) {
                          if (!snap.hasData) return const SizedBox();
                          final txt = ctrl.text.toLowerCase();
                          final matches = snap.data!.docs
                              .where((d) => (d.data()['email'] ?? '')
                                  .toString()
                                  .toLowerCase()
                                  .contains(txt))
                              .take(5)
                              .toList();
                          if (matches.isEmpty) return const SizedBox();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text('Suggestions',
                                  style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54)),
                              const SizedBox(height: 4),
                              ...matches.map((d) => ListTile(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 0),
                                    title: Text(d.data()['email'],
                                        style: TextStyle(
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black)),
                                    onTap: () {
                                      ctrl.text = d.data()['email'];
                                      setInner(() {}); // refresh
                                    },
                                  )),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: isDarkMode
                                      ? Colors.white
                                      : Colors.black),
                              onPressed: () => Navigator.pop(c),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.greenAccent,
                                foregroundColor: Colors.black,
                              ),
                              onPressed: () {
                                final email = ctrl.text.trim();
                                if (email.isNotEmpty) {
                                  Navigator.pop(c, email);
                                }
                              },
                              child: const Text('Next'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showAddAdministrator() async {
    final email = await _askEmail();
    if (email == null) return;

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (userSnap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No user found with that email'),
            duration: Duration(seconds: 2)));
      }
      return;
    }

    final userDoc = userSnap.docs.first;
    final data = userDoc.data();

    if (!mounted) return;
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) {
        return Container(
          decoration: BoxDecoration(
              color: isDarkMode ? _darkSheet : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16))),
          padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(c).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 36,
              backgroundImage: (data['photoUrl'] ?? '').toString().isNotEmpty
                  ? NetworkImage(data['photoUrl'])
                  : null,
              child: (data['photoUrl'] ?? '').toString().isEmpty
                  ? const Icon(Icons.person, size: 36)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(data['fullName'] ?? 'Unknown',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: isDarkMode ? Colors.white : Colors.black)),
            const SizedBox(height: 4),
            Text(data['email'] ?? '',
                style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                  child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: isDarkMode
                              ? Colors.white
                              : Colors.black),
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Back'))),
              const SizedBox(width: 16),
              Expanded(
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Add'))),
            ])
          ]),
        );
      },
    );
    if (confirm != true) return;

    await userDoc.reference
        .set({'privileges': 'educator'}, SetOptions(merge: true));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('User promoted to educator'),
          duration: Duration(seconds: 2)));
    }
  }

  // ───────────── header / search ─────────────
  Widget _header() => Text('Review Submissions',
      style: TextStyle(
          fontFamily: 'Lovelo',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? Colors.white : Colors.black));

  Widget _subHeader() => Text('Approve or decline new communities',
      style: TextStyle(
          fontSize: 14,
          color: isDarkMode ? Colors.white : Colors.black));

  Widget _searchBar() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            const SizedBox(width: 12),
            Icon(Icons.search,
                color: isDarkMode ? Colors.white54 : Colors.black54),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchText = v),
                style: TextStyle(
                    color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Search…',
                    hintStyle: TextStyle(
                        color: isDarkMode ? Colors.white54 : Colors.black54)),
              ),
            ),
            const SizedBox(width: 12),
          ]),
        ),
      );

  // ───────────── build list per status ─────────────
  Widget _buildList(String status) => StreamBuilder<
          List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _statusStream(status),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
              child: CircularProgressIndicator(
                  color: isDarkMode ? Colors.white : Colors.black));
        }
        if (snap.hasError) {
          return Center(
              child: Text('Error: ${snap.error}',
                  style: const TextStyle(color: Colors.redAccent)));
        }
        final docs = (snap.data ?? [])
            .where((d) {
              final data = d.data();
              final q = _searchText.toLowerCase();
              return (data['name'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(q) ||
                  (data['description'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(q);
            })
            .toList();

        for (final d in docs) _archiveDoc(d);

        if (docs.isEmpty) {
          return Center(
              child: Text('No $status submissions',
                  style: TextStyle(
                      color: isDarkMode ? Colors.white54 : Colors.black54)));
        }

        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, i) {
            final data = docs[i].data();
            return _CommunityCard(
              dark: isDarkMode,
              status: status,
              doc: docs[i],
              data: data,
              currentUserId: _user?.uid,
            );
          },
        );
      });

  // ───────────── misc widgets ─────────────
  Widget _circleBtn(IconData icon, {required VoidCallback onTap}) => Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
        ),
        child: IconButton(
            icon: Icon(icon,
                size: 18, color: isDarkMode ? Colors.white : Colors.black),
            onPressed: onTap),
      );

  Widget _shimmerPfp() => AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) {
        final scale = 0.96 + 0.04 * math.sin(_pulseCtrl.value * math.pi);
        return Transform.scale(
            scale: scale,
            child: Stack(alignment: Alignment.center, children: [
              Shimmer.fromColors(
                baseColor: const Color(0xFFFFAF7B),
                highlightColor: const Color(0xFFD76D77),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
              CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.black,
                  backgroundImage: (_pfpUrl != null && _pfpUrl!.isNotEmpty)
                      ? NetworkImage(_pfpUrl!)
                      : null,
                  child: (_pfpUrl == null || _pfpUrl!.isEmpty)
                      ? const Icon(Icons.person, color: Colors.white)
                      : null)
            ]));
      });
}

// ─────────────────── community card ───────────────────
class _CommunityCard extends StatefulWidget {
  final bool dark;
  final Map<String, dynamic> data;
  final String status;
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final String? currentUserId;

  const _CommunityCard(
      {Key? key,
      required this.dark,
      required this.data,
      required this.status,
      required this.doc,
      required this.currentUserId})
      : super(key: key);

  @override
  State<_CommunityCard> createState() => _CommunityCardState();
}

class _CommunityCardState extends State<_CommunityCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final name = widget.data['name'] ?? 'Unnamed';
    final desc = widget.data['description'] ?? '';
    final img = widget.data['pfpUrl'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: widget.dark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: widget.dark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1)),
      ),
      child: Column(children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: AspectRatio(
              aspectRatio: 16 / 9,
              child: img.isNotEmpty
                  ? Image.network(img, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback(widget.dark))
                  : _fallback(widget.dark)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: widget.dark ? Colors.white : Colors.black)),
            const SizedBox(height: 6),
            Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: widget.dark ? Colors.white : Colors.black87)),
          ]),
        ),
        if (_busy)
          const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2))
        else
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: _actionRow(context))
      ]),
    );
  }

  Widget _fallback(bool dark) => Container(
      color: Colors.grey.shade900,
      child: Icon(Icons.image,
          color: dark ? Colors.white54 : Colors.black54));

  Widget _actionRow(BuildContext ctx) {
    final style = OutlinedButton.styleFrom(
        foregroundColor: widget.dark ? Colors.white : Colors.black);
    switch (widget.status) {
      case 'pending':
        return Row(children: [
          Expanded(
              child: OutlinedButton(
                  style: style,
                  onPressed: () => _update(false),
                  child: const Text('Decline'))),
          const SizedBox(width: 8),
          Expanded(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent,
                      foregroundColor: Colors.black),
                  onPressed: () => _update(true),
                  child: const Text('Approve'))),
          const SizedBox(width: 8),
          OutlinedButton(
              style: style,
              onPressed: _details,
              child: const Text('Details')),
        ]);
      case 'approved':
        return Row(children: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pinkAccent,
                  foregroundColor: widget.dark ? Colors.white : Colors.black,
                  shape: const CircleBorder()),
              onPressed: () => _update(false),
              child: Icon(Icons.delete_forever,
                  size: 20,
                  color: widget.dark ? Colors.white : Colors.black)),
          const SizedBox(width: 8),
          OutlinedButton(
              style: style,
              onPressed: _details,
              child: const Text('Details')),
        ]);
      case 'declined':
        return Row(children: [
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black),
              onPressed: _confirmCreate,
              child: const Text('Create')),
          const SizedBox(width: 8),
          OutlinedButton(
              style: style,
              onPressed: _details,
              child: const Text('Details')),
        ]);
      default:
        return const SizedBox();
    }
  }

  Future<void> _update(bool approve) async {
    setState(() => _busy = true);
    final upd = {
      'approvalStatus': approve ? 'approved' : 'declined',
      'approvedBy': widget.currentUserId,
      'approvedAt': FieldValue.serverTimestamp(),
    };
    await widget.doc.reference.set(upd, SetOptions(merge: true));
    await FirebaseFirestore.instance
        .collection('communityReview')
        .doc(widget.doc.id)
        .set({...widget.doc.data(), ...upd}, SetOptions(merge: true));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _confirmCreate() async {
    final ctr = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: widget.dark ? _darkSheet : Colors.white,
        titleTextStyle: TextStyle(
            color: widget.dark ? Colors.white : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600),
        contentTextStyle: TextStyle(
            color: widget.dark ? Colors.white : Colors.black87),
        title: const Text('Create this community?'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Type CREATE below to approve and create.'),
          const SizedBox(height: 8),
          TextField(
            controller: ctr,
            style: TextStyle(
                color: widget.dark ? Colors.white : Colors.black),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () =>
                  Navigator.pop(c, ctr.text.trim() == 'CREATE'),
              child: const Text('Create')),
        ],
      ),
    );
    if (ok == true) _update(true);
  }

  Future<void> _details() async {
    final creatorId = widget.data['creatorId'] ?? '';
    Map<String, dynamic>? userMap;
    if (creatorId.toString().isNotEmpty) {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .get();
      if (snap.exists) userMap = snap.data();
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) {
        final photo = userMap?['photoUrl'] ?? '';
        final dark = widget.dark;
        return Container(
          decoration: BoxDecoration(
              color: dark ? _darkSheet : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16))),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text(widget.data['name'] ?? '',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: dark ? Colors.white : Colors.black)),
            const SizedBox(height: 8),
            Text(widget.data['description'] ?? '',
                style: TextStyle(
                    color: dark ? Colors.white70 : Colors.black87)),
            const Divider(height: 24),
            ListTile(
              leading: CircleAvatar(
                backgroundImage: photo.toString().isNotEmpty
                    ? NetworkImage(photo)
                    : null,
                child:
                    photo.toString().isEmpty ? const Icon(Icons.person) : null,
              ),
              title: Text(userMap?['fullName'] ?? 'Unknown user',
                  style: TextStyle(
                      color: dark ? Colors.white : Colors.black)),
              subtitle: Text(userMap?['email'] ?? '—',
                  style: TextStyle(
                      color: dark ? Colors.white70 : Colors.black87)),
            ),
            const SizedBox(height: 24),
          ]),
        );
      },
    );
  }
}
