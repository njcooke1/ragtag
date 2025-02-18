// lib/pages/club_events_page.dart

import 'package:flutter/material.dart';

class ClubEventsPage extends StatelessWidget {
  final String clubId;
  final String clubName;

  const ClubEventsPage({
    Key? key,
    required this.clubId,
    required this.clubName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$clubName Events"),
        backgroundColor: const Color(0xFF1F1F1F),
      ),
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: Text(
          'Upcoming Events for $clubName!',
          style: const TextStyle(color: Colors.white70, fontSize: 18),
        ),
      ),
      // TODO: Implement your events list UI here
    );
  }
}
