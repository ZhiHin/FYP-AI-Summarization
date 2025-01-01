import 'dart:io';
import 'package:ai_summarization/screen/utils.dart';
import 'package:blur_detection/blur_detection.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:camera/camera.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

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
    final bool isBlurred = await _isImageBlurred(File(image.path));
    if (!isBlurred) {
      images.add(image);
    } else {
      showSnackBar(context, "Image is too blurry, please retake the picture");
    }

    return images;
  }

  Future<bool> _isImageBlurred(File imageFile) async {
    final img = imageFile.path;
    final mat = await cv.imread(img);
    final laplacian = await cv.laplacian(mat, cv.MatType.CV_64F).variance();
    print(laplacian);
    print(laplacian.val[0]);
    const double threshold = 100;
    return laplacian.val[0] < threshold;
  }
}
