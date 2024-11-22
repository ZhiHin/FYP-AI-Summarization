import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class ImagePreview extends StatelessWidget {
  final XFile file;
  final Function onConfirm;

  const ImagePreview({required this.file, required this.onConfirm, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Preview Image'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Image.file(File(file.path)),
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
                onPressed: () async {
                  await onConfirm();
                  Navigator.pop(context);
                },
                child: const Text('Confirm'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
