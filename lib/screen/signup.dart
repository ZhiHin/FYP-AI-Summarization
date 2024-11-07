import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'mainpage.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Function to save user data in Firestore
  Future<void> _saveUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Storing user data in Firestore under the 'users' collection
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'createdAt': Timestamp.now(), // Store the creation timestamp
      });
      print("User data saved to Firestore!");
    }
  }

  // Function to handle sign-up process
  Future<void> _signUp() async {
  if (_passwordController.text == _confirmPasswordController.text) {
    try {
      // Create user with Firebase Authentication
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Save user data in Firestore after successful sign-up
      await _saveUserData();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account created!')));

      // Wait for Firebase Auth to finish before navigating
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Navigate to MainPage after the user is confirmed
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainPage()));
      } else {
        // Handle the case where the user is not authenticated (should not happen)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User not authenticated')));
      }

    } catch (e) {
      // Show error message if sign-up fails
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to sign up: $e')));
    }
  } else {
    // Show error if passwords do not match
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Passwords do not match')));
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: InputDecoration(labelText: 'Confirm Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please confirm your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        _signUp();
                      }
                    },
                    child: Text('Sign Up'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
