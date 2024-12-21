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
  int _currentIndex = 0;
  String? _documentTypeFilter;
  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    // Initialize pages with the navigation function
    _pages.addAll([
      HomePage(onNavigateToPage: _navigateToPage),
      DocumentsPage(documentTypeFilter: _documentTypeFilter),
      const CameraView(),
      const ToolsPage(),
      const ProfilePage(),
    ]);
  }

  void _navigateToPage(int index, {String? documentTypeFilter}) {
    setState(() {
      _currentIndex = index;
      _documentTypeFilter = documentTypeFilter;
      _pages[1] = DocumentsPage(documentTypeFilter: _documentTypeFilter);
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
      // Reset document filter when navigating to Documents page via bottom nav
      if (index == 1) {
        _documentTypeFilter = null;
        _pages[1] = const DocumentsPage(documentTypeFilter: null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
