import 'dart:io';
import 'package:ai_summarization/screen/crop_image_view.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:flutter/material.dart';
import 'package:ai_summarization/controller/gallery_tool_control.dart';
import 'detect_text_view.dart';

class GalleryView extends StatefulWidget {
  @override
  _GalleryViewState createState() => _GalleryViewState();
}

class _GalleryViewState extends State<GalleryView> {
  final GalleryControl _galleryControl = GalleryControl();
  List<Map<String, dynamic>> _imageData = [];
  Set<int> _selectedIndices = {};
  bool _selectionMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchImageData();
  }

  Future<void> _fetchImageData() async {
    setState(() => _isLoading = true);
    try {
      List<Map<String, dynamic>> imageData =
          await _galleryControl.fetchImageData(context);
      setState(() {
        _imageData = imageData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading images: $e')),
      );
    }
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
        if (_selectedIndices.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  void _uploadSelectedImages() {
    if (_selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one image')),
      );
      return;
    }

    List<String> selectedImageUrls = _selectedIndices
        .map((index) => _imageData[index]['fileUrl'] as String)
        .toList();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropImagePage(imageUrls: selectedImageUrls),
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
        title: Text(
            _selectionMode ? '${_selectedIndices.length} Selected' : 'Gallery'),
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSelection,
              tooltip: 'Clear selection',
            ),
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: _uploadSelectedImages,
              tooltip: 'Upload selected',
            ),
          ]
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchImageData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _imageData.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_library_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text(
                          'No images available',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        TextButton(
                          onPressed: _fetchImageData,
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _imageData.length,
                    itemBuilder: (context, index) {
                      String imageUrl = _imageData[index]['fileUrl']!;
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
                                    imageUrl: imageUrl, imageName: imageName),
                              ),
                            );
                          }
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return const Center(
                                          child: Icon(
                                            Icons.error_outline,
                                            color: Colors.red,
                                          ),
                                        );
                                      },
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.bottomCenter,
                                            end: Alignment.topCenter,
                                            colors: [
                                              Colors.black.withOpacity(0.7),
                                              Colors.transparent,
                                            ],
                                          ),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        child: Text(
                                          imageName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_selectionMode)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).primaryColor
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.check,
                                      size: 16,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: _selectionMode
          ? FloatingActionButton.extended(
              onPressed: _uploadSelectedImages,
              icon: const Icon(Icons.upload),
              label: const Text('Upload'),
            )
          : null,
    );
  }
}
