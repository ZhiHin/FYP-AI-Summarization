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
enum DocumentType {
  pdf,
  document,
  spreadsheet,
  presentation,
  images,
  audios,
  other
}

// Utility function to determine document type
DocumentType getDocumentType(String fileName) {
  final extension = path.extension(fileName).toLowerCase();
  switch (extension) {
    case '.pdf':
      return DocumentType.pdf;
    case '.docx':
    case '.doc':
      return DocumentType.document;
    case '.xlsx':
    case '.xls':
      return DocumentType.spreadsheet;
    case '.pptx':
    case '.ppt':
      return DocumentType.presentation;
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
      return DocumentType.other;
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
     _selectedDocumentType = widget.documentTypeFilter;
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

  Future<void> _loadDocuments() async {
    final user = _auth.currentUser;
    if (user != null) {
      Query query = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents');

      // Apply filter based on documentTypeFilter
      if (widget.documentTypeFilter == 'documents') {
        query = query.where('documentType', whereIn: documentTypes);
      } else if (widget.documentTypeFilter != null) {
        query = query.where('documentType', isEqualTo: widget.documentTypeFilter);
      }

      final documentsSnapshot = await query.get();
      final allDocuments = documentsSnapshot.docs.map((doc) => doc.data()).toList();

      setState(() {
        _filteredDocuments = allDocuments.cast<Map<String, dynamic>>();
        _selectedDocumentType = widget.documentTypeFilter; // Sync dropdown with filter
      });
    }
  }

static const List<String> documentTypes = [
  'pdf',
  'document',
  'spreadsheet',
  'presentation'
];

  // Stream that combines folders and documents
  Stream<List<QuerySnapshot>> get _combinedStream {
  final user = _auth.currentUser;
  if (user != null) {
    // Create folder query for current level only
    Query<Map<String, dynamic>> folderQuery =
        _firestore.collection('users').doc(user.uid).collection('folders');

    // Only show folders that belong to the current level
    if (_selectedFolderId == null) {
      folderQuery = folderQuery.where('parentFolderId', isNull: true);
    } else {
      folderQuery =
          folderQuery.where('parentFolderId', isEqualTo: _selectedFolderId);
    }

    // Create document query
    Query<Map<String, dynamic>> documentQuery =
        _firestore.collection('users').doc(user.uid).collection('documents');

    // Filter documents by folderId
    if (_selectedFolderId == null) {
      documentQuery = documentQuery.where('folderId', isNull: true);
    } else {
      documentQuery = documentQuery.where('folderId', isEqualTo: _selectedFolderId);
    }

    // Apply document type filter
      final effectiveFilter = _selectedDocumentType ?? widget.documentTypeFilter;
      
      if (effectiveFilter == 'documents') {
        documentQuery = documentQuery.where('documentType', whereIn: documentTypes);
      } else if (effectiveFilter != null) {
        documentQuery = documentQuery.where('documentType', isEqualTo: effectiveFilter);
      }

    return Rx.combineLatest2(
      folderQuery.snapshots(),
      documentQuery.snapshots(),
      (QuerySnapshot a, QuerySnapshot b) => [a, b],
    );
  } else {
    return const Stream.empty();
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
      String documentId, String? currentFolderId) async {
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
                  _updateDocumentFolder(documentId, null);
                  Navigator.pop(context);
                },
              ),
              ...foldersSnapshot.docs.map((folder) => ListTile(
                    leading: const Icon(Icons.folder),
                    title: Text(folder['name']),
                    onTap: () {
                      _updateDocumentFolder(documentId, folder.id);
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
      String documentId, String? folderId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
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

      final storageRef =
          FirebaseStorage.instance.ref().child('users/$userId/documents/');

      // Generate unique filename
      String fileName = originalFileName;
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

        final documentType = getDocumentType(fileName);

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
            .collection('documents')
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
  Future<void> _deleteDocument(
      String documentId, String fileUrl, String fileName) async {
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

      // Check for documents in folder
      final documents = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .where('folderId', isEqualTo: folderId)
          .get();

      if (subfolders.docs.isNotEmpty || documents.docs.isNotEmpty) {
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
                _selectedDocumentType = value == 'all' ? null : value;
              });
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'all',
                child: Text('All Documents'),
              ),
              ...DocumentType.values.map((type) => PopupMenuItem<String>(
                    value: type.toString().split('.').last,
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
                final documents = snapshot.data![1].docs;

                if (folders.isEmpty && documents.isEmpty) {
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
                    ...documents.map((doc) {
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
                        // subtitle: Text(
                        //   '${_formatFileSize(fileSize)} • ${DateFormat.yMMMd().format(uploadDate)}',
                        // ),
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
                                _moveDocumentToFolder(doc.id, data['folderId']);
                                break;
                              case 'delete':
                                _deleteDocument(
                                    doc.id, data['fileUrl'], fileName);
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
    switch (documentType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'document':
        return Icons.description;
      case 'spreadsheet':
        return Icons.table_chart;
      case 'presentation':
        return Icons.slideshow;
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
