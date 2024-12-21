import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import '../components/folder_card.dart';
import '../components/nav_button.dart';
import '../components/file_card.dart';
import 'package:intl/intl.dart';

import 'translate.dart';

class HomePage extends StatefulWidget {
  final Function(int, {String? documentTypeFilter}) onNavigateToPage;

  const HomePage({super.key, required this.onNavigateToPage});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<Map<String, dynamic>> _recentFiles = [];
  Map<String, int> _fileCounts = {
    'documents': 0,
    'images': 0,
    'audios': 0,
  };
  final List<double> _dragOffsets = List.filled(5, 0.0);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    await Future.wait([
      _loadRecentFiles(),
      _loadFileCounts(),
    ]);
  }

  Future<void> _loadRecentFiles() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Fetch recent files from each collection with a larger limit
        final docSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('documents')
            .orderBy('uploadedAt', descending: true)
            .limit(
                20) // Increased limit to ensure we get enough documents to compare
            .get();

        final imageSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('images')
            .orderBy('uploadedAt', descending: true)
            .limit(20) // Increased limit
            .get();

        final audioSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('audios')
            .orderBy('uploadedAt', descending: true)
            .limit(20) // Increased limit
            .get();

        // Combine all files with their timestamps
        final allRecentFiles = [
          ...docSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'type': 'documents',
              'name': data['name'] ?? 'Unnamed Document',
              'uploadedAt': data['uploadedAt'] ?? Timestamp.now(),
              'pageCount': data['pageCount'] ?? 0,
            };
          }),
          ...imageSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'type': 'images',
              'name': data['name'] ?? 'Unnamed Image',
              'uploadedAt': data['uploadedAt'] ?? Timestamp.now(),
            };
          }),
          ...audioSnapshot.docs.map((doc) {
            final data = doc.data();
            return {
              ...data,
              'id': doc.id,
              'type': 'audios',
              'name': data['name'] ?? 'Unnamed Audio',
              'uploadedAt': data['uploadedAt'] ?? Timestamp.now(),
            };
          }),
        ];

        // Sort all files by uploadedAt timestamp
        allRecentFiles.sort((a, b) {
          final aTime = (a['uploadedAt'] as Timestamp).toDate();
          final bTime = (b['uploadedAt'] as Timestamp).toDate();
          return bTime.compareTo(aTime); // Most recent first
        });

        // Take only the 5 most recent files
        setState(() {
          _recentFiles = allRecentFiles.take(5).toList();
        });
      }
    } catch (e) {
      _showError("Error loading recent files: $e");
    }
  }

  Future<void> _loadFileCounts() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final counts = await Future.wait([
          _getCollectionCount(user.uid, 'documents'),
          _getCollectionCount(user.uid, 'images'),
          _getCollectionCount(user.uid, 'audios'),
        ]);

        setState(() {
          _fileCounts = {
            'documents': counts[0],
            'images': counts[1],
            'audios': counts[2],
          };
        });
      }
    } catch (e) {
      _showError("Error loading file counts: $e");
    }
  }

  Future<int> _getCollectionCount(String userId, String collection) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection(collection)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _handleEdit(int index) async {
    try {
      final user = _auth.currentUser;
      if (user != null && index < _recentFiles.length) {
        final file = _recentFiles[index];
        final fileId = file['id'];
        final fileType = file['type'];

        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection(fileType)
            .doc(fileId)
            .update({
          'lastEdited': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File ${index + 1} updated")),
        );
      }
    } catch (e) {
      _showError("Error updating file: $e");
    }
  }

  Future<void> _handleDelete(int index) async {
    try {
      final user = _auth.currentUser;
      if (user != null && index < _recentFiles.length) {
        final file = _recentFiles[index];
        final fileId = file['id'];
        final fileName = file['name'];
        final fileType = file['type'];

        // Delete from Firestore
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection(fileType)
            .doc(fileId)
            .delete();

        // Delete from Storage
        await _storage.ref('users/${user.uid}/$fileType/$fileName').delete();

        setState(() {
          _recentFiles.removeAt(index);
          _fileCounts[fileType] = (_fileCounts[fileType] ?? 0) - 1;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("File ${index + 1} deleted")),
        );
      }
    } catch (e) {
      _showError("Error deleting file: $e");
    }
  }

  Future<void> _handleSearch(String query) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Search in all collections
        final docSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('documents')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

        final imageSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('images')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

        final audioSnapshot = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('audios')
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

        final searchResults = [
          ...docSnapshot.docs.map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'type': 'documents',
              }),
          ...imageSnapshot.docs.map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'type': 'images',
              }),
          ...audioSnapshot.docs.map((doc) => {
                ...doc.data(),
                'id': doc.id,
                'type': 'audios',
              }),
        ];

        setState(() {
          _recentFiles = searchResults;
        });
      }
    } catch (e) {
      _showError("Error searching files: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "Home",
          style: TextStyle(color: Colors.black),
        ),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.logout, color: Colors.black),
        //     onPressed: () async {
        //       await _auth.signOut();
        //       // Navigate to login screen
        //     },
        //   ),
        // ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.blue),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: _handleSearch,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Search files...",
                          hintStyle: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Folder Cards Section
          SliverToBoxAdapter(
            child: SizedBox(
              height: 150,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  GestureDetector(
                    onTap: () => widget.onNavigateToPage(1,
                        documentTypeFilter: 'documents'),
                    child: FolderCard(
                      icon: Icons.description,
                      label: "DOCUMENTS",
                      count: "${_fileCounts['documents']} Files",
                      color: Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => widget.onNavigateToPage(1,
                        documentTypeFilter: 'images'),
                    child: FolderCard(
                      icon: Icons.image,
                      label: "IMAGES",
                      count: "${_fileCounts['images']} Files",
                      color: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => widget.onNavigateToPage(1,
                        documentTypeFilter: 'audios'),
                    child: FolderCard(
                      icon: Icons.audiotrack,
                      label: "AUDIO",
                      count: "${_fileCounts['audios']} Files",
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
          //Tools Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Tools",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateToPage(3),
                        child: const Text("View All"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          // Tools Horizontal List
          SliverToBoxAdapter(
            child: SizedBox(
              height: 85,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  NavButton(
                    icon: Icons.translate,
                    label: "Translate",
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const TranslateScreen()),
                    ),
                  ),
                  NavButton(
                    icon: Icons.picture_as_pdf,
                    label: "PDF Tools",
                  ),
                  NavButton(
                    icon: Icons.text_snippet,
                    label: "Extract Text",
                  ),
                  NavButton(
                    icon: Icons.summarize,
                    label: "Document Summarize",
                  ),
                  NavButton(
                    icon: Icons.image,
                    label: "Import Images",
                  ),
                  NavButton(
                    icon: Icons.folder,
                    label: "Import Folders",
                  ),
                  SizedBox(width: 8),
                ],
              ),
            ),
          ),
          // Recent Files Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recent Files",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateToPage(1),
                        child: const Text("View All"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Recent Files List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= _recentFiles.length) return null;
                  final file = _recentFiles[index];

                  return Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          color: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.centerRight,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTap: () => _handleEdit(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.white),
                                      SizedBox(width: 15, height: 70),
                                      Text("Edit",
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              GestureDetector(
                                onTap: () => _handleDelete(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.white),
                                      SizedBox(width: 5, height: 70),
                                      Text("Delete",
                                          style:
                                              TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(_dragOffsets[index], 0),
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _dragOffsets[index] += details.delta.dx;
                              if (_dragOffsets[index] > 0) {
                                _dragOffsets[index] = 0;
                              }
                              if (_dragOffsets[index] < -200) {
                                _dragOffsets[index] = -200;
                              }
                            });
                          },
                          onHorizontalDragEnd: (details) {
                            if (_dragOffsets[index] > -100) {
                              setState(() => _dragOffsets[index] = 0);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: FileCard(
                              fileName: file['name'] ?? '',
                              date: DateFormat('dd-MM-yyyy').format(
                                  (file['uploadedAt'] as Timestamp).toDate()),
                              time: DateFormat('HH:mm:ss').format(
                                  (file['uploadedAt'] as Timestamp).toDate()),
                              pages: (file['pageCount']?.toString()) ?? '0',
                              onEdit: () => _handleEdit(index),
                              onDelete: () => _handleDelete(index),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                childCount: _recentFiles.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}

// Custom Widget for File Categories
class FileCategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;

  const FileCategoryCard({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                Text(count, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
