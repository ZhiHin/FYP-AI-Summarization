// nav_button.dart
import 'package:flutter/material.dart';

class NavButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const NavButton({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 30, color: Colors.blueAccent),
          onPressed: () {
            // Handle button press
          },
        ),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
