import 'dart:io';
import 'dart:typed_data';

import 'package:ai_summarization/screen/detect_text_view.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class CropImagePage extends StatefulWidget {
  final List<String> imageUrls;

  const CropImagePage({Key? key, required this.imageUrls}) : super(key: key);

  @override
  _CropImagePageState createState() => _CropImagePageState();
}

class _CropImagePageState extends State<CropImagePage> {
  List<CroppedFile?> _croppedFiles = [];
  List<bool> currentCropProgress = [];
  int _currentIndex = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (mounted) {
      _croppedFiles = List.filled(widget.imageUrls.length, null);
      currentCropProgress = List.filled(widget.imageUrls.length, false);
      _cropImage(_currentIndex);
    }
  }

  Future<void> _cropImage(int index) async {
    setState(() => _isLoading = true);
    try {
      // Download the image from the URL
      final response = await http.get(Uri.parse(widget.imageUrls[index]));
      final Uint8List bytes = response.bodyBytes;

      // Get the directory for storing the image
      final directory = await getExternalStorageDirectory();
      final projectDir = Directory('${directory?.path}/MyProjectImages');
      if (!await projectDir.exists()) {
        await projectDir.create(recursive: true);
      }

      // Create a temporary file with a timestamped name
      final timeStamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final imageFileName = 'JPEG_$timeStamp.jpg';
      final tempFile = File('${projectDir.path}/temp_image_$index.jpg');
      await tempFile.writeAsBytes(bytes);

      // Crop the image
      if (mounted) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: tempFile.path,
          compressFormat: ImageCompressFormat.jpg,
          compressQuality: 90,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle:
                  'Crop Image ${index + 1}/${widget.imageUrls.length}',
              toolbarColor: Theme.of(context).primaryColor,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false,
              hideBottomControls: true,
              showCropGrid: true,
            ),
          ],
        );

        if (croppedFile != null) {
          final croppedFilePath = '${projectDir.path}/CROPPED_$imageFileName';
          final croppedFileBytes = await File(croppedFile.path).readAsBytes();
          final savedCroppedFile = File(croppedFilePath);
          await savedCroppedFile.writeAsBytes(croppedFileBytes);

          setState(() {
            _croppedFiles[index] = CroppedFile(croppedFilePath);
            currentCropProgress[index] = true;
            print("test" + _croppedFiles.length.toString());
          });
        }
      }
      await tempFile.delete();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing image: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forwardImages() async {
    final croppedImagePaths = _croppedFiles
        .where((file) => file != null)
        .map((file) => file!.path)
        .toList();

    if (croppedImagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please crop at least one image')),
      );
      return;
    }

    if (currentCropProgress.length == widget.imageUrls.length &&
        currentCropProgress.every((progress) => progress)) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DetectTextView(
            croppedImagesPath: croppedImagePaths,
            imageUrls: widget.imageUrls,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete cropping all images')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Crop Images (${_currentIndex + 1}/${widget.imageUrls.length})'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _forwardImages,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                itemCount: widget.imageUrls.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                    if (_croppedFiles[index] == null) {
                      _cropImage(index);
                    }
                  });
                },
                itemBuilder: (context, index) {
                  return Center(
                    child: _isLoading && _croppedFiles[index] == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Processing image...'),
                            ],
                          )
                        : _croppedFiles[index] != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Image.file(
                                      File(_croppedFiles[index]!.path),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  if (widget.imageUrls.length > 1 &&
                                      index != widget.imageUrls.length - 1)
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'Swipe to crop next image',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge,
                                      ),
                                    ),
                                ],
                              )
                            : const CircularProgressIndicator(),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  if (_currentIndex > 0)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentIndex--;
                          _cropImage(_currentIndex);
                        });
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Previous'),
                    )
                  else
                    const SizedBox(width: 0), // Placeholder to maintain spacing
                  const Spacer(),
                  if (_currentIndex < widget.imageUrls.length - 1)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _currentIndex++;
                          _cropImage(_currentIndex);
                        });
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next'),
                    )
                  else
                    const SizedBox(width: 0), // Placeholder to maintain spacing
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
