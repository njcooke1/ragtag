import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'first_choice.dart';
import '../services/token_service.dart';
import 'change_password_page.dart';

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
  bool _obscurePassword = true;

  // Error message to display in the UI
  String? _errorMessage;

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
    setState(() {
      _isLoading = true;
      _errorMessage = null; // clear any previous error
    });

    final String email = _usernameController.text.trim();
    final String password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password.';
        _isLoading = false;
      });
      return;
    }

    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      print("Sign-in successful: ${userCredential.user?.email}");

      // Get the Firebase auth token and save it using shared_preferences
      String? token = await userCredential.user?.getIdToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('authToken', token);
        print("Token saved in shared preferences: $token");
      }

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
                  position: Tween(begin: Offset.zero, end: const Offset(0.0, -1.0))
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
      setState(() {
        _errorMessage = e.message ?? 'Sign-in failed. Please try again.';
      });
    } catch (e, stacktrace) {
      print("Unknown error: $e");
      print("Stacktrace: $stacktrace");
      setState(() {
        _errorMessage = 'An unknown error occurred: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ensures the scaffold resizes when the keyboard appears
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
          // 2) App logo remains at the top center
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
          // 3) Main form: centered content without keyboard movement
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                bottom: 40.0,
                left: 20.0,
                right: 20.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Error banner (only shows if _errorMessage is not null)
                      if (_errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(10.0),
                          margin: const EdgeInsets.only(bottom: 20),
                          color: Colors.redAccent,
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.white),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white),
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      // Sign-in prompt text
                      const Text(
                        "Sign in using your campus email",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                      const SizedBox(height: 30),
                      // Email TextField
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
                      // Password field (only shows if a username is entered)
                      if (_isUsernameEntered)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Password',
                                style: TextStyle(color: Colors.white)),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
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
                      // Continue button
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
                              ? const CircularProgressIndicator(
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                )
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
          ),
          // 4) Transparent back button at the top remains unchanged
          Positioned(
            top: 40,
            left: 20,
            child: SafeArea(
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
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
