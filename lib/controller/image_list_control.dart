import 'dart:io';
import 'package:ai_summarization/model/image_model.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ImageListControl {
  final ImageModel _imageModel = ImageModel();
  Future<void> deleteImage(
      BuildContext context, List<XFile> images, int index) async {
    try {
      // Show confirmation dialog
      bool? confirmDelete = await showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Delete Image'),
            content: const Text('Are you sure you want to delete this image?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      // If the user confirmed, delete the image
      if (confirmDelete == true) {
        // Get the current image path
        String currentPath = images[index].path;

        // Delete the file
        File(currentPath).deleteSync();

        // Remove the image from the list
        images.removeAt(index);
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      showSnackBar(context, "Error deleting image: $e");
    }
  }

  Future<String> renameXFile(BuildContext context, List<XFile> images,
      XFile file, String? newName) async {
    final directory = await getApplicationDocumentsDirectory();
    String fileName = newName ?? path.basename(file.path);
    List<String> existingFiles =
        images.map((img) => path.basename(img.path)).toList();

    int index = 1;
    while (existingFiles.contains(fileName)) {
      fileName =
          '${path.basenameWithoutExtension(fileName)}($index)${path.extension(fileName)}';
      index++;
    }
    if (index > 1) {
      showSnackBar(context, 'File renamed to $fileName');
    }

    final newFilePath = path.join(directory.path, fileName);
    final newFile = await File(file.path).copy(newFilePath);
    await File(file.path).delete();
    return newFile.path;
  }

  Future<void> uploadAllImagesToFirebase(
      BuildContext context, List<XFile> images) async {
    for (XFile image in images) {
      try {
        await _imageModel.uploadImageToFirebase(context, image);
      } catch (e) {
        showSnackBar(context, "Error uploading image: $e");
      }
    }
    showSnackBar(context, 'Images uploaded successfully');
    deleteAllImages(context, images);
  }

  Future<void> deleteAllImages(BuildContext context, List<XFile> images) async {
    for (XFile image in images) {
      try {
        File(image.path).deleteSync();
      } catch (e) {
        showSnackBar(context, "Error deleting image: $e");
      }
    }
    images.clear();
  }
}
