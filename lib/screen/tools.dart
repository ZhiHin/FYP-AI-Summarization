import 'package:flutter/material.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Tools'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, // Align items to the start
          children: [
            const SizedBox(height: 20), // Add space at the top
            const Text(
              "Select a Tool",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text("PDF to Word Converter"),
              onTap: () {
                // Implement functionality
              },
            ),
            ListTile(
              title: const Text("Image Resizer"),
              onTap: () {
                // Implement functionality
              },
            ),
            ListTile(
              title: const Text("Text Summarizer"),
              onTap: () {
                // Implement functionality
              },
            ),
          ],
        ),
      ),
    );
  }
}
