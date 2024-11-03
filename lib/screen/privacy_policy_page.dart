import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Privacy Policy",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                "Your privacy is important to us. This privacy policy explains how we collect, use, and share your personal information. We will ensure that your information is used in accordance with this privacy policy.",
                style: TextStyle(fontSize: 16),
              ),
              // Add more details about your privacy policy here.
            ],
          ),
        ),
      ),
    );
  }
}
