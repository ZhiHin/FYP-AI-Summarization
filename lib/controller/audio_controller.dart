import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../model/audio_model.dart';

class AudioController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  User? get currentUser => _auth.currentUser;

  Future<void> pickAndUploadAudioFile(BuildContext context) async {
  if (currentUser == null) {
    _showSnackBar(context, 'Please log in to upload audio');
    return;
  }

  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.audio,
    allowMultiple: false,
  );

  if (result != null) {
    try {
      File selectedFile = File(result.files.single.path!);
      String fileName = result.files.single.name;
      String audioId = DateTime.now().millisecondsSinceEpoch.toString();
      int fileSize = await selectedFile.length();

      // Upload to Firebase Storage
      Reference firebaseStorageRef =
          _storage.ref().child('users/${currentUser!.uid}/audios/$fileName');

      UploadTask uploadTask = firebaseStorageRef.putFile(selectedFile);
      TaskSnapshot taskSnapshot = await uploadTask;
      String fileUrl = await taskSnapshot.ref.getDownloadURL();

      // Create document data
      Map<String, dynamic> audioData = {
        'name': fileName,
        'description': '',
        'size': fileSize,
        'uploadedAt': Timestamp.now(),
        'fileUrl': fileUrl,
        'folderId': null,
        'documentType': 'audios',
        'audioId': audioId,
        'transcribed': false,
        'transcriptText': null,
      };

      // Save to Firestore
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('audios')
          .doc(audioId)
          .set(audioData);

      _showSnackBar(context, 'Audio uploaded successfully');
    } catch (e) {
      _showSnackBar(context, 'Upload failed: $e');
    }
  }
}

  Future<void> deleteAudio(BuildContext context, String audioId, String fileUrl,
      bool Function() isMounted) async {
    if (currentUser == null) {
      if (isMounted()) {
        _showSnackBar(context, 'Please log in to delete audio');
      }
      return;
    }

    try {
      // Deletion logic remains the same
      await _storage.refFromURL(fileUrl).delete();
      await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .collection('audios')
          .doc(audioId)
          .delete();

      if (isMounted()) {
        _showSnackBar(context, 'Audio deleted successfully');
      }
    } catch (e) {
      if (isMounted()) {
        _showSnackBar(context, 'Error deleting audio: $e');
      }
    }
  }

  Future<String?> generateTranscript(
    BuildContext context, String audioId, String fileUrl) async {
  if (currentUser == null) {
    _showSnackBar(context, 'Please log in to generate transcript');
    return null;
  }

  try {
    // Fetch the document and handle data access safely
    DocumentSnapshot audioDoc = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('audios')
        .doc(audioId)
        .get();

    if (!audioDoc.exists) {
      throw Exception('Audio document not found');
    }

    // Safely access data with type checking
    final data = audioDoc.data() as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Audio data is null');
    }

    String correctFileUrl = data['fileUrl'] as String? ?? fileUrl;
    if (correctFileUrl.isEmpty || !correctFileUrl.startsWith('https://')) {
      throw Exception('Invalid file URL: $correctFileUrl');
    }

      // Download the file from Firebase Storage
      final tempDir = await getTemporaryDirectory();
      final localFilePath = '${tempDir.path}/$audioId.mp3';

      final ref = _storage.refFromURL(correctFileUrl);
      await ref.writeToFile(File(localFilePath));

      // Create a multipart request
      var uri = Uri.parse('http://192.168.1.106:8000/audio_to_text');
      var request = http.MultipartRequest('POST', uri);

      request.fields['audioId'] = audioId;

      var multipartFile = await http.MultipartFile.fromPath(
          'file', localFilePath,
          filename: 'audio.mp3', contentType: MediaType('audio', 'mpeg'));

      request.files.add(multipartFile);

      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        var decodedResponse = json.decode(responseBody);
        String transcribedText =
            decodedResponse['transcription'] ?? 'No text transcribed';

        // Update Firestore to mark as transcribed
        await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .collection('audios')
            .doc(audioId)
            .update({
          'transcribed': true,
          'transcriptText': transcribedText,
        });

        _showSnackBar(context, 'Transcription completed');
        return transcribedText;
      } else {
        _showSnackBar(context, 'Transcription failed: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _showSnackBar(context, 'Error in transcription: $e');
      return null;
    }
  }

  Stream<List<AudioModel>> getAudioList() {
    if (currentUser == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('audios')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AudioModel.fromFirestore(doc)).toList());
  }

  void _showSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
