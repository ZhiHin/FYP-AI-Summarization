import 'package:ai_summarization/screen/camera_view.dart';
import 'package:flutter/material.dart';
import '../components/bottom_nav_bar.dart';
import 'documents.dart';
import 'home_page.dart';
import 'profile.dart';
import 'tools.dart';

class MainPage extends StatefulWidget {
  const MainPage({Key? key}) : super(key: key);

  @override
  _MainPageState createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0; // Keep track of the selected index
  final List<Widget> _pages = [
    const HomePage(), // Home Page
    const DocumentsPage(), // Document Page
    const CameraView(), // Camera Page
    const ToolsPage(), // Tools Page
    const ProfilePage(), // Profile Page
  ];

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index; // Update the current index
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex], // Display the current page
      bottomNavigationBar: BottomNavBar(
        // Use the BottomNavBar widget
        currentIndex: _currentIndex, // Pass current index to the BottomNavBar
        onTap: _onItemTapped, // Handle taps
      ),
    );
  }
}
