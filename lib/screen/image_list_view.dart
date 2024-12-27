import 'dart:io';
import 'package:ai_summarization/controller/image_list_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
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
          title: const Text('Clear All Images'),
          content: const Text('Are you sure you want to clear all images?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Clear'),
              onPressed: () {
                Navigator.of(context).pop(true);
              },
            ),
          ],
        );
      },
    );

    if (confirmClear == true) {
      setState(() {
        widget.control.deleteAllImages(context, widget.images);
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
          title: const Text('Rename Image'),
          content: Row(children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Enter new name'),
              ),
            ),
            Text(fileExtension),
          ]),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Rename'),
              onPressed: () {
                Navigator.of(context).pop(controller.text);
              },
            ),
          ],
        );
      },
    );

    if (newName != null && newName.isNotEmpty) {
      String newPath = await widget.control
          .renameXFile(context, widget.images, widget.images[index], newName);
      setState(() {
        widget.images[index] = XFile(newPath);
      });
    }
    return newName ?? '${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image List'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              switch (result) {
                case 'clear':
                  _confirmClearImages();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'clear',
                child: Text('Clear List'),
              ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.images.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: GestureDetector(
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
              child: Image.file(File(widget.images[index].path)),
            ),
            title: Text(widget.images[index].name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    _renameImage(index);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _deleteImage(index),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ElevatedButton(
          onPressed: () =>
              widget.control.uploadAllImagesToFirebase(context, widget.images),
          child: const Text('Upload Images'),
        ),
      ),
    );
  }
}
