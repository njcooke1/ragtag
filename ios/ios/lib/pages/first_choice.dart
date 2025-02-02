import 'dart:ui'; // For PathMetric and PathMetrics 
import 'dart:math'; // For pi and math operations
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'find_community.dart';

// Firebase imports
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirstChoicePage extends StatefulWidget {
  const FirstChoicePage({Key? key}) : super(key: key);

  @override
  State<FirstChoicePage> createState() => _FirstChoicePageState();
}

class _FirstChoicePageState extends State<FirstChoicePage>
    with SingleTickerProviderStateMixin {
  bool _didCheckArgs = false;
  bool _didPrecache = false;

  late AnimationController _badgeAnimController;
  late Animation<double> _scaleAnim;
  late Animation<double> _rotationAnim;

  @override
  void initState() {
    super.initState();

    // For extra flair, let’s animate the badge just a bit
    _badgeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _badgeAnimController, curve: Curves.easeInOut),
    );
    _rotationAnim = Tween<double>(begin: -0.015, end: 0.015).animate(
      CurvedAnimation(parent: _badgeAnimController, curve: Curves.easeInOut),
    );

    _badgeAnimController.forward().then((_) {
      _badgeAnimController.reverse();
    });
    _badgeAnimController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _badgeAnimController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _badgeAnimController.forward();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Only do the precaching once
    if (!_didPrecache) {
      _didPrecache = true;
      precacheImage(const AssetImage('assets/club1.png'), context);
      precacheImage(const AssetImage('assets/event1.png'), context);
      precacheImage(const AssetImage('assets/club2.png'), context);
      precacheImage(const AssetImage('assets/placeholder.png'), context);
    }

    // Only check once for arguments
    if (!_didCheckArgs) {
      _didCheckArgs = true;
      final isFromLikesDislikes =
          ModalRoute.of(context)?.settings.arguments == 'fromLikesDislikes';
      if (isFromLikesDislikes) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showNewMemberDialog();
        });
      }
    }
  }

  @override
  void dispose() {
    _badgeAnimController.dispose();
    super.dispose();
  }

  Future<void> _awardIntroBadge() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
      await userDoc.set({
        'badges': FieldValue.arrayUnion(['introbadge']),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint("Error awarding intro badge: $e");
    }
  }

  void _showNewMemberDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Center(
          child: Material(
            color: Colors.black54,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.88,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 40,
                    spreadRadius: 10,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.amberAccent.withOpacity(0.5),
                              Colors.transparent,
                            ],
                            radius: 0.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellowAccent.withOpacity(0.4),
                              blurRadius: 70,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                      ),
                      Shimmer.fromColors(
                        baseColor: Colors.yellowAccent.withOpacity(0.2),
                        highlightColor: Colors.white.withOpacity(0.1),
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: const BoxDecoration(
                            color: Colors.amberAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _badgeAnimController,
                        builder: (ctx, child) {
                          return Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..scale(_scaleAnim.value, _scaleAnim.value)
                              ..rotateZ(_rotationAnim.value),
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/newmemberbadge.png',
                          height: 160,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "CONGRATULATIONS!",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lovelo',
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "As a welcoming gift, here's your first badge!\nCheck your profile to see it shine in all its glory.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amberAccent,
                      foregroundColor: Colors.black87,
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      elevation: 2,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Awesome!"),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    _awardIntroBadge();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: GestureDetector(
              onTap: () {
                Navigator.pushNamed(context, '/start-community');
              },
              child: Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(60, 60),
                        painter: StartCommunityIconPainter(),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Start a community',
                        style: TextStyle(fontSize: 20, color: Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FindCommunityPage()),
                );
              },
              child: Container(
                color: Colors.black,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomPaint(
                        size: const Size(75, 75),
                        painter: FindCommunityIconPainter(),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Find a community',
                        style: TextStyle(fontSize: 20, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            height: 100,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFAF7B),
                  Color(0xFFD76D77),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Center(
              child: Image.asset(
                'assets/ragtaglogo.png',
                height: 75,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter for "Find a Community" Icon (Thinner Magnifying Glass)
class FindCommunityIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Magnifying glass handle
    final double handleLength = size.height * 0.4;
    final Offset handleStart = Offset(size.width * 0.7, size.height * 0.7);
    final Offset handleEnd = Offset(size.width, size.height);
    canvas.drawLine(handleStart, handleEnd, paint);

    // Circle
    final Offset circleCenter = Offset(size.width * 0.4, size.height * 0.4);
    final double circleRadius = size.width * 0.3;
    canvas.drawCircle(circleCenter, circleRadius, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Custom Painter for "Start a Community" Icon
class StartCommunityIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final Offset center = Offset(radius, radius);

    // Paint for solid arcs
    final Paint solidPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Draw solid arcs (3 quadrants)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      3 * pi / 2,
      false,
      solidPaint,
    );

    // Dashed arc
    final Paint dashedPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final Path dashedArc = Path();
    dashedArc.addArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi / 2,
    );

    _drawDashedPath(canvas, dashedArc, dashedPaint);

    // plus sign
    final double plusSize = radius;
    final Paint plusPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // vertical line
    canvas.drawLine(
      Offset(center.dx, center.dy - plusSize / 2),
      Offset(center.dx, center.dy + plusSize / 2),
      plusPaint,
    );
    // horizontal line
    canvas.drawLine(
      Offset(center.dx - plusSize / 2, center.dy),
      Offset(center.dx + plusSize / 2, center.dy),
      plusPaint,
    );
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const double dashWidth = 5;
    const double dashSpace = 5;
    for (final PathMetric pathMetric in path.computeMetrics()) {
      double distance = 0;
      while (distance < pathMetric.length) {
        final double nextDistance = distance + dashWidth;
        canvas.drawPath(
          pathMetric.extractPath(distance, nextDistance),
          paint,
        );
        distance = nextDistance + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
