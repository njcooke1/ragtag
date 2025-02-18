import 'package:flutter/material.dart';
import 'dart:math' as math;

// Third-party packages
import 'package:shimmer/shimmer.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Firebase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Any other pages you need
import 'sign_in_page.dart';
import 'registration_page.dart';

/// ----------------------------------------
/// OPENING LANDING PAGE (Animations remain)
/// ----------------------------------------
class OpeningLandingPage extends StatefulWidget {
  const OpeningLandingPage({Key? key}) : super(key: key);

  @override
  State<OpeningLandingPage> createState() => _OpeningLandingPageState();
}

class _OpeningLandingPageState extends State<OpeningLandingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _rotationAnimation;

  late Animation<Color?> _bgColor1Animation;
  late Animation<Color?> _bgColor2Animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    // Fade in from 0 to 1
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    // Scale from 0.8 to 1.0
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // Shimmer sweeps across the logo
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeInOut),
      ),
    );

    // Rotating logo from -0.05 to 0.05 radians
    _rotationAnimation = Tween<double>(begin: -0.05, end: 0.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    // Animated gradient background
    _bgColor1Animation = ColorTween(
      begin: const Color(0xFF000000),
      end: const Color(0xFFFFAF7B),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );
    _bgColor2Animation = ColorTween(
      begin: const Color(0xFF000000),
      end: const Color(0xFFD76D77),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Start the animation
    _controller.forward();

    // Transition to LandingPage when animation completes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LandingPage()),
        );
      }
    });
  }

  /// Precache the background image so it’s already loaded when LandingPage appears.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/background.png'), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildShimmer(Widget child) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        final shimmerWidth = MediaQuery.of(context).size.width / 2;
        final start = _shimmerAnimation.value * MediaQuery.of(context).size.width;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.4),
                Colors.white.withOpacity(0.0),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ).createShader(
              Rect.fromLTWH(start, 0, shimmerWidth, bounds.height),
            );
          },
          blendMode: BlendMode.srcATop,
          child: child,
        );
      },
      child: child,
    );
  }

  Widget _buildGradientLogo() {
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Color(0xFFFFAF7B),
            Color(0xFFD76D77),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds);
      },
      child: Image.asset(
        'assets/ragtaglogo.png',
        width: 200,
        height: 200,
      ),
    );
  }

  /// Two faint shimmer overlays
  Widget _buildShimmerOverlays() {
    return Stack(
      children: [
        // First shimmer layer
        Positioned.fill(
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFD76D77).withOpacity(0.2),
            highlightColor: const Color(0xFFFFAF7B).withOpacity(0.3),
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
        // Second shimmer layer
        Positioned.fill(
          child: Shimmer.fromColors(
            baseColor: const Color(0xFFD76D77).withOpacity(0.1),
            highlightColor: const Color(0xFFFFAF7B).withOpacity(0.2),
            period: const Duration(seconds: 9),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFD76D77),
                    Color(0xFFFFAF7B),
                  ],
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _bgColor1Animation.value ?? Colors.black,
                      _bgColor2Animation.value ?? Colors.black,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          // Faint shimmer overlays
          _buildShimmerOverlays(),
          // Centered, rotating/fading/scaling logo
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: AnimatedBuilder(
                  animation: _rotationAnimation,
                  builder: (context, child) {
                    return Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: child,
                    );
                  },
                  child: _buildShimmer(_buildGradientLogo()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ----------------------------------------------
/// LANDING PAGE (Test Version)
/// ----------------------------------------------
class LandingPage extends StatelessWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Bright background color for easy visibility
      backgroundColor: Colors.green,
      body: Center(
        child: Text(
          'Landing Page!',
          style: TextStyle(
            fontSize: 32,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
