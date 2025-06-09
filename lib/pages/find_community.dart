import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math'; // For random selection
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:ragtagrevived/pages/review_page.dart';

// Pages
import 'package:ragtagrevived/pages/clubs_profile_page.dart';
import 'package:ragtagrevived/pages/interest_groups_profile_page.dart';
import 'package:ragtagrevived/pages/open_forums_profile_page.dart';
import 'package:ragtagrevived/pages/class_sync.dart';
import 'package:ragtagrevived/pages/profile_page.dart';

import 'user_directory_page.dart';
import 'uneditable_profile_page.dart'; // If needed

/// Crisp, sexy card for communities (LEAVE THIS ALONE, NO CHANGES)
class CrispCommunityCard extends StatelessWidget {
  final String name;
  final String description;
  final String photoUrl;

  const CrispCommunityCard({
    Key? key,
    required this.name,
    required this.description,
    required this.photoUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      width: 240,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2A2A2A), Color(0xFF1F1F1F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Left image
            photoUrl.isNotEmpty
                ? SizedBox(
                    width: 90,
                    height: 90,
                    child: FadeInImage.assetNetwork(
                      placeholder: 'assets/placeholder.png',
                      image: photoUrl,
                      fit: BoxFit.cover,
                      imageErrorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[900],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white54,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  )
                : Container(
                    width: 90,
                    height: 90,
                    color: Colors.grey[900],
                    child: const Icon(
                      Icons.image_not_supported,
                      color: Colors.white54,
                      size: 40,
                    ),
                  ),
            // Right text
            Expanded(
              child: Container(
                height: 90,
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.black54, Colors.transparent],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small, stateful wrapper that adds:
/// 1) A top-left "new.png" badge hanging off the card
/// 2) A scale-down animation on tap
/// 3) Navigation to the correct detail page
class PressableNewCard extends StatefulWidget {
  final Map<String, dynamic> community;
  final String? currentUserId;

  const PressableNewCard({
    Key? key,
    required this.community,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<PressableNewCard> createState() => _PressableNewCardState();
}

class _PressableNewCardState extends State<PressableNewCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final comm = widget.community;
    final name = comm['name'] ?? 'No Name';
    final desc = comm['description'] ?? 'No Description';
    final photoUrl = comm['pfpUrl'] ?? comm['photoUrl'] ?? '';
    final docId = comm['id'] ?? 'unknownId';
    final type = comm['type'] ?? _inferTypeFromCollectionName(comm['collection'] ?? '');

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        // Navigate to the correct page based on type
        if (type == 'Club') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ClubsProfilePage(
                communityId: docId,
                communityData: comm,
                userId: widget.currentUserId ?? '',
              ),
            ),
          );
        } else if (type == 'Interest Group') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RedesignedInterestGroupsPage(
                communityId: docId,
                communityData: comm,
                userId: widget.currentUserId ?? '',
              ),
            ),
          );
        } else if (type == 'Open Forum') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OpenForumsProfilePage(
                communityId: docId,
                communityData: comm,
                userId: widget.currentUserId ?? '',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Unknown community type: $type')),
          );
        }
      },
      // Slight scale animation
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            CrispCommunityCard(
              name: name,
              description: desc,
              photoUrl: photoUrl,
            ),
            // "NEW" badge
            Positioned(
              top: 6,
              left: -12, // negative left pushes it off the card
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black54,
                      offset: const Offset(2, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/new.png',
                  height: 30,
                  width: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _inferTypeFromCollectionName(String collectionName) {
    switch (collectionName) {
      case 'clubs':
        return 'Club';
      case 'interestGroups':
        return 'Interest Group';
      case 'openForums':
        return 'Open Forum';
      default:
        return 'Club'; // fallback
    }
  }
}

class FindCommunityPage extends StatefulWidget {
  const FindCommunityPage({super.key});

  @override
  State<FindCommunityPage> createState() => _FindCommunityPageState();
}

class _FindCommunityPageState extends State<FindCommunityPage>
    with SingleTickerProviderStateMixin {
  bool isDarkMode = true;
  bool isEducator = false;
  int currentPage = 0;
  late PageController _pageController;
  late Timer _timer;
  // ─── add these three private fields ───
  bool _hasAgreedTOS = false;      // tracks whether TOS accepted
  bool _isLoadingNew = false;      // true while “NEW” row fetches
  String? _newErrorMessage;        // non-null if fetch failed

  String? currentUserId;
  String? userInstitution;
  String? username;
  String? userProfilePicUrl;

  /// Tracks how many intro challenges the user has completed.
  /// 0 => none done
  /// 1 => #1 done
  /// 2 => #1 & #2 done
  /// 3 => all three
  int _introChallenge = 0;

  /// We'll keep your same 3 hero images:
  final List<String> heroImages = [
    "assets/club1.png",
    "assets/event1.png",
    "assets/club2.png",
  ];

  List<Map<String, dynamic>>? _cachedCommunities;
  DateTime? _lastFetchTime;
// Refresh every 30 min instead of 5 h
final Duration _cacheDuration = const Duration(minutes: 30);

/// A cached list is “fresh” **only if**:
/// • we actually have items, and
/// • the TTL hasn’t expired.
bool get _cacheIsFresh {
  if (_cachedCommunities == null ||
      _cachedCommunities!.isEmpty ||     // ← NEW: don’t cache empty results
      _lastFetchTime == null) return false;

  return DateTime.now().difference(_lastFetchTime!) < _cacheDuration;
}

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/sign-in');
      });
      return;
    } else {
      currentUserId = user.uid;
      _checkIfEducator();
      fetchUsername();
      fetchUserInstitution(user.uid);
      fetchUserPhotoUrl(user.uid);
      _fetchIntroChallengeStatus();
      _checkUserAgreementStatus(user.uid);
    }

    _pageController = PageController();
    _timer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      // (Unused auto-slide if needed)
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Check if the user has agreed to the TOS
  Future<void> _checkUserAgreementStatus(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        _hasAgreedTOS = data['hasAgreedToTOS'] ?? false;
      } else {
        _hasAgreedTOS = false;
      }
      // If not agreed, show the popup
      if (!_hasAgreedTOS) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showUserAgreementDialog();
        });
      }
    } catch (e) {
      debugPrint("Error checking user agreement: $e");
    }
  }

  /// Show the user agreement in a short, modern dialog
  void _showUserAgreementDialog() {
    showDialog(
      barrierDismissible: false, // force them to accept
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: double.infinity,
            // Shortened to ~ 39% screen height
            height: MediaQuery.of(context).size.height * 0.39,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // The scroller with a modern scrollbar
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    interactive: true,
                    child: SingleChildScrollView(
                      child: _buildUserAgreementContent(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildShimmerAcceptButton(),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The user agreement content, including Section 17
  Widget _buildUserAgreementContent() {
  final textColor = isDarkMode ? Colors.white70 : Colors.black87;

  /// Body text => Times New Roman
  final TextStyle bodyStyle = TextStyle(
    fontSize: 15,
    height: 1.4,
    color: textColor,
    fontFamily: 'Times New Roman',
  );

  /// Section headings => bold
  final TextStyle headingStyle = bodyStyle.copyWith(
    fontWeight: FontWeight.bold,
  );

  /// The main big title => Lovelo
  final TextStyle mainTitleStyle = TextStyle(
    fontSize: 24,
    fontFamily: 'Lovelo-Black',
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  /// The smaller date style
  final TextStyle dateStyle = bodyStyle.copyWith(
    fontSize: 13,
    color: textColor.withOpacity(0.8),
  );

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Main Title
      Text("User & EULA Agreement", style: mainTitleStyle),
      const SizedBox(height: 4),

      // Dates: smaller
      Text("Last Updated: January 27, 2025", style: dateStyle),
      Text("Effective Date: January 27, 2025", style: dateStyle),
      const SizedBox(height: 12),

      // Big Intro
      Text(
        "Welcome to Ragtag (the “App”), owned and operated by Ragtag Social LLC (“Ragtag,” “we,” “us,” or “our”). By using or accessing our App (including any associated websites, features, content, platforms, tools, and services), you (“User” or “you”) agree to comply with the terms and conditions set forth in this agreement (the “Agreement” or “Terms”). If you do not agree to these Terms, you must discontinue use of the App immediately.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 1. Acceptance of Terms
      Text("1. Acceptance of Terms", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "1.1 Binding Agreement\nBy downloading, installing, accessing, or using the App, you acknowledge that you have read, understood, and agree to be bound by this Agreement, our [Privacy Policy], and any additional guidelines, rules, or disclaimers posted within the App or our official website.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "1.2 Eligibility\nYou must be at least 13 years of age (or older if required in your jurisdiction) to use our App. If you are under 18, you represent that you have your parent or guardian’s permission to use the App. If you do not meet these requirements, you are not permitted to use or access the App.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 2. Accounts and Registration
      Text("2. Accounts and Registration", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "2.1 Account Creation\nTo access certain features, you may be required to create an account. You agree to:\n• Provide accurate, current, and complete information during registration.\n• Keep your account credentials confidential.\n• Maintain and promptly update your information to keep it accurate and complete.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "2.2 Account Security\nYou are responsible for any activity that occurs under your username and password, whether or not authorized. If you suspect any unauthorized use of your account, notify us immediately at [Contact Email or Support Portal].",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "2.3 Multiple Accounts\nYou may not create multiple accounts for the purpose of abusing the functionality of the App or circumventing any restrictions.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 3. License and App Usage
      Text("3. License and App Usage", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "3.1 Limited License\nRagtag grants you a non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes, subject to these Terms and any other guidelines we provide.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "3.2 Prohibited Activities\nIn using the App, you agree not to:\n• Violate any applicable local, state, national, or international law.\n• Reverse-engineer, decompile, modify, or create derivative works of the App or its features (including but not limited to “Campus Commons,” “Class Sync,” and “FOMO Feed”) unless explicitly permitted by applicable law.\n• Use the App to transmit any spam, viruses, or harmful content.\n• Engage in automated data collection (e.g., bots, spiders, scrapers) unless expressly permitted in writing by Ragtag.\n• Attempt to gain unauthorized access to other users’ accounts or our systems.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 4. User Conduct and Community Guidelines
      Text("4. User Conduct and Community Guidelines", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "4.1 Behavioral Standards\nYou are solely responsible for any content you post, share, or otherwise make available through the App. You agree not to:\n• Post content that is defamatory, obscene, hateful, harassing, threatening, or otherwise objectionable.\n• Impersonate any person or entity, or falsely state or misrepresent your affiliation with a person or entity.\n• Post any content that infringes or violates the intellectual property rights of others.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "4.2 Zero Tolerance for Abusive and Objectionable Content\nWe enforce a strict, zero-tolerance policy for abusive behavior and objectionable content. Any content or conduct that violates this policy will be removed immediately, and repeat offenders may have their accounts suspended or terminated without prior notice.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "4.3 Reporting Violations\nIf you observe content or user behavior that violates these Terms, please notify us at [Contact Email or Support Portal]. Ragtag reserves the right to remove or modify any content that violates our policies or is otherwise objectionable.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 5. User-Generated Content
      Text("5. User-Generated Content", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "5.1 Ownership of Your Content\nYou retain all intellectual property rights in any content you create and share on the App (“User Content”). By posting or sharing User Content, you represent that you own or have the necessary permissions to share such content.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "5.2 License to Ragtag\nBy submitting or posting User Content, you grant Ragtag a non-exclusive, worldwide, royalty-free, transferable license to use, store, display, reproduce, distribute, modify, and create derivative works of your User Content for the purpose of operating, developing, providing, and improving the App.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "5.3 Content Removal\nRagtag reserves the right, but is not obligated, to remove any User Content that, at our sole discretion, violates these Terms or is otherwise objectionable.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 6. Intellectual Property Rights
      Text("6. Intellectual Property Rights", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "6.1 Ragtag Ownership\nAll content, features, functionality, trademarks, service marks, and trade names (including but not limited to “Ragtag,” “Campus Commons,” “Class Sync,” and “FOMO Feed”) are owned by Ragtag Social LLC or its licensors, and are protected by copyright, trademark, patent, trade secret, or other intellectual property laws.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "6.2 No Implied Rights\nExcept for the limited license granted herein, nothing in this Agreement transfers any ownership or license of our intellectual property to you.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 7. Privacy and Data Collection
      Text("7. Privacy and Data Collection", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "Our [Privacy Policy] explains how we collect, use, and share information about you when you use our App. By using the App, you consent to the collection and use of your data as outlined in that policy.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 8. Paid Features or Subscriptions (If Applicable)
      Text("8. Paid Features or Subscriptions (If Applicable)", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "8.1 Subscription Fees\nRagtag may offer certain premium features or subscriptions for a fee. The pricing and payment terms will be described at the point of purchase.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "8.2 Free Trials\nIf we offer free trials, you may be required to cancel before the trial ends to avoid being charged.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "8.3 Refunds\nRefund requests will be evaluated on a case-by-case basis according to applicable consumer protection laws and our internal policy.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 9. Third-Party Services and Links
      Text("9. Third-Party Services and Links", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "9.1 Third-Party Content\nThe App may contain links to third-party websites or services that are not under our control. We are not responsible for the content, privacy policies, or practices of any third-party services.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "9.2 No Endorsement\nAny reference to third-party products, services, or websites is not an endorsement or recommendation by Ragtag.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 10. Disclaimer of Warranties
      Text("10. Disclaimer of Warranties", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "10.1 “AS IS” and “AS AVAILABLE”\nYour use of the App is at your sole risk. The App is provided on an “AS IS” and “AS AVAILABLE” basis without warranties of any kind, whether express or implied, including but not limited to the implied warranties of merchantability, fitness for a particular purpose, or non-infringement.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "10.2 No Guarantee\nWe do not guarantee that the App will be secure, uninterrupted, error-free, or free of viruses or other harmful components. We do not guarantee any specific results from using the App.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 11. Limitation of Liability
      Text("11. Limitation of Liability", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "11.1 No Indirect Damages\nTo the maximum extent permitted by law, Ragtag Social LLC and its affiliates, officers, employees, agents, or partners shall not be liable to you for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, or goodwill.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "11.2 Cap on Liability\nIn no event shall Ragtag’s total liability for all claims arising out of or related to these Terms exceed the amount paid by you (if any) for accessing or using the App in the twelve (12) months preceding the event giving rise to liability.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 12. Indemnification
      Text("12. Indemnification", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "You agree to defend, indemnify, and hold harmless Ragtag Social LLC, its affiliates, and their respective officers, directors, employees, and agents from and against any claims, damages, obligations, losses, liabilities, costs, or debt, and expenses (including but not limited to attorney’s fees) arising from:\n• Your use or misuse of the App.\n• Your violation of any term of this Agreement.\n• Your violation of any third-party right, including without limitation any intellectual property or privacy right.\n• Another’s misuse/violation of the App",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 13. Term and Termination
      Text("13. Term and Termination", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "13.1 Termination by User\nYou may terminate your account and stop using the App at any time.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "13.2 Termination by Ragtag\nWe may suspend or terminate your access to the App if we believe you have violated these Terms or for any other reason at our sole discretion, with or without notice.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "13.3 Effect of Termination\nUpon termination, all rights granted to you under this Agreement shall cease. Sections regarding intellectual property, disclaimers, liability limitations, and indemnification shall survive termination.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 14. Governing Law and Dispute Resolution
      Text("14. Governing Law and Dispute Resolution", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "14.1 Governing Law\nThis Agreement shall be governed by and construed in accordance with the laws of the [State/Country], without regard to its conflict of law principles.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "14.2 Arbitration\nAny dispute, claim, or controversy arising out of or relating to this Agreement or the breach thereof shall be settled by binding arbitration in a decided jurisdiction, in accordance with the rules of the American Arbitration Association. Judgment on the award rendered by the arbitrator may be entered in any court having jurisdiction thereof.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "14.3 Venue and Jurisdiction\nIf arbitration is not mandated, you agree to submit to the personal jurisdiction of the state and federal courts located in Raleigh, North Carolina, and you agree to waive any objections to the exercise of jurisdiction over you by such courts.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 15. Changes to These Terms
      Text("15. Changes to These Terms", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "We reserve the right, at our sole discretion, to modify or replace these Terms at any time. We will make reasonable efforts to notify you of material changes, such as by posting the updated Agreement within the App or sending a notification. Your continued use of the App after any such changes constitutes your acceptance of the new Terms.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 16. General Provisions
      Text("16. General Provisions", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "16.1 Entire Agreement\nThis Agreement, together with the Privacy Policy, constitutes the entire agreement between you and Ragtag and supersedes any prior agreements or understandings.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "16.2 Severability\nIf any provision of this Agreement is found to be invalid, illegal, or unenforceable, the remaining provisions shall remain in full force and effect.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "16.3 No Waiver\nNo waiver of any term or condition herein shall be deemed a further or continuing waiver of such term or any other term, and Ragtag’s failure to assert any right or provision under these Terms shall not constitute a waiver.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "16.4 Assignment\nYou may not assign or transfer your rights or obligations under these Terms without our prior written consent. We may freely assign our rights and obligations under these Terms.",
        style: bodyStyle,
      ),
      const SizedBox(height: 6),
      Text(
        "16.5 Electronic Communications\nYou consent to receive communications electronically from us, and you agree that any notices, agreements, disclosures, or other communications we provide electronically satisfy any legal requirements for written communication.",
        style: bodyStyle,
      ),
      const SizedBox(height: 16),

      // 17. Contact Information
      Text("17. Contact Information", style: headingStyle),
      const SizedBox(height: 6),
      Text(
        "If you have any questions or concerns about this Agreement, please contact us at:\nRagtag Social LLC\nAttn: Nicholas Cooke (Founder & CEO)\nreachragtag@gmail.com",
        style: bodyStyle,
      ),
      const SizedBox(height: 20),
    ],
  );
}

  /// The "Accept" pill button (Shimmer)
  Widget _buildShimmerAcceptButton() {
    return GestureDetector(
      onTap: _onAcceptUserAgreement,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shimmer Outline
          Shimmer.fromColors(
            baseColor: const Color(0xFFFFAF7B),
            highlightColor: const Color(0xFFD76D77),
            child: Container(
              width: 120,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
          // Black pill
          Container(
            width: 114,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text(
                "Accept",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Times New Roman',
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Accept action
  Future<void> _onAcceptUserAgreement() async {
    if (currentUserId == null) return;
    Navigator.of(context).pop(); // close the dialog
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({'hasAgreedToTOS': true});
      setState(() {
        _hasAgreedTOS = true;
      });
    } catch (e) {
      debugPrint("Error storing user agreement acceptance: $e");
    }
  }

  Future<void> fetchUsername() async {
    if (currentUserId == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      if (userDoc.exists) {
        setState(() {
          username = userDoc['username'] ?? "@Anonymous";
        });
      }
    } catch (e) {
      debugPrint("Error fetching username: $e");
    }
  }

  Future<void> fetchUserPhotoUrl(String uid) async {
    try {
      final docSnap =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        setState(() {
          userProfilePicUrl = data['photoUrl'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching user photoUrl: $e');
    }
  }

  Future<void> fetchUserInstitution(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          userInstitution = data['institution'] ?? '';
        });
      } else {
        debugPrint("User doc does not exist or missing 'institution' field.");
      }
    } catch (e) {
      debugPrint("Error fetching user institution: $e");
    }
  }

// ──────────────────────────────────────────────────────────
// Look up privilege once and flip the flag
Future<void> _checkIfEducator() async {
  if (currentUserId == null) return;

  final snap = await FirebaseFirestore.instance
      .collection('users')
      .doc(currentUserId)
      .get();

  if (snap.exists && snap.data()?['privileges'] == 'educator') {
    if (mounted) setState(() => isEducator = true);
  }
}
// ──────────────────────────────────────────────────────────
  /// INTRO CHALLENGE LOGIC
  Future<void> _fetchIntroChallengeStatus() async {
    if (currentUserId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();

      if (!userDoc.exists) return;
      final data = userDoc.data()!;
      final intVal = data['introchallenge'] ?? 0;
      setState(() {
        _introChallenge = intVal;
      });
    } catch (e) {
      debugPrint("Error fetching introchallenge: $e");
    }
  }

  /// Build the 3-step intro challenges at the top
  Widget _buildIntroChallengesSection() {
    final String firstTitle =
        (_introChallenge >= 1) ? "Edit Your Profile" : "Complete Your Profile";

    final challenges = [
      {
        "title": firstTitle,
        "subtitle": "Edit your profile, set your vibe!",
        "image": heroImages[0],
        "index": 0,
      },
      {
        "title": "Try Something New",
        "subtitle": "View Communities!",
        "image": heroImages[1],
        "index": 1,
      },
      {
        "title": "Try it yourself!",
        "subtitle": "Check out an open forum!",
        "image": heroImages[2],
        "index": 2,
      },
    ];

    return SizedBox(
      height: 280,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: challenges.map((challenge) {
            final idx = challenge['index'] as int;
            final locked = _introChallenge < idx;
            final imagePath = challenge['image'] as String;
            final title = challenge['title'] as String;
            final sub = challenge['subtitle'] as String;

            return Container(
              margin: const EdgeInsets.only(right: 14),
              width: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                image: DecorationImage(
                  image: AssetImage(imagePath),
                  fit: BoxFit.cover,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Subtle dark overlay
                    Container(
                      color: Colors.black.withOpacity(0.3),
                    ),

                    // Lock overlay if locked
                    if (locked)
                      Container(
                        color: Colors.black.withOpacity(0.6),
                        child: const Center(
                          child: Icon(
                            Icons.lock,
                            color: Colors.white70,
                            size: 60,
                          ),
                        ),
                      ),

                    // Bottom text area
                    Positioned(
                      bottom: 15,
                      left: 15,
                      right: 15,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Lovelo-Black',
                              shadows: [
                                Shadow(
                                  offset: Offset(0.5, 0.5),
                                  blurRadius: 4.0,
                                  color: Colors.black87,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sub,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontFamily: 'Lovelo-Black',
                              shadows: [
                                Shadow(
                                  offset: Offset(0.5, 0.5),
                                  blurRadius: 4.0,
                                  color: Colors.black87,
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // A black circle with white outline + shimmer icon
                    if (!locked)
                      Positioned(
                        bottom: 15,
                        right: 15,
                        child: GestureDetector(
                          onTap: () async {
                            if (idx == 0) {
                              // #1 => Profile
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ProfilePage(),
                                ),
                              );
                              await _markChallengeComplete(1);
                            } else if (idx == 1) {
                              // #2 => All Orgs
                              Navigator.pushNamed(
                                context,
                                '/all_organizations',
                              );
                              await _markChallengeComplete(2);
                            } else if (idx == 2) {
                              // #3 => no direct nav
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Shimmer.fromColors(
                                baseColor: const Color(0xFFFFAF7B),
                                highlightColor: const Color(0xFFD76D77),
                                child: Icon(
                                  idx == 2
                                      ? Icons.chat_bubble_outline
                                      : Icons.chevron_right,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _markChallengeComplete(int newValue) async {
    if (currentUserId == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .update({"introchallenge": newValue});
      setState(() {
        _introChallenge = newValue;
      });
    } catch (e) {
      debugPrint("Error updating introchallenge: $e");
    }
  }

  /// Username menu (top-left)
  Widget _buildUsernameMenu() {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: isDarkMode ? Colors.grey[850] : Colors.white,
        onSelected: (value) async {
          if (value == 'signOut') {
            await FirebaseAuth.instance.signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/openingLandingPage');
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.black54 : Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  username ?? "@Loading...",
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black,
                    fontFamily: 'Lovelo-Black',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ],
          ),
        ),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'signOut',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: const [
                Icon(Icons.exit_to_app, color: Colors.redAccent, size: 20),
                SizedBox(width: 6),
                Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// "NEW Communities" row
  Widget _buildNewCommunitiesSection() {
    if (userInstitution == null || userInstitution!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Loading institution-based communities..."),
        ),
      );
    }

    if (_cacheIsFresh) {
      return _buildCommunitiesRow(_cachedCommunities!);
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchNewCommunitiesOnce(userInstitution!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting ||
            _isLoadingNew) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_newErrorMessage != null) {
          return Center(
            child: Text(
              _newErrorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error: ${snapshot.error}",
              style: const TextStyle(color: Colors.red),
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

        return _buildCommunitiesRow(newCommunities);
      },
    );
  }

  Widget _buildCommunitiesRow(List<Map<String, dynamic>> communities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: communities.map((comm) {
              return PressableNewCard(
                community: comm,
                currentUserId: currentUserId,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

/// 3 big (or 4, if educator) image-buttons row
Widget buildActionButtons() {
  final screenWidth = MediaQuery.of(context).size.width;
  const double buttonHeight = 180.0;
  const double spacing = 2.0;

  // ───────── build the list dynamically ─────────
  final List<Widget> buttons = [];

  // Educator-only “Review” button
  if (isEducator) {
    buttons.add(
      _ScalableImageButton(
        imagePath: 'assets/review.png',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReviewPage()),
          );
        },
        height: buttonHeight,
      ),
    );
    buttons.add(const SizedBox(width: spacing)); // add a spacer *after* it
  }

  // Everyone sees these three:
  buttons.addAll([
    _ScalableImageButton(
      imagePath: 'assets/allorganizations.png',
      onTap: () => Navigator.pushNamed(context, '/all_organizations'),
      height: buttonHeight,
    ),
    const SizedBox(width: spacing),
    _ScalableImageButton(
      imagePath: 'assets/events.png',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClassSyncPage()),
      ),
      height: buttonHeight,
    ),
    const SizedBox(width: spacing),
    _ScalableImageButton(
      imagePath: 'assets/usersearch.png',
      onTap: () {
        if (userInstitution != null && userInstitution!.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => UserDirectoryPage(institution: userInstitution!),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No institution available for user.")),
          );
        }
      },
      height: buttonHeight,
    ),
  ]);

  // ───────── render ─────────
  return SizedBox(
    width: screenWidth,
    height: buttonHeight,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons,
      ),
    ),
  );
}

  /// "Discover By Category"
  Widget buildDiscoverByCategory() {
    final categories = [
      {
        'icon': Icons.menu_book,
        'title': 'Academic / Subject-Based',
        'description': 'Focus on academic pursuits',
        'color': Colors.orangeAccent,
        'categoryKey': 'Academic / Subject-Based',
      },
      {
        'icon': Icons.volunteer_activism,
        'title': 'Service / Philanthropy',
        'description': 'Volunteer & give back',
        'color': Colors.redAccent,
        'categoryKey': 'Service / Philanthropy',
      },
      {
        'icon': Icons.brush,
        'title': 'Creative Expression',
        'description': 'Art, music, dance, etc.',
        'color': Colors.purpleAccent,
        'categoryKey': 'Creative Expression',
      },
      {
        'icon': Icons.campaign_outlined,
        'title': 'Political / Advocacy',
        'description': 'Civic initiatives',
        'color': Colors.pinkAccent,
        'categoryKey': 'Political / Advocacy',
      },
      {
        'icon': Icons.auto_awesome,
        'title': 'Faith / Religious',
        'description': 'Faith-based gatherings',
        'color': Colors.amberAccent,
        'categoryKey': 'Faith / Religious',
      },
      {
        'icon': Icons.work_outline,
        'title': 'Professional Development',
        'description': 'Build your career & skills',
        'color': Colors.greenAccent,
        'categoryKey': 'Professional Development',
      },
      {
        'icon': Icons.language,
        'title': 'Cultural',
        'description': 'Celebrate heritage & traditions',
        'color': Colors.blueAccent,
        'categoryKey': 'Cultural',
      },
      {
        'icon': Icons.account_balance,
        'title': 'Leadership / Student Gov',
        'description': 'Student councils, etc.',
        'color': Colors.indigoAccent,
        'categoryKey': 'Leadership / Student Gov',
      },
      {
        'icon': Icons.sports_soccer,
        'title': 'Sports / Wellness',
        'description': 'Fitness & healthy living',
        'color': Colors.tealAccent,
        'categoryKey': 'Sports / Wellness',
      },
      {
        'icon': Icons.sentiment_satisfied_alt,
        'title': 'Hobby',
        'description': 'Fun, casual interests',
        'color': Colors.lightBlue,
        'categoryKey': 'Hobby',
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Surprise Me",
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'Lovelo-Black',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Randomly explore communities that align with each category.",
            style: TextStyle(
              color: isDarkMode ? Colors.white70 : Colors.black54,
              fontSize: 14,
              fontFamily: 'Lovelo-Black',
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 16),
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final color = cat['color'] as Color;
                final iconData = cat['icon'] as IconData;
                final title = cat['title']?.toString() ?? '';
                final description = cat['description']?.toString() ?? '';
                final categoryKey = cat['categoryKey']?.toString() ?? '';

                return _ScalableCategoryBox(
                  color: color,
                  iconData: iconData,
                  title: title,
                  description: description,
                  onTap: () => _openRandomCommunityByCategory(categoryKey),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// On tapping a category, we fetch random community in that category, *excluding ghost-mode*
  Future<void> _openRandomCommunityByCategory(String categoryKey) async {
    if (userInstitution == null || userInstitution!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No institution available for user.")),
      );
      return;
    }

    final clubs = await _fetchCategoryCommunitiesOnce(
      'clubs',
      userInstitution!,
      categoryKey,
    );
    final igs = await _fetchCategoryCommunitiesOnce(
      'interestGroups',
      userInstitution!,
      categoryKey,
    );
    final forums = await _fetchCategoryCommunitiesOnce(
      'openForums',
      userInstitution!,
      categoryKey,
    );

    final all = [...clubs, ...igs, ...forums];
    if (all.isEmpty) {
      _showNoCommunitiesDialog();
      return;
    }

    final rand = Random();
    final chosen = all[rand.nextInt(all.length)];
    final docId = chosen['id'] ?? '';
    final collectionName = chosen['collection'] ?? '';
    final type = chosen['type'] ?? _inferTypeFromCollectionName(collectionName);

    if (type == 'Club') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubsProfilePage(
            communityId: docId,
            communityData: chosen,
            userId: currentUserId ?? '',
          ),
        ),
      );
    } else if (type == 'Interest Group') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RedesignedInterestGroupsPage(
            communityId: docId,
            communityData: chosen,
            userId: currentUserId ?? '',
          ),
        ),
      );
    } else if (type == 'Open Forum') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OpenForumsProfilePage(
            communityId: docId,
            communityData: chosen,
            userId: currentUserId ?? '',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unknown community type: $type')),
      );
    }
  }

  /// Exclude `isGhostMode == true` from results
  Future<List<Map<String, dynamic>>> _fetchCategoryCommunitiesOnce(
    String collectionName,
    String institution,
    String categoryKey,
  ) async {
    final querySnap = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('institution', isEqualTo: institution)
        .where('categories', arrayContains: categoryKey)
        .get();

    return querySnap.docs
        .map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          data['collection'] = collectionName;
          data['type'] = data['type'] ?? _inferTypeFromCollectionName(collectionName);
          return data;
        })
        // Filter out ghost-mode docs
        .where((comm) => comm['isGhostMode'] != true)
        .toList();
  }

  /// NO COMMUNITIES FOUND DIALOG
  void _showNoCommunitiesDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _buildNoCommunitiesDialog();
      },
    );
  }

  Widget _buildNoCommunitiesDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.white, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: Colors.black,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // The main card content
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "No Communities Found",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Image.asset(
                    'assets/sadface.png',
                    height: 60,
                    width: 60,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "No clubs match that category.\nWhy not start one?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Maybe Later",
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _buildShimmeringOutlineButton(
                        label: "Sure!",
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(
                            context,
                            '/start-community',
                            arguments: currentUserId,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // The white circle at the top LEFT
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// White button with black text, shimmering color only on the border
  Widget _buildShimmeringOutlineButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Shimmer.fromColors(
            baseColor: const Color(0xFFFFAF7B),
            highlightColor: const Color(0xFFD76D77),
            child: Container(
              height: 42,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(width: 2, color: Colors.white),
              ),
            ),
          ),
          Container(
            height: 36,
            width: 114,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The theme toggle
  Widget _buildThemeToggle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black54 : Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: IconButton(
          icon: Icon(
            isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => setState(() {
            isDarkMode = !isDarkMode;
          }),
        ),
      ),
    );
  }

  /// User PFP with shimmer circle
  Widget _buildShimmeringUserPfp() {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/profilePage');
      },
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 8),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Shimmer.fromColors(
              baseColor: const Color(0xFFFFAF7B),
              highlightColor: const Color(0xFFD76D77),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                ),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.black,
              backgroundImage: (userProfilePicUrl != null &&
                      userProfilePicUrl!.isNotEmpty)
                  ? NetworkImage(userProfilePicUrl!)
                  : null,
              child: (userProfilePicUrl == null || userProfilePicUrl!.isEmpty)
                  ? const Icon(
                      Icons.person,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// The bottom nav
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
          color: isDarkMode ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Admin
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/admin-dashboard');
                },
                child: Icon(
                  Icons.admin_panel_settings,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 40,
                ),
              ),
            ),
            // Explore => replaced with FOMO Feed logo @ height 34
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/fomo_feed'),
                child: Image.asset(
                  isDarkMode
                      ? 'assets/fomofeedlogo.png'
                      : 'assets/fomofeedlogoblack.png',
                  height: 34,
                ),
              ),
            ),
            // Center logo
            GestureDetector(
              onTap: () {
                // Brings us back to the FindCommunityPage
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FindCommunityPage(),
                  ),
                );
              },
              child: Image.asset(
                isDarkMode
                    ? 'assets/ragtaglogo.png'
                    : 'assets/ragtaglogoblack.png',
                height: 40,
              ),
            ),
            // plus icon
            _buildFooterIcon(
              Icons.add,
              color: isDarkMode ? Colors.white : Colors.black,
              onTap: () {
                Navigator.pushNamed(
                  context,
                  '/start-community',
                  arguments: currentUserId,
                );
              },
            ),
            _buildShimmeringUserPfp(),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterIcon(
    IconData icon, {
    required Color color,
    required Function() onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }

  /// The scaffold
  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF000000) : Colors.white,
      bottomNavigationBar: buildFooter(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      floatingActionButton: _buildThemeToggle(),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: isDarkMode ? Colors.black : Colors.white,
              expandedHeight: 110.0,
              floating: false,
              pinned: false,
              elevation: 0,
              leadingWidth: 190,
              automaticallyImplyLeading: false,
              leading: Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 10.0),
                child: _buildUsernameMenu(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 96),
                    child: Image.asset(
                      isDarkMode
                          ? 'assets/flatlogo.png'
                          : 'assets/flatlogoblack.png',
                      height: 38,
                      width: 140,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Text(
                            'Image not found',
                            style: TextStyle(color: Colors.red),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        // main content
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              // Our 3-step challenges
              _buildIntroChallengesSection(),
              const SizedBox(height: 10),
              _buildNewCommunitiesSection(),
              const SizedBox(height: 10),
              buildActionButtons(),
              const SizedBox(height: 10),
              buildDiscoverByCategory(),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  /// Caching logic for "NEW Communities"
  Future<List<Map<String, dynamic>>> _fetchNewCommunitiesOnce(
    String institution,
  ) async {
    if (_cachedCommunities != null && _lastFetchTime != null) {
      final elapsed = DateTime.now().difference(_lastFetchTime!);
      if (elapsed < _cacheDuration) {
        return _cachedCommunities!;
      }
    }

    try {
      setState(() {
        _isLoadingNew = true;
        _newErrorMessage = null;
      });

      final clubsList = await _fetchCollectionOnce('clubs', institution);
      final igsList = await _fetchCollectionOnce('interestGroups', institution);
      final forumsList = await _fetchCollectionOnce('openForums', institution);

      final combined = [...clubsList, ...igsList, ...forumsList];
      combined.shuffle();
      final results = combined.take(6).toList();

      _cachedCommunities = results;
      _lastFetchTime = DateTime.now();
      return results;
    } catch (e) {
      setState(() => _newErrorMessage = "Error fetching communities: $e");
      return [];
    } finally {
      setState(() => _isLoadingNew = false);
    }
  }

  /// Pull from a given collection, enforce approval, and skip ghost-mode
  Future<List<Map<String, dynamic>>> _fetchCollectionOnce(
    String collectionName,
    String institution,
  ) async {
    // Base query for the user’s institution
    Query query = FirebaseFirestore.instance
        .collection(collectionName)
        .where('institution', isEqualTo: institution);

    // Require "approved" status for Clubs, Interest Groups, and Open Forums
    if (collectionName == 'clubs' ||
        collectionName == 'interestGroups' ||
        collectionName == 'openForums') {
      query = query.where('approvalStatus', isEqualTo: 'approved');
    }

    final querySnap = await query.get();

    // Convert to strongly-typed Map and filter out ghost-mode docs
    final List<Map<String, dynamic>> results = querySnap.docs
        .where((doc) =>
            (doc.data() as Map<String, dynamic>)['isGhostMode'] != true)
        .map<Map<String, dynamic>>((doc) {
      final Map<String, dynamic> data =
          doc.data() as Map<String, dynamic>; // explicit cast
      data['id'] = doc.id;
      data['collection'] = collectionName;
      data['type'] =
          data['type'] ?? _inferTypeFromCollectionName(collectionName);
      return data;
    }).toList();

    return results;
  }

  String _inferTypeFromCollectionName(String collectionName) {
    switch (collectionName) {
      case 'clubs':
        return 'Club';
      case 'interestGroups':
        return 'Interest Group';
      case 'openForums':
        return 'Open Forum';
      default:
        return 'Club';
    }
  }
}

/// A helper widget for the 3 big images row that shrinks slightly on tap.
class _ScalableImageButton extends StatefulWidget {
  final String imagePath;
  final double height;
  final VoidCallback onTap;

  const _ScalableImageButton({
    required this.imagePath,
    required this.onTap,
    this.height = 180.0,
  });

  @override
  State<_ScalableImageButton> createState() => _ScalableImageButtonState();
}

class _ScalableImageButtonState extends State<_ScalableImageButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Image.asset(
          widget.imagePath,
          fit: BoxFit.cover,
          height: widget.height,
        ),
      ),
    );
  }
}

/// A helper widget for categories with a color, icon, text,
/// and a scale-down animation on tap.
class _ScalableCategoryBox extends StatefulWidget {
  final Color color;
  final IconData iconData;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ScalableCategoryBox({
    required this.color,
    required this.iconData,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  State<_ScalableCategoryBox> createState() => _ScalableCategoryBoxState();
}

class _ScalableCategoryBoxState extends State<_ScalableCategoryBox> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: widget.color,
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 20,
              horizontal: 16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.iconData, size: 48, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Lovelo-Black',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.3,
                    fontFamily: 'Lovelo-Black',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
