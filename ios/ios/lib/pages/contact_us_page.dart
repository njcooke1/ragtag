import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Mailer imports:
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class ContactUsPage extends StatefulWidget {
  const ContactUsPage({Key? key}) : super(key: key);

  @override
  State<ContactUsPage> createState() => _ContactUsPageState();
}

class _ContactUsPageState extends State<ContactUsPage>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isSubmitting = false;
  bool _isDarkMode = true;

  /// We'll store the photoUrl for the user whose email = 'nicholasjcooke03@gmail.com'
  String? _nicholasPhotoUrl;

  /// Animation controller + tween to animate a "shimmer" across our gradient outline
  late final AnimationController _shimmerController;
  late final Animation<double> _shimmerAnimation;

  /// Top icon expansion state (Support email)
  bool _showSupportEmail = false;

  /// Bottom icon expansion state (Personal/Business email)
  bool _showPersonalEmail = false;

  /// Tracks if the user has typed anything into the "Your Message" field
  bool _showSendButton = false;

  @override
  void initState() {
    super.initState();
    _fetchNicholasPhotoUrl();

    // Setup shimmer animation
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(); // loop forever

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // Listen for typing in the "Your Message" field
    _messageController.addListener(() {
      setState(() {
        _showSendButton = _messageController.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();

    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  /// Fetch the photoUrl from Firestore for user with email = 'nicholasjcooke03@gmail.com'
  Future<void> _fetchNicholasPhotoUrl() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: 'nicholasjcooke03@gmail.com')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userData = query.docs.first.data();
        if (userData.containsKey('photoUrl') && userData['photoUrl'] is String) {
          _nicholasPhotoUrl = userData['photoUrl'] as String;
        } else {
          _nicholasPhotoUrl = 'No "photoUrl" field in this user doc.';
        }
      } else {
        _nicholasPhotoUrl = 'No user found with that email.';
      }
    } catch (e) {
      _nicholasPhotoUrl = 'Error fetching photoUrl: $e';
    }

    if (mounted) setState(() {});
  }

  /// Sends an actual email to "reachragtag@gmail.com" using Gmail SMTP credentials
  Future<void> _sendEmailDirect({
    required String name,
    required String email,
    required String subject,
    required String message,
  }) async {
    // Replace these with valid Gmail credentials/App Password:
    final String username = 'reachragtag@gmail.com';
    final String password = 'wvzi wojs gjln wvry'; // Must enable 2FA

    final smtpServer = gmail(username, password);

    final mail = Message()
      ..from = Address(username, 'My Flutter App')
      ..recipients.add('reachragtag@gmail.com') // The address to send to
      ..subject = 'Contact Form: $subject'
      ..text = 'Name: $name\n'
          'Email: $email\n'
          'Subject: $subject\n\n'
          '$message';

    try {
      final sendReport = await send(mail, smtpServer);
      debugPrint('Email sent: $sendReport');
    } on MailerException catch (e) {
      debugPrint('Error sending email: $e');
      rethrow; // so we can show error in the UI
    }
  }

  /// Submits the contact form to Firestore & triggers an email
  Future<void> _submitContactForm() async {
    if (_nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill out all fields.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Write to Firestore
      final user = FirebaseAuth.instance.currentUser;
      final userId = user?.uid ?? 'anonymous';

      await FirebaseFirestore.instance.collection('contactFormSubmissions').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'subject': _subjectController.text.trim(),
        'message': _messageController.text.trim(),
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Send an actual email
      await _sendEmailDirect(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        subject: _subjectController.text.trim(),
        message: _messageController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thank you! We'll get back soon.")),
      );

      // Clear fields
      _nameController.clear();
      _emailController.clear();
      _subjectController.clear();
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error sending message: $e")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: _isDarkMode ? Colors.black : Colors.white,
      child: Scaffold(
        backgroundColor: Colors.transparent,

        /// Toggle dark mode
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
        floatingActionButton: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Container(
            decoration: BoxDecoration(
              /// Make the toggle's container transparent
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: IconButton(
              icon: Icon(
                _isDarkMode ? Icons.nights_stay : Icons.wb_sunny,
                color: _isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () => setState(() => _isDarkMode = !_isDarkMode),
            ),
          ),
        ),

        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ///
                /// Top bar/back button
                ///
                Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isDarkMode
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.1),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new,
                          size: 18,
                          color: _isDarkMode ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    "Contact Us",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: _isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    "We'd love to hear from you",
                    style: TextStyle(
                      fontSize: 14,
                      color: _isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                ///
                /// Top-right reveal icon for Support Email
                ///
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(), // push everything to the far right
                    SizedBox(
                      height: 28,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          // The sliding text container
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            width: _showSupportEmail ? 300 : 0,
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "reachragtag@gmail.com (Ideas & Issues)",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _isDarkMode
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                              ),
                            ),
                          ),
                          // The icon itself, now color changes with dark mode
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _showSupportEmail = !_showSupportEmail;
                              });
                            },
                            child: Icon(
                              Icons.email_outlined,
                              color: _isDarkMode ? Colors.white : Colors.black,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                ///
                /// Name
                ///
                _buildInputCard(
                  child: _buildTextField(
                    controller: _nameController,
                    hint: "Your Name",
                    icon: Icons.person_outline,
                  ),
                ),
                const SizedBox(height: 16),

                ///
                /// Email
                ///
                _buildInputCard(
                  child: _buildTextField(
                    controller: _emailController,
                    hint: "Your Email",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                const SizedBox(height: 16),

                ///
                /// Subject
                ///
                _buildInputCard(
                  child: _buildTextField(
                    controller: _subjectController,
                    hint: "Subject",
                    icon: Icons.subject_outlined,
                  ),
                ),
                const SizedBox(height: 16),

                ///
                /// Message
                ///
                _buildInputCard(
                  child: _buildMultilineField(
                    controller: _messageController,
                    hint: "Your Message",
                    icon: Icons.message_outlined,
                  ),
                ),

                ///
                /// Shimmering "Send" button, only appears after user typed message
                ///
                const SizedBox(height: 20),
                if (_showSendButton)
                  _buildShimmeringGradientOutline(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _isSubmitting ? null : _submitContactForm,
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              "Send",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                const SizedBox(height: 40),

                ///
                /// Nicholas photo section
                ///
                Center(child: _buildNicholasPhotoSection()),
                const SizedBox(height: 24),

                ///
                /// Minimalist icon for personal email
                /// Now the text appears ABOVE the icon
                ///
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Show the text above the icon
                      AnimatedCrossFade(
                        crossFadeState: _showPersonalEmail
                            ? CrossFadeState.showFirst
                            : CrossFadeState.showSecond,
                        duration: const Duration(milliseconds: 250),
                        firstChild: Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            "nicholasjcooke03@gmail.com\n(For Business Inquiries)",
                            style: TextStyle(
                              fontSize: 13,
                              color: _isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        secondChild: const SizedBox.shrink(),
                      ),
                      // The icon, now color changes with dark mode
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showPersonalEmail = !_showPersonalEmail;
                          });
                        },
                        child: Icon(
                          Icons.email_outlined,
                          color: _isDarkMode ? Colors.white : Colors.black,
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  ///
  /// Container for text fields
  ///
  Widget _buildInputCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _isDarkMode
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isDarkMode
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  ///
  /// Single-line text field
  ///
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        prefixIcon: Icon(
          icon,
          color: _isDarkMode ? Colors.white70 : Colors.black54,
        ),
        hintText: hint,
        hintStyle:
            TextStyle(color: _isDarkMode ? Colors.white54 : Colors.black45),
        fillColor: Colors.transparent,
        filled: true,
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  ///
  /// Multi-line text field
  ///
  Widget _buildMultilineField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 6,
      style: TextStyle(color: _isDarkMode ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        prefixIcon: Padding(
          padding: const EdgeInsets.only(top: 0, bottom: 50),
          child: Icon(
            icon,
            color: _isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        hintText: hint,
        hintStyle:
            TextStyle(color: _isDarkMode ? Colors.white54 : Colors.black45),
        fillColor: Colors.transparent,
        filled: true,
        border: InputBorder.none,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  ///
  /// Display Nicholas's photo from Firestore & a short paragraph
  ///
  Widget _buildNicholasPhotoSection() {
    if (_nicholasPhotoUrl == null) {
      // Still loading from Firestore
      return Text(
        "Loading user photo...",
        style: TextStyle(
          color: _isDarkMode ? Colors.white60 : Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final isValidUrl = _nicholasPhotoUrl!.startsWith('http://') ||
        _nicholasPhotoUrl!.startsWith('https://');

    if (isValidUrl) {
      return Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(_nicholasPhotoUrl!),
          ),
          const SizedBox(height: 12),
          Text(
            "Nicholas J. Cooke",
            style: TextStyle(
              color: _isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          // CEO & Founder directly under the name
          Text(
            "CEO & Founder",
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "I believe in creating an open, inclusive space where people\n"
            "can innovate, share ideas, and build something truly amazing\n"
            "together. I'd love to hear your thoughts and suggestions\n"
            "as we shape the future of this platform.\n",
            style: TextStyle(
              color: _isDarkMode ? Colors.white70 : Colors.black87,
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      return Text(
        _nicholasPhotoUrl!,
        style: TextStyle(
          color: _isDarkMode ? Colors.white70 : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      );
    }
  }

  ///
  /// Draws a shimmering gradient border around [child]
  ///
  Widget _buildShimmeringGradientOutline({required Widget child}) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
          ),
          child: CustomPaint(
            painter: _ShimmerBorderPainter(
              animationValue: _shimmerAnimation.value,
            ),
            child: Container(
              margin: const EdgeInsets.all(3), // border thickness
              decoration: BoxDecoration(
                color: Colors.black, // Fill behind the child
                borderRadius: BorderRadius.circular(24),
              ),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

///
/// Custom painter for the shimmering gradient border
///
class _ShimmerBorderPainter extends CustomPainter {
  final double animationValue;

  _ShimmerBorderPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final double shimmerShift = size.width * animationValue;

    final gradient = const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [Color(0xFFFFAF7B), Color(0xFFD76D77), Color(0xFFFFAF7B)],
      stops: [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect.shift(Offset(shimmerShift, 0)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_ShimmerBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
