import 'package:flutter/material.dart';

class DirectMessagePage extends StatelessWidget {
  const DirectMessagePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Direct Messages')),
      body: const Center(child: Text('Direct-message hub coming soon!')),
    );
  }
}
