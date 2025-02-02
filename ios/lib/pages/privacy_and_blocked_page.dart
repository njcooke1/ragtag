import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class PrivacyAndBlockedPage extends StatefulWidget {
  const PrivacyAndBlockedPage({Key? key}) : super(key: key);

  @override
  State<PrivacyAndBlockedPage> createState() => _PrivacyAndBlockedPageState();
}

class _PrivacyAndBlockedPageState extends State<PrivacyAndBlockedPage> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  /// Dark/light background toggle
  bool isDarkMode = true;

  /// If true => 'privacy': 'quiet', else remove 'privacy'
  bool _isBlockingStrangerMessages = false;

  /// Device Permissions (locally tracked).
  /// We'll default each permission to TRUE if not found in Firestore.
  bool _cameraEnabled = true;
  bool _contactsEnabled = true;
  bool _notificationsEnabled = true;
  bool _photosEnabled = true;

  /// Large block of legal text for expansion
  final String _copyrightText = """
Copyright Notice
© 2025 Ragtag Social LLC. All Rights Reserved.

This mobile application, Ragtag (the “App”), including but not limited to its design, interface, underlying technology, concepts, and all associated features—such as “Campus Commons,” “Class Sync,” and “FOMO Feed”—is the property of Ragtag Social LLC (“Ragtag,” “we,” “us,” or “our”) and is protected by copyright and other intellectual property laws.

Ownership
1.1. The design, layout, graphics, logos, icons, text, software code, algorithms, trade secrets, and all other materials forming part of the App (collectively, the “Content”) are the exclusive property of Ragtag Social LLC.
1.2. The distinctive and original elements of features like “Campus Commons,” “Class Sync,” and “FOMO Feed” are covered by copyright and may also be protected by trademark and/or patent laws, as applicable.

Scope of Rights
2.1. Downloading, installing, or using the App does not transfer any intellectual property rights to you.
2.2. You are granted a non-exclusive, non-transferable, revocable license to use the App solely for personal, non-commercial purposes, in accordance with Ragtag’s Terms of Use.
2.3. Except as explicitly authorized by Ragtag Social LLC, you may not copy, reproduce, redistribute, transmit, display, publish, or otherwise exploit any portion of the App or its Content.

Prohibited Use
3.1. You may not reverse-engineer, decompile, or otherwise attempt to extract the source code of the App or any part thereof, unless such activity is expressly permitted by applicable law.
3.2. You may not create derivative works or resell any part of this App without prior written permission from Ragtag Social LLC.

Trademarks
4.1. Any logos, names, or other trademarks (registered or unregistered) used in this App—including but not limited to “Ragtag,” “Campus Commons,” “Class Sync,” and “FOMO Feed”—are the property of Ragtag Social LLC.
4.2. No license to use these trademarks is granted. Unauthorized use may violate applicable trademark laws.

Third-Party Materials
5.1. This App may include or integrate materials or code owned by third parties, which are provided under their respective licenses.
5.2. Such licenses only permit the specific use of these third-party materials and do not grant ownership or extended rights.

Reservation of Rights
6.1. All rights not expressly granted in this Notice or in the Terms of Use are reserved by Ragtag Social LLC.
6.2. Failure to enforce any rights under this Notice does not constitute a waiver of such rights.

Violation and Enforcement
7.1. Unauthorized use of the App and its Content—including but not limited to duplication, reproduction, or redistribution in violation of the license granted herein—may subject you to civil and criminal liability.
7.2. Ragtag Social LLC reserves the right to pursue all legal remedies available under applicable law in the event of unauthorized use of the App or any of its components.

Updates and Revisions
8.1. Ragtag Social LLC reserves the right to modify, update, or discontinue any part of the App at any time without prior notice.
8.2. Ragtag Social LLC may also revise this Copyright Notice or other legal documentation from time to time. The most current version will be available within the App or on our official website.
""";

  final String _userAgreementText = """
Ragtag User Agreement
Last Updated: January 27, 2025
Effective Date: January 27, 2025
Welcome to Ragtag (the “App”), owned and operated by Ragtag Social LLC (“Ragtag,” “we,” “us,” or “our”). By using or accessing our App (including any associated websites, features, content, platforms, tools, and services), you (“User” or “you”) agree to comply with the terms and conditions set forth in this agreement (the “Agreement” or “Terms”). If you do not agree to these Terms, you must discontinue use of the App immediately.

1. Acceptance of Terms
1.1 Binding Agreement
By downloading, installing, accessing, or using the App, you acknowledge that you have read, understood, and agree to be bound by this Agreement, our [Privacy Policy], and any additional guidelines, rules, or disclaimers posted within the App or our official website.
1.2 Eligibility
You must be at least 13 years of age (or older if required in your jurisdiction) to use our App. If you are under 18, you represent that you have your parent or guardian’s permission to use the App. If you do not meet these requirements, you are not permitted to use or access the App.

2. Accounts and Registration
2.1 Account Creation
To access certain features, you may be required to create an account. You agree to:
• Provide accurate, current, and complete information during registration.
• Keep your account credentials confidential.
• Maintain and promptly update your information to keep it accurate and complete.
2.2 Account Security
You are responsible for any activity that occurs under your username and password, whether or not authorized. If you suspect any unauthorized use of your account, notify us immediately at [Contact Email or Support Portal].
2.3 Multiple Accounts
You may not create multiple accounts for the purpose of abusing the functionality of the App or circumventing any restrictions.

3. License and App Usage
3.1 Limited License
Ragtag grants you a non-exclusive, non-transferable, revocable license to use the App for personal, non-commercial purposes, subject to these Terms and any other guidelines we provide.
3.2 Prohibited Activities
In using the App, you agree not to:
• Violate any applicable local, state, national, or international law.
• Reverse-engineer, decompile, modify, or create derivative works of the App or its features (including but not limited to “Campus Commons,” “Class Sync,” and “FOMO Feed”) unless explicitly permitted by applicable law.
• Use the App to transmit any spam, viruses, or harmful content.
• Engage in automated data collection (e.g., bots, spiders, scrapers) unless expressly permitted in writing by Ragtag.
• Attempt to gain unauthorized access to other users’ accounts or our systems.

4. User Conduct and Community Guidelines
4.1 Behavioral Standards
You are solely responsible for any content you post, share, or otherwise make available through the App. You agree not to:
• Post content that is defamatory, obscene, hateful, harassing, threatening, or otherwise objectionable.
• Impersonate any person or entity, or falsely state or misrepresent your affiliation with a person or entity.
• Post any content that infringes or violates the intellectual property rights of others.
4.2 Reporting Violations
If you observe content or user behavior that violates these Terms, please notify us at [Contact Email or Support Portal]. Ragtag reserves the right to remove or modify any content that violates our policies or is otherwise objectionable.

5. User-Generated Content
5.1 Ownership of Your Content
You retain all intellectual property rights in any content you create and share on the App (“User Content”). By posting or sharing User Content, you represent that you own or have the necessary permissions to share such content.
5.2 License to Ragtag
By submitting or posting User Content, you grant Ragtag a non-exclusive, worldwide, royalty-free, transferable license to use, store, display, reproduce, distribute, modify, and create derivative works of your User Content for the purpose of operating, developing, providing, and improving the App.
5.3 Content Removal
Ragtag reserves the right, but is not obligated, to remove any User Content that, at our sole discretion, violates these Terms or is otherwise objectionable.

6. Intellectual Property Rights
6.1 Ragtag Ownership
All content, features, functionality, trademarks, service marks, and trade names (including but not limited to “Ragtag,” “Campus Commons,” “Class Sync,” and “FOMO Feed”) are owned by Ragtag Social LLC or its licensors, and are protected by copyright, trademark, patent, trade secret, or other intellectual property laws.
6.2 No Implied Rights
Except for the limited license granted herein, nothing in this Agreement transfers any ownership or license of our intellectual property to you.

7. Privacy and Data Collection
Our [Privacy Policy] explains how we collect, use, and share information about you when you use our App. By using the App, you consent to the collection and use of your data as outlined in that policy.

8. Paid Features or Subscriptions (If Applicable)
8.1 Subscription Fees
Ragtag may offer certain premium features or subscriptions for a fee. The pricing and payment terms will be described at the point of purchase.
8.2 Free Trials
If we offer free trials, you may be required to cancel before the trial ends to avoid being charged.
8.3 Refunds
Refund requests will be evaluated on a case-by-case basis according to applicable consumer protection laws and our internal policy.

9. Third-Party Services and Links
9.1 Third-Party Content
The App may contain links to third-party websites or services that are not under our control. We are not responsible for the content, privacy policies, or practices of any third-party services.
9.2 No Endorsement
Any reference to third-party products, services, or websites is not an endorsement or recommendation by Ragtag.

10. Disclaimer of Warranties
10.1 “AS IS” and “AS AVAILABLE”
Your use of the App is at your sole risk. The App is provided on an “AS IS” and “AS AVAILABLE” basis without warranties of any kind, whether express or implied, including but not limited to the implied warranties of merchantability, fitness for a particular purpose, or non-infringement.
10.2 No Guarantee
We do not guarantee that the App will be secure, uninterrupted, error-free, or free of viruses or other harmful components. We do not guarantee any specific results from using the App.

11. Limitation of Liability
11.1 No Indirect Damages
To the maximum extent permitted by law, Ragtag Social LLC and its affiliates, officers, employees, agents, or partners shall not be liable to you for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, or goodwill.
11.2 Cap on Liability
In no event shall Ragtag’s total liability for all claims arising out of or related to these Terms exceed the amount paid by you (if any) for accessing or using the App in the twelve (12) months preceding the event giving rise to liability.

12. Indemnification
You agree to defend, indemnify, and hold harmless Ragtag Social LLC, its affiliates, and their respective officers, directors, employees, and agents from and against any claims, damages, obligations, losses, liabilities, costs, or debt, and expenses (including but not limited to attorney’s fees) arising from:
• Your use or misuse of the App.
• Your violation of any term of this Agreement.
• Your violation of any third-party right, including without limitation any intellectual property or privacy right.
• Another’s misuse/violation of the App

13. Term and Termination
13.1 Termination by User
You may terminate your account and stop using the App at any time.
13.2 Termination by Ragtag
We may suspend or terminate your access to the App if we believe you have violated these Terms or for any other reason at our sole discretion, with or without notice.
13.3 Effect of Termination
Upon termination, all rights granted to you under this Agreement shall cease. Sections regarding intellectual property, disclaimers, liability limitations, and indemnification shall survive termination.

14. Governing Law and Dispute Resolution
14.1 Governing Law
This Agreement shall be governed by and construed in accordance with the laws of the [State/Country], without regard to its conflict of law principles.
14.2 Arbitration
Any dispute, claim, or controversy arising out of or relating to this Agreement or the breach thereof shall be settled by binding arbitration in a decided jurisdiction, in accordance with the rules of the American Arbitration Association. Judgment on the award rendered by the arbitrator may be entered in any court having jurisdiction thereof.
14.3 Venue and Jurisdiction
If arbitration is not mandated, you agree to submit to the personal jurisdiction of the state and federal courts located in Raleigh, North Carolina, and you agree to waive any objections to the exercise of jurisdiction over you by such courts.

15. Changes to These Terms
We reserve the right, at our sole discretion, to modify or replace these Terms at any time. We will make reasonable efforts to notify you of material changes, such as by posting the updated Agreement within the App or sending a notification. Your continued use of the App after any such changes constitutes your acceptance of the new Terms.

16. General Provisions
16.1 Entire Agreement
This Agreement, together with the Privacy Policy, constitutes the entire agreement between you and Ragtag and supersedes any prior agreements or understandings.
16.2 Severability
If any provision of this Agreement is found to be invalid, illegal, or unenforceable, the remaining provisions shall remain in full force and effect.
16.3 No Waiver
No waiver of any term or condition herein shall be deemed a further or continuing waiver of such term or any other term, and Ragtag’s failure to assert any right or provision under these Terms shall not constitute a waiver.
16.4 Assignment
You may not assign or transfer your rights or obligations under these Terms without our prior written consent. We may freely assign our rights and obligations under these Terms.
16.5 Electronic Communications
You consent to receive communications electronically from us, and you agree that any notices, agreements, disclosures, or other communications we provide electronically satisfy any legal requirements for written communication.

17. Contact Information
If you have any questions or concerns about this Agreement, please contact us at:
Ragtag Social LLC
Attn: Nicholas Cooke (Founder & CEO)
reachragtag@gmail.com
""";

  @override
  void initState() {
    super.initState();
    _initSettingsFromFirestore();
  }

  /// Fetch initial privacy & permission settings from Firestore
  Future<void> _initSettingsFromFirestore() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    final docSnapshot =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!docSnapshot.exists) return;

    final data = docSnapshot.data() ?? {};

    // Check 'privacy'
    final privacyValue = data['privacy'];
    if (privacyValue == 'quiet') {
      _isBlockingStrangerMessages = true;
    }

    // Check device permissions: stored in "permissions" sub-map
    // If not found, default to `true`
    final permissionsMap = data['permissions'] as Map<String, dynamic>? ?? {};
    _cameraEnabled = permissionsMap['camera'] ?? true;
    _contactsEnabled = permissionsMap['contacts'] ?? true;
    _notificationsEnabled = permissionsMap['notifications'] ?? true;
    _photosEnabled = permissionsMap['photos'] ?? true;

    setState(() {});
  }

  /// Save changes (privacy + permissions) to Firestore
  Future<void> _saveAllSettings() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    // Build the 'permissions' sub-map
    final newPermissions = {
      'camera': _cameraEnabled,
      'contacts': _contactsEnabled,
      'notifications': _notificationsEnabled,
      'photos': _photosEnabled,
    };

    // If quiet mode is ON => 'privacy': 'quiet'
    // If OFF => remove 'privacy'
    if (_isBlockingStrangerMessages) {
      await docRef.update({
        'privacy': 'quiet',
        'permissions': newPermissions,
      });
    } else {
      await docRef.update({
        'privacy': FieldValue.delete(),
        'permissions': newPermissions,
      });
    }

    // Show a quick confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Settings saved!"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // The background color transitions between black/white,
    // matching the style from your admin page
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,

        // Floating button to toggle dark mode (top-right)
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: Padding(
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
              onPressed: () => setState(() => isDarkMode = !isDarkMode),
            ),
          ),
        ),

        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              const SizedBox(height: 8),
              _buildHeader(),
              const SizedBox(height: 4),
              _buildSubHeader(),
              const SizedBox(height: 16),

              // Main content scroll
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      // Quiet mode card
                      _buildQuietModeCard(),
                      const SizedBox(height: 16),

                      // Device permissions card
                      _buildDevicePermissionsCard(),
                      const SizedBox(height: 16),

                      // Collapsible Legal Sections
                      _buildLegalSectionCard(),

                      // Save button
                      const SizedBox(height: 16),
                      _buildSaveButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ///
  /// Top bar with a back arrow
  ///
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
      ],
    );
  }

  ///
  /// Page header & subheader
  ///
  Widget _buildHeader() {
    return Text(
      "Privacy & Permissions",
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 24,
        color: isDarkMode ? Colors.white : Colors.black,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSubHeader() {
    return Text(
      "Adjust your quiet mode & device preferences",
      style: TextStyle(
        color: isDarkMode ? Colors.white70 : Colors.black54,
        fontSize: 14,
      ),
      textAlign: TextAlign.center,
    );
  }

  ///
  /// Card to toggle "Block Stranger Messages" (quiet mode)
  ///
  Widget _buildQuietModeCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle("Quiet Mode"),
          const Divider(thickness: 1.2),
          ListTile(
            leading: Icon(
              _isBlockingStrangerMessages
                  ? Icons.lock_outlined
                  : Icons.lock_open_outlined,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            title: Text(
              "Block Stranger Messages",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              "People will not be able to invite you to chat.",
              style: TextStyle(
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
            trailing: Switch(
              value: _isBlockingStrangerMessages,
              onChanged: (val) {
                setState(() => _isBlockingStrangerMessages = val);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  ///
  /// Card with toggles for device permissions
  ///
  Widget _buildDevicePermissionsCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle("Device Permissions"),
          const Divider(thickness: 1.2),

          // Camera
          _buildPermissionTile(
            icon: Icons.camera_alt_outlined,
            label: "Camera",
            value: _cameraEnabled,
            onChanged: (val) => setState(() => _cameraEnabled = val),
          ),

          // Contacts
          _buildPermissionTile(
            icon: Icons.contacts_outlined,
            label: "Contacts",
            value: _contactsEnabled,
            onChanged: (val) => setState(() => _contactsEnabled = val),
          ),

          // Notifications
          _buildPermissionTile(
            icon: Icons.notifications_none_outlined,
            label: "Notifications",
            value: _notificationsEnabled,
            onChanged: (val) => setState(() => _notificationsEnabled = val),
          ),

          // Photos
          _buildPermissionTile(
            icon: Icons.photo_outlined,
            label: "Photos",
            value: _photosEnabled,
            onChanged: (val) => setState(() => _photosEnabled = val),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  ///
  /// Card containing two ExpansionTiles for legal text
  ///
  Widget _buildLegalSectionCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardTitle("Legal"),
          const Divider(thickness: 1.2),
          ExpansionTile(
            title: Text(
              "User Agreement",
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            iconColor: isDarkMode ? Colors.white70 : Colors.black54,
            collapsedIconColor: isDarkMode ? Colors.white70 : Colors.black54,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _userAgreementText,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
          const Divider(thickness: 1.2),
          ExpansionTile(
            title: Text(
              "Copyright Notice",
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            iconColor: isDarkMode ? Colors.white70 : Colors.black54,
            collapsedIconColor: isDarkMode ? Colors.white70 : Colors.black54,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  _copyrightText,
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ],
      ),
    );
  }

  ///
  /// Build a SwitchListTile for each device permission
  ///
  Widget _buildPermissionTile({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      activeColor: Colors.greenAccent,
      contentPadding: const EdgeInsets.only(left: 16, right: 16),
      secondary: Icon(
        icon,
        color: isDarkMode ? Colors.white70 : Colors.black54,
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      ),
      value: value,
      onChanged: onChanged,
    );
  }

  ///
  /// The "Save" button in the center that updates Firestore
  ///
  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.greenAccent,
        foregroundColor: Colors.white, // <-- text & icon color
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: _saveAllSettings,
      icon: const Icon(Icons.check, color: Colors.white),
      label: const Text(
        "SAVE",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  ///
  /// Shared card decoration
  ///
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: isDarkMode
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isDarkMode
            ? Colors.white.withOpacity(0.1)
            : Colors.black.withOpacity(0.1),
        width: 1,
      ),
    );
  }

  ///
  /// Title widget in each card
  ///
  Widget _buildCardTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 18,
          color: isDarkMode ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
