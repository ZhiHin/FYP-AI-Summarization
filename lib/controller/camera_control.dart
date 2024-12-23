import 'dart:io';
import 'package:ai_summarization/screen/utils.dart';
import 'package:blur_detection/blur_detection.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';

class CameraUIController {
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
      final newFilePath = path.join(directory.path,
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(image.path)}');
      final newFile = await File(image.path).copy(newFilePath);
      await File(image.path).delete();
      return XFile(newFile.path);
    } catch (e) {
      showSnackBar(context, "Error capturing image: $e");
      return null;
    }
  }

  Future<List<XFile>> addImages(BuildContext context, XFile image) async {
    final bool isBlurred =
        await BlurDetectionService.isImageBlurred(File(image.path));
    if (!isBlurred) {
      images.add(image);
    } else {
      showSnackBar(context, "Image is too blurry, please retake the picture");
    }

    return images;
  }
}
