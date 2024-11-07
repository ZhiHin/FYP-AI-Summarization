import 'package:flutter/material.dart';
import '../components/folder_card.dart';
import '../components/nav_button.dart';
import '../components/file_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<double> _dragOffsets =
      List.filled(5, 0.0); // Store drag offsets for each file card

  void _handleEdit(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Edit clicked for File ${index + 1}")),
    );
  }

  void _handleDelete(int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Delete clicked for File ${index + 1}")),
    );
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
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search, color: Colors.blue),
                        SizedBox(width: 10),
                        Text("Search files...",
                            style: TextStyle(color: Colors.blue)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          // Folder Cards Section
          SliverToBoxAdapter(
            child: SizedBox(
              height: 150, // Adjust height as needed
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: const [
                  FolderCard(
                    icon: Icons.folder,
                    label: "DOCUMENTS",
                    count: "58 Files",
                    color: Colors.orangeAccent,
                  ),
                  SizedBox(width: 10),
                  FolderCard(
                    icon: Icons.image,
                    label: "IMAGES",
                    count: "36 Files",
                    color: Colors.greenAccent,
                  ),
                  SizedBox(width: 10),
                  FolderCard(
                    icon: Icons.picture_as_pdf,
                    label: "PDFs",
                    count: "120 Files",
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ),
          ),
          // Tools Section
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
                        onPressed: () {},
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
              height:
                  85, // Height that accommodates both icon and two lines of text
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: const [
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
                  SizedBox(width: 8), // Right padding
                ],
              ),
            ),
          ),
          // File Categories Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "All Files",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text("View All"),
                      ),
                    ],
                  ),
                  const Row(
                    children: [
                      FileCategoryCard(
                        icon: Icons.folder,
                        label: "Document",
                        count: "58 Files",
                      ),
                      SizedBox(width: 10),
                      FileCategoryCard(
                        icon: Icons.image,
                        label: "Gallery",
                        count: "46 Files",
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Recents",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {},
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
                              fileName: "Example ${index + 1}.pdf",
                              date: "12-09-2024",
                              time: "15:30",
                              pages: "12 Pages",
                              onEdit: () => _handleEdit(index),
                              onDelete: () => _handleDelete(index),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                childCount: 5,
              ),
            ),
          ),
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80), // Space for FloatingActionButton
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
