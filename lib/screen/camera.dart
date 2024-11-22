import 'package:ai_summarization/screen/upload_gallery.dart';
import 'package:ai_summarization/screen/image_preview.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class Camera extends StatefulWidget {
  @override
  _CameraState createState() => _CameraState();
}

class _CameraState extends State<Camera> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        _controller = CameraController(cameras![0], ResolutionPreset.high);
        await _controller!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<XFile?> _captureImage() async {
    if (!_controller!.value.isInitialized) {
      return null;
    }

    if (_controller!.value.isTakingPicture) {
      return null;
    }

    try {
      XFile image = await _controller!.takePicture();
      return image;
    } catch (e) {
      print('Error capturing image: $e');
      return null;
    }
  }

  Future<void> _uploadImageToFirebase(XFile image) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in');
        return;
      }
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      String userId = user.uid;
      Reference storageRef =
          FirebaseStorage.instance.ref('users/$userId/uploads/$fileName');

      // Upload the file to Firebase Storage
      final UploadTask uploadTask = storageRef.putFile(File(image.path));

      // Wait for the upload to complete
      TaskSnapshot taskSnapshot = await uploadTask;

      // Get the download URL of the uploaded file
      String imageUrl = await taskSnapshot.ref.getDownloadURL();

      // Log the image URL
      print('Image URL: $imageUrl');

      // Save metadata to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('images')
          .add({
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('File uploaded and Firestore document created successfully');
    } on FirebaseException catch (e) {
      print('Error uploading image to Firebase: $e');
    } catch (e) {
      print('Unexpected error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
      ),
      body: Stack(
        children: [
          _isCameraInitialized
              ? Column(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
        ],
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          BottomAppBar(
            shape: CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                SizedBox(width: 48), // Space for the custom round button
                Spacer(),
                IconButton(
                  icon: Icon(Icons.photo_library),
                  onPressed: () {
                    // Navigate to the gallery page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UploadGallery()),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10.0,
            child: GestureDetector(
              onTap: () async {
                final image = await _captureImage();
                if (image != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImagePreview(
                        file: image,
                        onConfirm: () async {
                          // Upload to Firebase and save to Firestore
                          await _uploadImageToFirebase(image);
                        },
                      ),
                    ),
                  );
                } else {
                  print('Error capturing image');
                }
              },
              child: Container(
                width: 56.0,
                height: 56.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
