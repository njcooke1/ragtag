import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart'; // For Ticker
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:email_validator/email_validator.dart';
import 'package:shimmer/shimmer.dart';
import '../services/token_service.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({Key? key}) : super(key: key);

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _retypePasswordController =
      TextEditingController();

  String? _selectedInstitution;
  bool _obscurePassword = true;
  bool _obscureRetypePassword = true;
  bool _isLoading = false;

  // Controls whether we are currently waiting for email verification
  bool _awaitingVerification = false;
  Timer? _verificationCheckTimer;

  final TokenService _tokenService = TokenService();

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _retypePasswordController.dispose();
    _verificationCheckTimer?.cancel();
    super.dispose();
  }

  /// Periodically checks whether the user has verified their email.
  void _startVerificationCheck() {
    _verificationCheckTimer?.cancel();
    _verificationCheckTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload(); // refresh user data
      if (user != null && user.emailVerified) {
        timer.cancel();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pushReplacementNamed(context, '/likes-dislikes');
      }
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Create the user
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      User? user = userCredential.user;
      if (user == null) throw Exception('User registration failed.');

      // Update display name in FirebaseAuth
      await user.updateDisplayName(
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
      );

      // Save user info in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName':
            '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}',
        'email': _emailController.text.trim(),
        'institution': _selectedInstitution,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Temporarily comment out token initialization for troubleshooting:
      // await _tokenService.initializeToken();

      // Send verification email
      await user.sendEmailVerification();

      // Show success message
      _showSnackBar(
        message: 'Registration successful! Check your .edu email to verify.',
        backgroundColor: Colors.green,
      );

      setState(() => _awaitingVerification = true);
      _startVerificationCheck();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(message: e.message ?? 'An error occurred.');
    } catch (e) {
      _showSnackBar(message: 'An unknown error occurred.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar({required String message, Color? backgroundColor}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? Colors.redAccent,
      ),
    );
  }

  /// Reusable text form field
  Widget _buildTextFormField({
    required String label,
    required TextEditingController controller,
    required String? Function(String?)? validator,
    bool obscureText = false,
    VoidCallback? toggleVisibility,
    bool autoFocus = false,
    TextInputAction textInputAction = TextInputAction.next,
    String? hintText,
    Function()? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            style: const TextStyle(color: Colors.white),
            autofocus: autoFocus,
            textInputAction: textInputAction,
            onFieldSubmitted: (_) {
              if (onFieldSubmitted != null) onFieldSubmitted();
            },
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.white54),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: toggleVisibility != null
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white70,
                      ),
                      onPressed: toggleVisibility,
                    )
                  : null,
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Institution",
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.black87,
              popupMenuTheme: PopupMenuThemeData(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                borderRadius: BorderRadius.circular(12),
                value: _selectedInstitution,
                dropdownColor: Colors.black87,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                style: const TextStyle(color: Colors.white),
                hint: const Text(
                  'Select Institution',
                  style: TextStyle(color: Colors.white54),
                ),
                onChanged: (String? newValue) {
                  setState(() => _selectedInstitution = newValue);
                },
                items: const [
                  DropdownMenuItem(
                    value: 'North Carolina State University',
                    child: Text(
                      'North Carolina State University',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'University of North Carolina at Chapel Hill',
                    child: Text(
                      'University of North Carolina Chapel Hill',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'University of North Carolina Greensboro',
                    child: Text(
                      'University of North Carolina Greensboro',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Register button
  Widget _buildRegisterButton() {
    return SizedBox(
      height: 50,
      width: double.infinity,
      child: Hero(
        tag: 'registerButton',
        child: ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
            padding: EdgeInsets.zero,
            foregroundColor: Colors.white,
          ),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFAF7B), Color(0xFFD76D77)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Container(
              alignment: Alignment.center,
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : const Text(
                      "Register",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------
  // UPDATED WAIT SCREEN USING THE BOUNCING LOGO
  // ------------------------------------------------
  /// Minimal waiting-for-verification screen
  Widget _buildVerificationWaitView() {
    return Container(
      color: Colors.black87,
      child: Stack(
        children: [
          // Bouncing ragtag logo behind everything
          const Positioned.fill(
            child: BouncingLogoWidget(),
          ),
          // Centered text + loading indicator
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "We sent a verification link to your campus email.\n\n"
                    "Verify to continue!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lovelo', // Lovelo font
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 20),
                  CircularProgressIndicator(color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Shimmer background + Registration form
  Widget _buildRegistrationFormView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // First Shimmer
        Positioned.fill(
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFD76D77).withOpacity(0.8),
            highlightColor: const Color(0xFFFFAF7B).withOpacity(0.9),
            period: const Duration(seconds: 9),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFAF7B),
                    Color(0xFFD76D77),
                    Color(0xFF1C6971),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
        ),
        // Second Shimmer
        Positioned.fill(
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFD76D77).withOpacity(0.5),
            highlightColor: const Color(0xFFFFAF7B).withOpacity(0.6),
            period: const Duration(seconds: 4),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFAF7B),
                    Color(0xFFD76D77),
                    Color(0xFF1C6971),
                  ],
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                ),
              ),
            ),
          ),
        ),

        // Blur effect over shimmer
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.1),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_left,
                          color: Colors.white70,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Title
                  const Text(
                    "Create Your Account",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Join our community and explore what's ahead.",
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Registration form container
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // First & Last Name
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextFormField(
                                  label: 'First Name',
                                  controller: _firstNameController,
                                  autoFocus: true,
                                  hintText: 'Your first name',
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'First name cannot be empty';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildTextFormField(
                                  label: 'Last Name',
                                  controller: _lastNameController,
                                  hintText: 'Your last name',
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Last name cannot be empty';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Email
                          _buildTextFormField(
                            label: 'Email',
                            controller: _emailController,
                            hintText: 'Your .edu email address',
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter an email';
                              }
                              final trimmedVal = value.trim().toLowerCase();
                              if (!EmailValidator.validate(trimmedVal)) {
                                return 'Please enter a valid email';
                              }
                              if (!trimmedVal.endsWith('.edu')) {
                                return 'Please provide a .edu email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password
                          _buildTextFormField(
                            label: 'Set Password',
                            controller: _passwordController,
                            hintText: 'At least 8 characters',
                            obscureText: _obscurePassword,
                            toggleVisibility: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a password';
                              } else if (value.trim().length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Confirm Password
                          _buildTextFormField(
                            label: 'Confirm Password',
                            controller: _retypePasswordController,
                            hintText: 'Re-enter password',
                            obscureText: _obscureRetypePassword,
                            toggleVisibility: () {
                              setState(() {
                                _obscureRetypePassword =
                                    !_obscureRetypePassword;
                              });
                            },
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please re-enter your password';
                              } else if (value.trim() !=
                                  _passwordController.text.trim()) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Institution dropdown
                          _buildDropdownField(),
                          const SizedBox(height: 30),

                          // Register button
                          _buildRegisterButton(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_awaitingVerification) {
      // If user has submitted and we are waiting for them to verify:
      return Scaffold(
        body: _buildVerificationWaitView(),
      );
    }

    // Otherwise, show the registration form
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: _buildRegistrationFormView(),
    );
  }
}

// --------------------------------------------------------------------
// BOUNCING LOGO WIDGET - SLOW, MULTI-ANGLE BOUNCE, RAINBOW COLOR FILTER
// --------------------------------------------------------------------
class BouncingLogoWidget extends StatefulWidget {
  const BouncingLogoWidget({Key? key}) : super(key: key);

  @override
  State<BouncingLogoWidget> createState() => _BouncingLogoWidgetState();
}

class _BouncingLogoWidgetState extends State<BouncingLogoWidget>
    with TickerProviderStateMixin {
  // Positions and velocities for manual bouncing
  double _xPos = 0;
  double _yPos = 0;
  double _xVel = 0.7; // Adjust for slower horizontal movement
  double _yVel = 1.0; // Adjust for slower vertical movement

  // Ragtag logo size
  final double _logoWidth = 80;
  final double _logoHeight = 80;

  // Ticker for updating position
  Ticker? _ticker;

  // Color animation
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // 1) Multiple color transitions (rainbow effect)
    _colorController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // Build a chain of color transitions
    _colorAnimation = TweenSequence<Color?>([
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.red, end: Colors.orange),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.orange, end: Colors.yellow),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.yellow, end: Colors.green),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.green, end: Colors.blue),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.blue, end: Colors.indigo),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: ColorTween(begin: Colors.indigo, end: Colors.purple),
        weight: 1,
      ),
      // Add more if you want an even longer sequence...
    ]).animate(_colorController);

    // 2) Ticker for bouncing
    _ticker = createTicker((_) {
      setState(() {
        _xPos += _xVel;
        _yPos += _yVel;

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        // Bounce horizontally
        if (_xPos < 0) {
          _xPos = 0;
          _xVel = -_xVel;
        } else if (_xPos + _logoWidth > screenWidth) {
          _xPos = screenWidth - _logoWidth;
          _xVel = -_xVel;
        }

        // Bounce vertically
        if (_yPos < 0) {
          _yPos = 0;
          _yVel = -_yVel;
        } else if (_yPos + _logoHeight > screenHeight) {
          _yPos = screenHeight - _logoHeight;
          _yVel = -_yVel;
        }
      });
    });
    _ticker?.start();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _colorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Animate color changes with an AnimatedBuilder
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        // Move the logo to the current position
        return Positioned(
          left: _xPos,
          top: _yPos,
          child: SizedBox(
            width: _logoWidth,
            height: _logoHeight,
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                _colorAnimation.value ?? Colors.white,
                BlendMode.srcATop,
              ),
              child: Image.asset(
                'assets/ragtaglogo.png', // Make sure path is correct
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      },
    );
  }
}
