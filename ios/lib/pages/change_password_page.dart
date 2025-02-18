import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({Key? key}) : super(key: key);

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  bool isDarkMode = true;    // Dark/Light mode toggle
  bool _isLoading = false;   // For showing a loading overlay
  final _emailController = TextEditingController();

  /// Send the password reset email via Firebase
  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your email.")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password link reset sent! Check your email.")),
      );
      Navigator.of(context).pop(); 
    } catch (e) {
      debugPrint("Trouble sending reset email: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Top bar with a back arrow & dark mode toggle
  Widget _buildTopBar() {
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
            onPressed: () {
              setState(() => isDarkMode = !isDarkMode);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: isDarkMode ? Colors.black : Colors.white,
      child: Scaffold(
        // Make the scaffold background transparent so our container color shows
        backgroundColor: Colors.transparent,

        body: SafeArea(
          child: Stack(
            children: [
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),

              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top bar
                    _buildTopBar(),
                    const SizedBox(height: 16),

                    // Title
                    Center(
                      child: Text(
                        "Change Password",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        "We’ll send you a password reset link via email",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // The email field
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.06)
                            : Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            style: TextStyle(
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                            decoration: InputDecoration(
                              labelText: "Email Address",
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
                                  color: isDarkMode
                                      ? Colors.white10
                                      : Colors.black12,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              hintText: "Enter your email",
                              hintStyle: TextStyle(
                                color: isDarkMode ? Colors.white54 : Colors.black54,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.greenAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            onPressed: _sendResetEmail,
                            icon: const Icon(Icons.send, color: Colors.white),
                            label: const Text(
                              "Send Reset Link",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
