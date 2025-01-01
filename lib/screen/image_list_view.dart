import 'dart:io';
import 'package:ai_summarization/controller/image_list_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart' as path;

class ImageListView extends StatefulWidget {
  final List<XFile> images;
  final ImageListControl control = ImageListControl();

  ImageListView({Key? key, required this.images}) : super(key: key);

  @override
  _ImageListViewState createState() => _ImageListViewState();
}

class _ImageListViewState extends State<ImageListView> {
  void _deleteImage(int index) async {
    await widget.control.deleteImage(context, widget.images, index);
    setState(() {});
  }

  Future<void> _confirmClearImages() async {
    bool? confirmClear = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Clear All Images',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Are you sure you want to clear all images?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'Clear',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmClear == true) {
      setState(() {
        widget.control.deleteAllImages(context, widget.images);
        showSnackBar(context, 'Images cleared');
      });
    }
  }

  Future<String> _renameImage(int index) async {
    TextEditingController controller = TextEditingController();
    String fileExtension = path.extension(widget.images[index].path);
    String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Rename Image',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter new name',
              hintStyle: const TextStyle(color: Colors.white54),
              suffix: Text(fileExtension,
                  style: const TextStyle(color: Colors.white70)),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Theme.of(context).primaryColor),
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Rename',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
              onPressed: () => Navigator.of(context).pop(controller.text),
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      String newPath = await widget.control.renameXFile(
        context,
        widget.images,
        widget.images[index],
        newName,
      );
      setState(() {
        widget.images[index] = XFile(newPath);
      });
    }
    return newName ?? '${DateTime.now().millisecondsSinceEpoch}';
  }

  void _showImageOptions(int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.white),
                title: const Text(
                  'Rename',
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _renameImage(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteImage(index);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.images.length} Photos',
        ),
        elevation: 0,
        actions: [
          if (widget.images.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.black),
              onPressed: _confirmClearImages,
            ),
        ],
      ),
      body: widget.images.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 64,
                    color: Colors.grey[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No photos yet',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullImageView(
                          imagePath: widget.images[index].path,
                        ),
                      ),
                    );
                  },
                  onLongPress: () => _showImageOptions(index),
                  child: Hero(
                    tag: widget.images[index].path,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        image: DecorationImage(
                          image: FileImage(File(widget.images[index].path)),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: widget.images.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                try {
                  await widget.control
                      .uploadAllImagesToFirebase(context, widget.images);
                  showSnackBar(context, 'Uploading images...');
                  setState(() {
                    widget.images.clear(); // Clear the images list
                  });
                } catch (e) {
                  showSnackBar(context, 'Failed to upload images: $e');
                }
              },
              icon: const Icon(
                Icons.cloud_upload,
                color: Colors.white, // Set the icon color to white
              ),
              label: const Text(
                'Upload All',
                style:
                    TextStyle(color: Colors.white), // Set text color to white
              ),
              backgroundColor: Theme.of(context).primaryColor,
            )
          : null,
    );
  }
}
