import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Screens that are designed in Figma but not coded yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.note});
  final String title, note;

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      Container(
        padding: const EdgeInsets.all(20),
        decoration: saCard(),
        child: Text('ยังไม่ได้เขียน · $note', style: const TextStyle(color: SA.text2)),
      ),
    ]);
  }
}
