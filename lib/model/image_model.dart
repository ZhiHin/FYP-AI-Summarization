import 'dart:io';
import 'package:ai_summarization/screen/utils.dart';
import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';

class ImageModel {
  Future<void> uploadImageToFirebase(BuildContext context, XFile image) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in');
        return;
      }
      String fileName = image.name;
      String userId = user.uid;
      Reference storageRef =
          FirebaseStorage.instance.ref('users/$userId/images/$fileName');

      ListResult result =
          await FirebaseStorage.instance.ref('users/$userId/images').listAll();

      List<String> existingFiles =
          result.items.map((item) => item.name).toList();

      int index = 1;
      while (existingFiles.contains(fileName)) {
        fileName =
            '${path.basenameWithoutExtension(image.name)}($index)${path.extension(image.name)}';
        storageRef =
            FirebaseStorage.instance.ref('users/$userId/images/$fileName');
        index++;
      }

      final UploadTask uploadTask = storageRef.putFile(File(image.path));

      TaskSnapshot taskSnapshot = await uploadTask;

      String imageUrl = await taskSnapshot.ref.getDownloadURL();

      // Get the image size
      int imageSize = await File(image.path).length();

      // Save metadata to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('images')
          .add({
        'fileUrl': imageUrl,
        'description': '',
        'folderId': '',
        'documentType': 'images',
        'name': fileName,
        'size': imageSize,
        'uploadedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      showSnackBar(context, "Error capturing image: $e");
    } catch (e) {
      showSnackBar(context, "Unexpected Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getImageData(BuildContext context) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('User not logged in');
        return [];
      }
      String userId = user.uid;
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('images')
          .get();

      List<Map<String, dynamic>> imageData = [];
      for (var doc in snapshot.docs) {
        imageData.add(doc.data() as Map<String, dynamic>);
      }
      return imageData;
    } catch (e) {
      showSnackBar(context, "Error capturing image: $e");
      return [];
    }
  }
}
