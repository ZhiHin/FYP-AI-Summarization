import 'dart:io';
import 'package:ai_summarization/model/image_model.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';

class CameraUIController {
  final ImageModel _imageModel = ImageModel();
  final List<XFile> images = [];

  Future<XFile?> captureImage(
      BuildContext context, CameraController controller) async {
    if (!controller.value.isInitialized) {
      return null;
    }
    if (controller.value.isTakingPicture) {
      return null;
    }

    try {
      XFile image = await controller.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final newFilePath = path.join(
          directory.path,
          '${DateTime.now().millisecondsSinceEpoch}' +
              path.extension(image.path));
      final newFile = await File(image.path).copy(newFilePath);
      await File(image.path).delete();
      return XFile(newFile.path);
    } catch (e) {
      showSnackBar(context, "Error capturing image: $e");
      return null;
    }
  }

  Future<List<XFile>> addImages(XFile image) async {
    images.add(image);
    return images;
  }
}
