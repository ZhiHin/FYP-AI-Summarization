import 'package:ai_summarization/model/image_model.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:flutter/material.dart';

class GalleryControl {
  final ImageModel _imageModel = ImageModel();

  Future<List<Map<String, dynamic>>> fetchImageData(
      BuildContext context) async {
    try {
      List<Map<String, dynamic>> imageData =
          await _imageModel.getImageData(context);
      return imageData;
    } catch (e) {
      showSnackBar(context, "Error fetching image data: $e");
      return [];
    }
  }
}
