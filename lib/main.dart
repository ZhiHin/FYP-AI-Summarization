import 'package:flutter/material.dart';
import 'screen/mainpage.dart';

void main() {
  runApp(const SummaSphereApp());
}

class SummaSphereApp extends StatelessWidget {
  const SummaSphereApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MainPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
