import 'dart:io';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:flutter/material.dart';
import 'package:ai_summarization/controller/gallery_tool_control.dart';
import 'detect_text_view.dart'; // Import the DetectText screen

class GalleryView extends StatefulWidget {
  @override
  _GalleryViewState createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  final GalleryControl _galleryControl = GalleryControl();
  List<Map<String, dynamic>> _imageData = [];
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchImageData();
  }

  Future<void> _fetchImageData() async {
    List<Map<String, dynamic>> imageData =
        await _galleryControl.fetchImageData(context);
    setState(() {
      _imageData = imageData;
    });
    // Print out the contents of _imageData
    print(_imageData);
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _uploadSelectedImages() {
    List<Map<String, dynamic>> selectedImages =
        _selectedIndices.map((index) => _imageData[index]).toList();
    List<String> selectedImageUrls =
        selectedImages.map((image) => image['imageUrl'] as String).toList();
    if (selectedImages.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetectTextView(imageUrls: selectedImageUrls),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedIndices.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _imageData.isEmpty
                ? const Center(child: Text('No images available'))
                : ListView.builder(
                    itemCount: _imageData.length,
                    itemBuilder: (context, index) {
                      String imageUrl = _imageData[index]['imageUrl']!;
                      String imageName = _imageData[index]['name']!;
                      bool isSelected = _selectedIndices.contains(index);
                      return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _selectionMode = true;
                            _toggleSelection(index);
                          });
                        },
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(index);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FullImageView(
                                  imageUrl: imageUrl,
                                ),
                              ),
                            );
                          }
                        },
                        child: ListTile(
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_selectionMode)
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (bool? value) {
                                    _toggleSelection(index);
                                  },
                                ),
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              ),
                            ],
                          ),
                          title: Text(imageName),
                        ),
                      );
                    },
                  ),
          ),
          if (_selectedIndices.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8.0),
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.upload),
                label: const Text('Upload Selected Images'),
                onPressed: _uploadSelectedImages,
              ),
            ),
        ],
      ),
    );
  }
}
