import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdf_render/pdf_render.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  _DocumentsPageState createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Stream<QuerySnapshot> get _documentStream {
    final user = _auth.currentUser;
    if (user != null) {
      return _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .snapshots();
    } else {
      return const Stream.empty();
    }
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.isNotEmpty) {
      final originalFileName = result.files.single.name;
      final filePath = result.files.single.path!;

      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to upload a document')),
        );
        return;
      }

      final userId = user.uid;
      final file = File(filePath);
      final fileSize = await file.length();
      final uploadDate = DateTime.now();

      final storageRef =
          FirebaseStorage.instance.ref().child('users/$userId/documents/');

      // Generate a unique filename if a document with the same name exists
      String fileName = originalFileName;
      int count = 1;

      // Check if the file already exists by attempting to get its URL
      while (await _fileExists(storageRef, fileName)) {
        fileName =
            '${originalFileName.substring(0, originalFileName.lastIndexOf('.'))}($count)${originalFileName.substring(originalFileName.lastIndexOf('.'))}';
        count++;
      }

      try {
        // Use uploadTask to upload the file
        TaskSnapshot uploadTask =
            await storageRef.child(fileName).putFile(file);
        final fileUrl =
            await uploadTask.ref.getDownloadURL(); // Get the URL after upload

        int? pageCount;
        if (originalFileName.endsWith('.pdf')) {
          pageCount = await _getPdfPageCount(filePath);
        }

        final document = {
          'title': fileName,
          'description': '',
          'size': fileSize,
          'uploadedAt': uploadDate,
          'pageCount': pageCount ?? 0,
          'fileUrl': fileUrl,
        };

        await _firestore
            .collection('users')
            .doc(userId)
            .collection('documents')
            .add(document);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

// Helper method to check if file exists
  Future<bool> _fileExists(Reference storageRef, String fileName) async {
    try {
      await storageRef.child(fileName).getDownloadURL();
      return true; // File exists
    } catch (e) {
      return false; // File does not exist
    }
  }

  Future<int?> _getPdfPageCount(String path) async {
    try {
      final document = await PdfDocument.openFile(path);
      return document.pageCount;
    } catch (e) {
      print('Error opening PDF: $e');
      return null;
    }
  }

  Future<void> _deleteDocument(
      String documentId, String fileUrl, String fileName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to delete a document')),
        );
        return;
      }

      // Delete file from Firebase Storage
      final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
      await storageRef.delete();

      // Delete document from Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .doc(documentId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$fileName deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting file: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () async {
              await _auth.signOut();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logged out successfully')),
              );
            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _documentStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final documents = snapshot.data?.docs ?? [];
          return ListView.builder(
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              final data = document.data() as Map<String, dynamic>;
              final fileName = data['title'];
              final uploadDate = (data['uploadedAt'] as Timestamp).toDate();
              final fileSize = data['size'];
              final pageCount =
                  data.containsKey('pageCount') ? data['pageCount'] : 0;
              final fileUrl = data['fileUrl'];
              final documentId = document.id;

              return ListTile(
                title: Text(fileName),
                subtitle: Text(
                  'Uploaded on: $uploadDate\nSize: ${fileSize / 1024} KB\nPages: $pageCount',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        _deleteDocument(documentId, fileUrl, fileName);
                      },
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DocumentViewer(
                        fileName: fileName,
                        fileSize: fileSize,
                        pageCount: pageCount,
                        fileUrl: fileUrl,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickAndUploadFile,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DocumentViewer extends StatelessWidget {
  final String fileName;
  final int fileSize;
  final int pageCount;
  final String fileUrl;

  const DocumentViewer({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.pageCount,
    required this.fileUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document Name: $fileName'),
            Text('File Size: ${fileSize / 1024} KB'),
            Text('Page Count: $pageCount'),
            const SizedBox(height: 16),
            Expanded(
              child: SfPdfViewer.network(fileUrl), // Load PDF from URL
            ),
          ],
        ),
      ),
    );
  }
}
