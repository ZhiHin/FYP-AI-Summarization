import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';

// Enum for document types
enum DocumentType { pdf, word, images, audios }

// Utility function to determine document type
DocumentType getDocumentType(String fileName) {
  final extension = path.extension(fileName).toLowerCase();
  switch (extension) {
    case '.pdf':
      return DocumentType.pdf;
    case '.docx':
    case '.doc':
      return DocumentType.word;
    case '.jpg':
    case '.jpeg':
    case '.png':
    case '.gif':
    case '.bmp':
      return DocumentType.images;
    case '.mp3':
    case '.wav':
    case '.aac':
    case '.flac':
      return DocumentType.audios;
    default:
      return DocumentType.pdf;
  }
}

class DocumentsPage extends StatefulWidget {
  final String? documentTypeFilter;

  const DocumentsPage({Key? key, this.documentTypeFilter}) : super(key: key);

  @override
  _DocumentsPageState createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _selectedFolderId;
  String? _selectedDocumentType;
  List<String> _folderPath = [];
  List<Map<String, dynamic>> _filteredDocuments = [];

  @override
  void initState() {
    super.initState();
    _selectedDocumentType = null;
    _loadDocuments();
  }

  @override
  void didUpdateWidget(DocumentsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.documentTypeFilter != widget.documentTypeFilter) {
      setState(() {
        _selectedDocumentType = widget.documentTypeFilter;
      });
      _loadDocuments();
    }
  }

  static const List<String> documentTypes = ['pdf', 'word', 'images', 'audios'];

  Future<void> _loadDocuments() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Create queries for all collections
      List<QuerySnapshot> snapshots = await Future.wait([
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('documents')
            .get(),
        _firestore.collection('users').doc(user.uid).collection('images').get(),
        _firestore.collection('users').doc(user.uid).collection('audios').get(),
      ]);

      // Combine all documents
      List<Map<String, dynamic>> allDocuments = [];

      // Add documents from each collection
      for (var snapshot in snapshots) {
        allDocuments.addAll(snapshot.docs.map((doc) => {
              ...doc.data() as Map<String, dynamic>,
              'id': doc.id,
              'collection':
                  _getCollectionForDoc(doc.data() as Map<String, dynamic>),
            }));
      }

      setState(() {
        _filteredDocuments = allDocuments;
        _selectedDocumentType = widget.documentTypeFilter;
      });
    }
  }

// Helper method to determine collection
  String _getCollectionForDoc(Map<String, dynamic> data) {
    final docType = data['documentType']?.toString().toLowerCase();
    if (docType == 'images') return 'images';
    if (docType == 'audios') return 'audios';
    return 'documents';
  }

// Modify _combinedStream to include all collections
  Stream<List<QuerySnapshot>> get _combinedStream {
    final user = _auth.currentUser;
    if (user != null) {
      // Create folder query
      Query<Map<String, dynamic>> folderQuery =
          _firestore.collection('users').doc(user.uid).collection('folders');

      if (_selectedFolderId == null) {
        folderQuery = folderQuery.where('parentFolderId', isNull: true);
      } else {
        folderQuery =
            folderQuery.where('parentFolderId', isEqualTo: _selectedFolderId);
      }

      // Create queries for all document types
      List<Stream<QuerySnapshot>> documentStreams = [];

      // Get the effective filter
      final effectiveFilter =
          _selectedDocumentType ?? widget.documentTypeFilter;

      // Create base queries
      final docsQuery =
          _firestore.collection('users').doc(user.uid).collection('documents');

      final imagesQuery =
          _firestore.collection('users').doc(user.uid).collection('images');

      final audiosQuery =
          _firestore.collection('users').doc(user.uid).collection('audios');

      // Apply folder filter to all queries
      final filteredDocsQuery = _applyFolderFilter(docsQuery);
      final filteredImagesQuery = _applyFolderFilter(imagesQuery);
      final filteredAudiosQuery = _applyFolderFilter(audiosQuery);

      if (effectiveFilter == null || effectiveFilter == 'all') {
        // If no filter or 'all' is selected, add streams for all document types
        documentStreams.addAll([
          filteredDocsQuery.snapshots(),
          filteredImagesQuery.snapshots(),
          filteredAudiosQuery.snapshots(),
        ]);
      } else {
        // Apply specific filter
        switch (effectiveFilter.toLowerCase()) {
          case 'documents':
            documentStreams.add(filteredDocsQuery
                .where('documentType', whereIn: ['pdf', 'word']).snapshots());
            break;
          case 'pdf':
            documentStreams.add(filteredDocsQuery
                .where('documentType', isEqualTo: 'pdf')
                .snapshots());
            break;
          case 'word':
            documentStreams.add(filteredDocsQuery
                .where('documentType', isEqualTo: 'word')
                .snapshots());
            break;
          case 'images':
            documentStreams.add(filteredImagesQuery.snapshots());
            break;
          case 'audios':
            documentStreams.add(filteredAudiosQuery.snapshots());
            break;
        }
      }

      // Combine folder query with document streams
      return Rx.combineLatest2(
        folderQuery.snapshots(),
        Rx.combineLatestList(documentStreams),
        (QuerySnapshot folders, List<QuerySnapshot> docs) => [folders, ...docs],
      );
    }
    return const Stream.empty();
  }

// Helper method to apply folder filter
  Query<Map<String, dynamic>> _applyFolderFilter(
      Query<Map<String, dynamic>> query) {
    if (_selectedFolderId == null) {
      return query.where('folderId', isNull: true);
    } else {
      return query.where('folderId', isEqualTo: _selectedFolderId);
    }
  }

  // Folder path management
  Future<void> _updateFolderPath() async {
    if (_selectedFolderId == null) {
      setState(() => _folderPath = []);
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    List<String> path = [];
    String? currentFolderId = _selectedFolderId;

    while (currentFolderId != null) {
      final folderDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('folders')
          .doc(currentFolderId)
          .get();

      if (folderDoc.exists) {
        final folderData = folderDoc.data()!;
        path.insert(0, folderData['name']);
        currentFolderId = folderData['parentFolderId'];
      } else {
        break;
      }
    }

    setState(() => _folderPath = path);
  }

  // Modified folder creation method to support subfolders
  Future<void> _createFolder({String? parentFolderId}) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final TextEditingController controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            parentFolderId == null ? 'Create New Folder' : 'Create Subfolder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter folder name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _firestore
                    .collection('users')
                    .doc(user.uid)
                    .collection('folders')
                    .add({
                  'name': controller.text,
                  'createdAt': DateTime.now(),
                  'parentFolderId': parentFolderId,
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // Method to rename folder
  Future<void> _renameFolder(String folderId, String currentName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final TextEditingController controller =
        TextEditingController(text: currentName);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Enter new folder name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _firestore
                    .collection('users')
                    .doc(user.uid)
                    .collection('folders')
                    .doc(folderId)
                    .update({'name': controller.text});
                Navigator.pop(context);
                _updateFolderPath();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  // Add rename function in _DocumentsPageState class
  Future<void> _renameDocument(
      String docId, String currentName, String fileUrl) async {
    final extension = path.extension(currentName);
    final baseName = path.basenameWithoutExtension(currentName);
    String newName = baseName;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Document'),
        content: TextField(
          autofocus: true,
          controller: TextEditingController(text: baseName),
          onChanged: (value) => newName = value,
          decoration: InputDecoration(
            labelText: 'New name',
            suffixText: extension,
            suffixStyle: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, '$newName$extension'),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != currentName) {
      try {
        final storage = FirebaseStorage.instance;
        final oldRef = storage.refFromURL(fileUrl);

        // Get original document data
        final docSnapshot = await _firestore
            .collection('users')
            .doc(_auth.currentUser?.uid)
            .collection('documents')
            .doc(docId)
            .get();

        final originalData = docSnapshot.data() ?? {};

        // Create new reference with new name
        final newRef = storage
            .ref()
            .child(oldRef.fullPath.replaceAll(currentName, result));

        // Copy file to new location
        final bytes = await oldRef.getData();
        if (bytes != null) {
          await newRef.putData(bytes);
          final newUrl = await newRef.getDownloadURL();

          // Update Firestore with all fields
          await _firestore
              .collection('users')
              .doc(_auth.currentUser?.uid)
              .collection('documents')
              .doc(docId)
              .update({
            ...originalData,
            'name': result,
            'fileUrl': newUrl,
            'storagePath': newRef.fullPath,
            'updatedAt': DateTime.now(),
          });

          // Delete old file
          await oldRef.delete();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document renamed successfully')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error renaming document: $e')),
        );
      }
    }
  }

  // Method to move document to folder
  Future<void> _moveDocumentToFolder(
      String documentId, String? currentFolderId, String collectionName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final foldersSnapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('folders')
        .get();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move Document to Folder'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.folder_open),
                title: const Text('Root Folder'),
                onTap: () {
                  _updateDocumentFolder(documentId, null, collectionName);
                  Navigator.pop(context);
                },
              ),
              ...foldersSnapshot.docs.map((folder) => ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(folder['name']),
                    onTap: () {
                      _updateDocumentFolder(
                          documentId, folder.id, collectionName);
                      Navigator.pop(context);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateDocumentFolder(
      String documentId, String? folderId, String collectionName) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
          .doc(documentId)
          .update({'folderId': folderId});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(folderId != null
              ? 'Document moved successfully'
              : 'Document moved to root folder'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error moving document: $e')),
      );
    }
  }

  String _getCollectionName(DocumentType documentType) {
    switch (documentType) {
      case DocumentType.images:
        return 'images';
      case DocumentType.audios:
        return 'audios';
      default:
        return 'documents';
    }
  }

  // File upload method
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

      // Generate unique filename
      String fileName = originalFileName;
      final documentType = getDocumentType(fileName);
      final collectionName = _getCollectionName(documentType);

      final storageRef = FirebaseStorage.instance.ref().child(
          'users/$userId/$collectionName/' // Changed this line to use collection name
          );

      int count = 1;
      while (await _fileExists(storageRef, fileName)) {
        fileName =
            '${path.basenameWithoutExtension(originalFileName)}($count)${path.extension(originalFileName)}';
        count++;
      }

      try {
        // Show upload progress
        final uploadTask = storageRef.child(fileName).putFile(file);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => StreamBuilder<TaskSnapshot>(
            stream: uploadTask.snapshotEvents,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final snap = snapshot.data!;
                final progress = snap.bytesTransferred / snap.totalBytes;

                return AlertDialog(
                  title: const Text('Uploading Document'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      Text('${(progress * 100).toStringAsFixed(1)}%'),
                    ],
                  ),
                );
              }
              return const AlertDialog(
                title: Text('Uploading Document'),
                content: LinearProgressIndicator(),
              );
            },
          ),
        );

        final taskSnapshot = await uploadTask;
        final fileUrl = await taskSnapshot.ref.getDownloadURL();
        Navigator.pop(context); // Close progress dialog

        int? pageCount;
        if (originalFileName.endsWith('.pdf')) {
          pageCount = await _getPdfPageCount(filePath);
        }

        final document = {
          'name': fileName,
          'description': '',
          'size': fileSize,
          'uploadedAt': uploadDate,
          'pageCount': pageCount ?? 0,
          'fileUrl': fileUrl,
          'folderId': _selectedFolderId,
          'documentType': documentType.toString().split('.').last,
        };

        await _firestore
            .collection('users')
            .doc(userId)
            .collection(collectionName)
            .add(document);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } catch (e) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      }
    }
  }

  Future<bool> _fileExists(Reference storageRef, String fileName) async {
    try {
      await storageRef.child(fileName).getDownloadURL();
      return true;
    } catch (e) {
      return false;
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

  // Document deletion method
  Future<void> _deleteDocument(String documentId, String fileUrl,
      String fileName, String collectionName) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Document'),
          content: Text('Are you sure you want to delete "$fileName"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Delete file from Firebase Storage
      final storageRef = FirebaseStorage.instance.refFromURL(fileUrl);
      await storageRef.delete();

      // Delete document from Firestore
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection(collectionName)
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

  // Folder deletion method
  Future<void> _deleteFolder(String folderId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // Check for subfolders
      final subfolders = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('folders')
          .where('parentFolderId', isEqualTo: folderId)
          .get();

      // Check for documents in all collections
      final documentsInFolder = await Future.wait([
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('documents')
            .where('folderId', isEqualTo: folderId)
            .get(),
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('images')
            .where('folderId', isEqualTo: folderId)
            .get(),
        _firestore
            .collection('users')
            .doc(user.uid)
            .collection('audios')
            .where('folderId', isEqualTo: folderId)
            .get(),
      ]);

      final hasDocuments =
          documentsInFolder.any((snapshot) => snapshot.docs.isNotEmpty);

      if (subfolders.docs.isNotEmpty || hasDocuments) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot delete non-empty folder')),
        );
        return;
      }

      // Show confirmation dialog
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Folder'),
          content: const Text('Are you sure you want to delete this folder?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('folders')
            .doc(folderId)
            .delete();

        if (_selectedFolderId == folderId) {
          setState(() {
            _selectedFolderId = null;
            _folderPath = [];
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Folder deleted successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting folder: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Documents'),
        leading: _selectedFolderId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async {
                  if (_selectedFolderId != null) {
                    // Get parent folder ID
                    final folderDoc = await _firestore
                        .collection('users')
                        .doc(_auth.currentUser?.uid)
                        .collection('folders')
                        .doc(_selectedFolderId)
                        .get();

                    setState(() {
                      _selectedFolderId = folderDoc.data()?['parentFolderId'];
                    });
                    _updateFolderPath();
                  }
                },
              )
            : null,
        actions: [
          // Document type filter
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (String value) {
              setState(() {
                _selectedDocumentType =
                    value == 'all' ? null : value.toLowerCase();
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('All Documents'),
              ),
              const PopupMenuDivider(),
              ...DocumentType.values.map((type) => PopupMenuItem<String>(
                    value: type.toString().split('.').last.toLowerCase(),
                    child: Text(type.toString().split('.').last),
                  )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Folder path breadcrumb
          if (_folderPath.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedFolderId = null;
                          _folderPath = [];
                        });
                      },
                      child: const Text('Root'),
                    ),
                    ...List.generate(
                      _folderPath.length,
                      (index) {
                        // Build path up to this point
                        final pathUpToHere = _folderPath.sublist(0, index + 1);
                        return Row(
                          children: [
                            const Icon(Icons.chevron_right),
                            TextButton(
                              onPressed: () async {
                                // Navigate to this specific folder level
                                final user = _auth.currentUser;
                                if (user != null) {
                                  // Find the folder ID for this path
                                  QuerySnapshot folderQuery = await _firestore
                                      .collection('users')
                                      .doc(user.uid)
                                      .collection('folders')
                                      .where('name',
                                          isEqualTo: _folderPath[index])
                                      .get();

                                  if (folderQuery.docs.isNotEmpty) {
                                    setState(() {
                                      _selectedFolderId =
                                          folderQuery.docs.first.id;
                                      _folderPath = pathUpToHere;
                                    });
                                  }
                                }
                              },
                              child: Text(_folderPath[index]),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          // Folders and documents list
          Expanded(
            child: StreamBuilder<List<QuerySnapshot>>(
              stream: _combinedStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final folders = snapshot.data![0].docs;
                // Combine documents from all collections (starting from index 1)
                List<QueryDocumentSnapshot> allDocuments = [];
                for (int i = 1; i < snapshot.data!.length; i++) {
                  allDocuments.addAll(snapshot.data![i].docs);
                }

                if (folders.isEmpty && allDocuments.isEmpty) {
                  return const Center(
                    child: Text('No folders or documents found'),
                  );
                }

                return ListView(
                  children: [
                    // Folders
                    ...folders.map((folder) => ListTile(
                          leading: const Icon(Icons.folder),
                          title: Text(folder['name']),
                          onTap: () {
                            setState(() {
                              _selectedFolderId = folder.id;
                            });
                            _updateFolderPath();
                          },
                          trailing: PopupMenuButton(
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            onSelected: (value) {
                              switch (value) {
                                case 'create_subfolder':
                                  _createFolder(parentFolderId: folder.id);
                                  break;
                                case 'rename':
                                  _renameFolder(folder.id, folder['name']);
                                  break;
                                case 'delete':
                                  _deleteFolder(folder.id);
                                  break;
                              }
                            },
                          ),
                        )),

                    // Documents
                    ...allDocuments.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final fileName = data['name'] as String;
                      final fileSize = data['size'] as int;
                      final uploadDate =
                          (data['uploadedAt'] as Timestamp).toDate();
                      final documentType = data['documentType'] as String;
                      final pageCount =
                          data.containsKey('pageCount') ? data['pageCount'] : 0;

                      return ListTile(
                        leading: Icon(_getDocumentTypeIcon(documentType)),
                        title: Text(fileName),
                        subtitle: Text(
                          '${_formatFileSize(fileSize)} • ${DateFormat.yMMMd().format(uploadDate)}${pageCount > 0 ? ' • $pageCount pages' : ''}',
                        ),
                        onTap: () {
                          // Handle document opening based on type
                          if (documentType ==
                              DocumentType.pdf.toString().split('.').last) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Scaffold(
                                  appBar: AppBar(title: Text(fileName)),
                                  body: SfPdfViewer.network(data['fileUrl']),
                                ),
                              ),
                            );
                          } else {
                            // Launch URL or handle other document types
                          }
                        },
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Text('Rename'),
                            ),
                            const PopupMenuItem(
                              value: 'move',
                              child: Text('Move'),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                          onSelected: (value) {
                            switch (value) {
                              case 'rename':
                                _renameDocument(
                                    doc.id, fileName, data['fileUrl']);
                                break;
                              case 'move':
                                _moveDocumentToFolder(doc.id, data['folderId'],
                                    _getCollectionForDoc(data));
                                break;
                              case 'delete':
                                _deleteDocument(
                                    doc.id,
                                    data['fileUrl'],
                                    fileName,
                                    _getCollectionForDoc(
                                        data) // Pass the collection name
                                    );
                                break;
                            }
                          },
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: () => _createFolder(parentFolderId: _selectedFolderId),
            heroTag: 'createFolder',
            child: const Icon(Icons.create_new_folder),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            onPressed: _pickAndUploadFile,
            heroTag: 'uploadFile',
            child: const Icon(Icons.upload_file),
          ),
        ],
      ),
    );
  }

  IconData _getDocumentTypeIcon(String documentType) {
    switch (documentType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'word':
        return Icons.description;
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.audiotrack;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
