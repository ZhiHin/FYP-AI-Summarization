import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadGallery extends StatefulWidget {
  @override
  _UploadGalleryState createState() => _UploadGalleryState();
}

class _UploadGalleryState extends State<UploadGallery> {
  List<File> _images = [];
  List<File> _selectedImages = [];
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _pickImage();
  }

  Future<void> _pickImage() async {
    final ImagePicker _picker = ImagePicker();
    final List<XFile>? pickedFiles = await _picker.pickMultiImage();

    if (pickedFiles != null && pickedFiles.isNotEmpty) {
      setState(() {
        _images = pickedFiles.map((pickedFile) {
          final filename = path.basename(pickedFile.path);
          print('Picked file: ${pickedFile.path}');
          print('Filename: $filename');
          return File(pickedFile.path);
        }).toList();
      });
    } else {
      print('No images picked');
    }
  }

  void _toggleSelection(File image) {
    setState(() {
      if (_selectedImages.contains(image)) {
        _selectedImages.remove(image);
      } else {
        _selectedImages.add(image);
      }
    });
  }

  void _onLongPress(File image) {
    setState(() {
      _selectionMode = true;
      _toggleSelection(image);
    });
  }

  void _onTap(File image) {
    if (_selectionMode) {
      _toggleSelection(image);
    }
  }

  void _deleteSelectedImages() {
    setState(() {
      _images.removeWhere((image) => _selectedImages.contains(image));
      _selectedImages.clear();
      _selectionMode = false;
    });
  }

  Future<void> _uploadImages() async {
    List<File> uploadedImages = [];
    if (_selectedImages.isEmpty) {
      uploadedImages = _images;
    } else {
      uploadedImages = _selectedImages;
    }

    for (File image in uploadedImages) {
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          print('User not logged in');
          return;
        }
        final String fileName = path.basename(image.path);
        String userId = user.uid;
        Reference storageRef =
            FirebaseStorage.instance.ref('users/$userId/uploads/$fileName');

        // Upload the file to Firebase Storage
        final UploadTask uploadTask = storageRef.putFile(image);
        await uploadTask;

        TaskSnapshot taskSnapshot = await uploadTask;

        // Get the download URL of the uploaded file
        String imageUrl = await taskSnapshot.ref.getDownloadURL();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('images')
            .add({
          'imageUrl': imageUrl,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        print('Error uploading image to Firebase: $e');
      } catch (e) {
        print('Unexpected error: $e');
      }
    }
    print('All selected images uploaded');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Upload Images'),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deleteSelectedImages,
            ),
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
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _images.isEmpty
                    ? Center(child: Text('No images selected.'))
                    : GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4.0,
                          mainAxisSpacing: 4.0,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          final image = _images[index];
                          final isSelected = _selectedImages.contains(image);
                          return GestureDetector(
                            onLongPress: () => _onLongPress(image),
                            onTap: () => _onTap(image),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.file(image, fit: BoxFit.cover),
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
            ],
          ),
          Positioned(
            bottom: 16.0,
            left: 0,
            right: 0,
            child: Center(
              child: ElevatedButton(
                onPressed: _uploadImages,
                child: Text('Upload Selected Images'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
