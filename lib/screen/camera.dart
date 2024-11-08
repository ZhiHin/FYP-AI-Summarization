import 'package:flutter/material.dart';

class CameraPage extends StatelessWidget {
  const CameraPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 20.0, left: 16.0, right: 16.0), // Adjust the top padding
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Align items at the start
            children: [
              const SizedBox(height: 30), // Add space before the buttons
              ElevatedButton(
                onPressed: () {
                  // Implement camera functionality
                },
                child: const Text("Open Camera"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  // Implement image selection from gallery
                },
                child: const Text("Select from Gallery"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
