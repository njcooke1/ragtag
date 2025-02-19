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

    // Animated gradient background for the opening page
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

  /// Two faint shimmer overlays for a bit of extra polish
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
      // OpeningLandingPage remains unchanged.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Animated gradient background for the opening page
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
/// LANDING PAGE (Original UI, Fixed with Overlay)
/// ----------------------------------------------
class LandingPage extends StatefulWidget {
  const LandingPage({Key? key}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  // For the shimmer effect on the button text
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  // For the pop (scale) effect on buttons & banner
  late AnimationController _popController;
  late Animation<double> _popAnimation;

  // Subtle fade and slide for the entire column
  late AnimationController _landingTransitionController;
  late Animation<double> _landingFadeAnimation;
  late Animation<Offset> _landingSlideAnimation;

  // For background zoom effect
  late AnimationController _bgAnimationController;
  late Animation<double> _bgScaleAnimation;

  @override
  void initState() {
    super.initState();

    // SHIMMER
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // POP (SCALE)
    _popController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _popAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _popController, curve: Curves.easeOutBack),
    );

    // FADE + SLIDE
    _landingTransitionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..forward();
    _landingFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _landingTransitionController, curve: Curves.easeInOut),
    );
    _landingSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _landingTransitionController, curve: Curves.easeInOut),
    );

    // BACKGROUND ZOOM
    _bgAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
    _bgScaleAnimation = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _bgAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _popController.dispose();
    _landingTransitionController.dispose();
    _bgAnimationController.dispose();
    super.dispose();
  }

  /// Shimmer builder for button text
  Widget _buildButtonShimmer(Widget child) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        final width = MediaQuery.of(context).size.width;
        final shimmerWidth = width / 2;
        final start = _shimmerAnimation.value * width;
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                Colors.white.withOpacity(0.0),
                Colors.white.withOpacity(0.7),
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Animated background with slow zoom effect using the asset image
          AnimatedBuilder(
            animation: _bgScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _bgScaleAnimation.value,
                child: child,
              );
            },
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/background.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // Reintroduced overlay with a gradient (adjust opacity as desired)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.5),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Animated Column containing the logo and buttons
          FadeTransition(
            opacity: _landingFadeAnimation,
            child: SlideTransition(
              position: _landingSlideAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 12),
                  // Banner image/logo
                  ScaleTransition(
                    scale: _popAnimation,
                    child: Image.asset(
                      'assets/ragtaglogo.png',
                      width: size.width * 0.39,
                      height: size.height * 0.2,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // Sign In / Register buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ScaleTransition(
                      scale: _popAnimation,
                      child: Column(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/sign-in');
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              minimumSize: const Size(250, 55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: const Text(
                              "Sign In",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: 250,
                            height: 55,
                            child: _buildButtonShimmer(
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/register');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: const Text(
                                  "Register",
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                  // Bottom spacing
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ScaleTransition(
                      scale: _popAnimation,
                      child: SizedBox(height: size.height * 0.02),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}