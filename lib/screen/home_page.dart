import 'package:flutter/material.dart';
import '../components/nav_button.dart';
import '../components/file_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<double> _dragOffsets = List.filled(5, 0.0); // Store drag offsets for each file card

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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Colors.blue),
                  SizedBox(width: 10),
                  Text("Search files...", style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Tools Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Tools",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text("View All"),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  NavButton(icon: Icons.picture_as_pdf, label: "PDF Tools"),
                  NavButton(icon: Icons.text_snippet, label: "Extract Text"),
                  NavButton(icon: Icons.summarize, label: "Document Summarize"),
                  NavButton(icon: Icons.image, label: "Import Images"),
                  NavButton(icon: Icons.folder, label: "Import Folders"),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // File Categories
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "All Files",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text("View All"),
                ),
              ],
            ),
            const Row(
              children: [
                FileCategoryCard(icon: Icons.folder, label: "Document", count: "58 Files"),
                SizedBox(width: 10),
                FileCategoryCard(icon: Icons.image, label: "Gallery", count: "46 Files"),
              ],
            ),
            const SizedBox(height: 20),
            // Recent Files Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Recents",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text("View All"),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      // Background with edit and delete buttons
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green, // Set background color to green
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, color: Colors.white),
                                      SizedBox(width: 15, height: 70),
                                      Text("Edit", style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              GestureDetector(
                                onTap: () => _handleDelete(index),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red, // Set background color to red
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.white),
                                      SizedBox(width: 5, height: 70),
                                      Text("Delete", style: TextStyle(color: Colors.white)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Foreground draggable card
                      Transform.translate(
                        offset: Offset(_dragOffsets[index], 0),
                        child: GestureDetector(
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _dragOffsets[index] += details.delta.dx;
                              if (_dragOffsets[index] > 0) _dragOffsets[index] = 0;
                              if (_dragOffsets[index] < -200) _dragOffsets[index] = -200;
                            });
                          },
                          onHorizontalDragEnd: (details) {
                            if (_dragOffsets[index] < -100) {
                              // Stay open if dragged far enough
                            } else {
                              setState(() => _dragOffsets[index] = 0);
                            }
                          },
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
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // floatingActionButton: FloatingActionButton(
      //   onPressed: () {
      //     // Handle action button tap
      //   },
      //   backgroundColor: Colors.blue,
      //   child: const Icon(Icons.add),
      // ),
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
                Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text(count, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
