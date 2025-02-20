import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart'; // <-- Important

import 'first_choice.dart';
import '../services/token_service.dart'; // Corrected import path
import 'change_password_page.dart'; // <-- Make sure this import is correct

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isUsernameEntered = false;

  /// Added a password visibility toggle
  bool _obscurePassword = true;

  final TokenService _tokenService = TokenService();

  @override
  void initState() {
    super.initState();
    _usernameController.addListener(() {
      setState(() {
        _isUsernameEntered = _usernameController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signIn() async {
    setState(() => _isLoading = true);

    final String email = _usernameController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter both email and password.');
      setState(() => _isLoading = false);
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      print("Sign-in successful: ${userCredential.user?.email}");
      await _tokenService.initializeToken();

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) {
            return const FirstChoicePage();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;

            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final slideAnimation = animation.drive(tween);

            return Stack(
              children: [
                SlideTransition(position: slideAnimation, child: child),
                SlideTransition(
                  position:
                      Tween(begin: Offset.zero, end: const Offset(0.0, -1.0))
                          .animate(animation),
                  child: Container(color: Colors.transparent),
                ),
              ],
            );
          },
        ),
      );
    } on FirebaseAuthException catch (e) {
      print("FirebaseAuthException: ${e.message}");
      _showSnackBar(e.message ?? 'Sign-in failed. Please try again.');
    } catch (e) {
      print("Unknown error: $e");
      _showSnackBar('An unknown error occurred.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ensure the scaffold resizes to avoid bottom inset
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // -- FIRST SHIMMER --
          Positioned.fill(
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFD76D77).withOpacity(0.8),
              highlightColor: const Color(0xFFFFAF7B).withOpacity(0.9),
              period: const Duration(seconds: 4),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFAF7B),
                      Color(0xFFD76D77),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // -- SECOND SHIMMER (slightly delayed / offset) --
          Positioned.fill(
            child: Shimmer.fromColors(
              baseColor: const Color(0xFFD76D77).withOpacity(0.6),
              highlightColor: const Color(0xFFFFAF7B).withOpacity(0.7),
              period: const Duration(seconds: 9),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFFAF7B),
                      Color(0xFFD76D77),
                      Color(0xFF1C6971),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
              ),
            ),
          ),

          // 2) Your app logo
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 98.0),
              child: Image.asset(
                'assets/ragtaglogo.png',
                width: 120,
                height: 70,
              ),
            ),
          ),

          // 3) Main Form wrapped in a scroll view to avoid bunching when the keyboard pops up
          Positioned.fill(
            child: SingleChildScrollView(
              // Use extra top padding so the form doesn't overlap the logo,
              // and bottom padding based on the keyboard's viewInsets
              padding: EdgeInsets.only(
                left: 20.0,
                right: 20.0,
                top: 200.0,
                bottom: MediaQuery.of(context).viewInsets.bottom + 40.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 200.0,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Sign in using your campus email",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                    const SizedBox(height: 30),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Enter Username (email)',
                        hintStyle: const TextStyle(color: Colors.white),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.2),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (_isUsernameEntered)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Password',
                              style: TextStyle(color: Colors.white)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword, // <-- toggled
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter Password',
                              hintStyle: const TextStyle(color: Colors.white),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.2),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              // <-- Icon toggle
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 30),
                    Container(
                      width: 250,
                      height: 55,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white,
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const BouncingBallsLoader()
                            : ShaderMask(
                                shaderCallback: (bounds) =>
                                    const LinearGradient(
                                  colors: [
                                    Color(0xFFFFAF7B),
                                    Color(0xFFD76D77),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ).createShader(bounds),
                                child: const Text(
                                  "Continue",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ChangePasswordPage(),
                          ),
                        );
                      },
                      child: const Text(
                        "Forgot your password?",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4) Modern transparent back button
          Positioned(
            bottom: 70,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_left, // no stem, just a chevron
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// BouncingBallsLoader Implementation
class BouncingBallsLoader extends StatelessWidget {
  const BouncingBallsLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Ball(index: index),
        );
      }),
    );
  }
}

class Ball extends StatefulWidget {
  final int index;
  const Ball({required this.index, super.key});

  @override
  State<Ball> createState() => _BallState();
}

class _BallState extends State<Ball> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    // Give each ball a slight delay so they bounce in a staggered fashion
    Future.delayed(Duration(milliseconds: widget.index * 200), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Transform.translate(
          offset: Offset(0, -10 * _controller.value),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFAF7B),
                  Color(0xFFD76D77),
                  Color(0xFF1C6971),
                ],
              ),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
