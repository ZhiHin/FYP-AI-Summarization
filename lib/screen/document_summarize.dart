import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'extractText.dart';

class DocumentSummarizePage extends StatefulWidget {
  const DocumentSummarizePage({super.key});

  @override
  State<DocumentSummarizePage> createState() => _DocumentSummarizePageState();
}

class _DocumentSummarizePageState extends State<DocumentSummarizePage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _selectedFileUrl;
  bool _isLoading = false;

  Stream<QuerySnapshot> get _documentStream {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .orderBy('uploadedAt', descending: true)
          .snapshots();
    }
    return const Stream.empty();
  }

  Future<void> _pickAndUploadFile() async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) return;

      final user = _auth.currentUser;
      if (user == null) {
        _showSnackBar('Please log in to upload a document');
        return;
      }

      final file = File(result.files.single.path!);
      final fileSize = await file.length();
      if (fileSize > 10 * 1024 * 1024) {
        // 10MB limit
        _showSnackBar('File size must be less than 10MB');
        return;
      }

      final fileName = await _getUniqueFileName(
        user.uid,
        result.files.single.name,
      );

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/documents/$fileName');

      final uploadTask = await storageRef.putFile(file);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .add({
        'name': fileName,
        'description': '',
        'size': fileSize,
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileUrl': fileUrl,
      });

      _showSnackBar('File uploaded successfully');
    } catch (e) {
      _showSnackBar('Error uploading file: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Summarize'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_selectedFileUrl != null)
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: SfPdfViewer.network(_selectedFileUrl!),
                ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _documentStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('Something went wrong'),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    final documents = snapshot.data?.docs ?? [];
                    if (documents.isEmpty) {
                      return const Center(
                        child: Text('No documents uploaded yet'),
                      );
                    }

                    return ListView.builder(
                      itemCount: documents.length,
                      itemBuilder: (context, index) {
                        final document = documents[index];
                        final data = document.data() as Map<String, dynamic>;
                        final fileName = data['name'] as String;
                        final uploadDate =
                            (data['uploadedAt'] as Timestamp?)?.toDate() ??
                                DateTime.now();
                        final fileSize = (data['size'] as num).toDouble();
                        final fileUrl = data['fileUrl'] as String;
                        final documentId = document.id;

                        return ListTile(
                          title: Text(fileName),
                          subtitle: Text(
                            'Uploaded on: ${uploadDate.toString().split('.')[0]}\n'
                            'Size: ${(fileSize / 1024).toStringAsFixed(2)} KB',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => _deleteDocument(
                                  documentId,
                                  fileUrl,
                                  fileName,
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                          selected: _selectedFileUrl == fileUrl,
                          onTap: () {
                            setState(() => _selectedFileUrl = fileUrl);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              if (_selectedFileUrl != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // Navigate to ExtractScreen when a document is selected
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ExtractScreen(fileUrl: _selectedFileUrl!),
                        ),
                      );
                    },
                    child: const Text('Extract Text'),
                  ),
                ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadFile,
        child: const Icon(Icons.upload_file),
      ),
    );
  }

  Future<void> _deleteDocument(
      String documentId, String fileUrl, String fileName) async {
    final user = _auth.currentUser;
    if (user == null) {
      _showSnackBar('Please log in to delete the document');
      return;
    }

    try {
      final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
      await storageRef.delete();
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .doc(documentId)
          .delete();
      _showSnackBar('Document deleted successfully');
    } catch (e) {
      _showSnackBar('Error deleting document: $e');
    }
  }

  Future<String> _getUniqueFileName(String userId, String fileName) async {
    final fileRef = FirebaseStorage.instance
        .ref()
        .child('users/$userId/documents/$fileName');

    try {
      // Try to get the file metadata
      await fileRef.getMetadata();
      // If it succeeds, the file already exists
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newFileName = '${timestamp}_$fileName';
      return newFileName;
    } catch (e) {
      // If it fails (file does not exist), return the original file name
      return fileName;
    }
  }
}
