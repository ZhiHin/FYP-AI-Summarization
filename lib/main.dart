import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'screen/login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase once
  runApp(const SummaSphereApp());
}

class SummaSphereApp extends StatelessWidget {
  const SummaSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SummaSphere',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      debugShowCheckedModeBanner: false,
      home: LoginPage(), // Directly set LoginPage as home
    );
  }
}