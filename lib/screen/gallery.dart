import 'package:ai_summarization/screen/DetectText.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class Gallery extends StatefulWidget {
  @override
  _GalleryState createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  List<String> _imageUrls = [];
  List<String> _selectedImages = [];
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchImageUrls();
  }

  Future<void> _fetchImageUrls() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in');
        return;
      }
      String userId = user.uid;
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('images')
          .get();

      List<String> imageUrls = [];
      for (var doc in snapshot.docs) {
        String imageUrl = doc['imageUrl'];
        imageUrls.add(imageUrl);
      }

      setState(() {
        _imageUrls = imageUrls;
      });
    } catch (e) {
      print('Error fetching image URLs: $e');
    }
  }

  void _toggleSelection(String imageUrl) {
    setState(() {
      if (_selectedImages.contains(imageUrl)) {
        _selectedImages.remove(imageUrl);
      } else {
        _selectedImages.add(imageUrl);
      }
    });
  }

  void _onLongPress(String imageUrl) {
    setState(() {
      _selectionMode = true;
      _toggleSelection(imageUrl);
    });
  }

  void _onTap(String imageUrl) {
    if (_selectionMode) {
      _toggleSelection(imageUrl);
    }
  }

  void _uploadSelectedImages() {
    // Navigate to the DetectText page with the selected image URLs
    if (_selectedImages.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetectText(imageUrls: _selectedImages),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Uploaded Image Gallery'),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: Icon(Icons.cancel),
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedImages.clear();
                });
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _imageUrls.isEmpty
                ? Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4.0,
                      mainAxisSpacing: 4.0,
                    ),
                    itemCount: _imageUrls.length,
                    itemBuilder: (context, index) {
                      final imageUrl = _imageUrls[index];
                      final isSelected = _selectedImages.contains(imageUrl);
                      return GestureDetector(
                        onLongPress: () => _onLongPress(imageUrl),
                        onTap: () => _onTap(imageUrl),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            ),
                            if (isSelected)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _uploadSelectedImages,
              child: Text('Upload Selected Images'),
            ),
          ),
        ],
      ),
    );
  }
}
