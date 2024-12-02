import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ImagePreview extends StatelessWidget {
  final XFile image;
  final List<XFile> images;
  final Function onAddMoreImages;

  ImagePreview({
    required this.image,
    required this.images,
    required this.onAddMoreImages,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Image'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Image.file(File(image.path)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Retake'),
              ),
              ElevatedButton(
                onPressed: () => {onAddMoreImages(), Navigator.pop(context)},
                child: const Text('Add Image'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
