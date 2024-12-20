import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

class FullImageView extends StatelessWidget {
  final String? imageUrl;
  final String? imagePath;
  const FullImageView({super.key, this.imageUrl, this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Center(
            child: PhotoView(
                imageProvider: imagePath != null
                    ? FileImage(File(imagePath!))
                    : NetworkImage(imageUrl!)),
          ),
          Positioned(
            top: 40,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ],
      ),
    );
  }
}
