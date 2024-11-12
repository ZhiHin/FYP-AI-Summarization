import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class CameraCapture extends StatefulWidget {
  @override
  _CameraCaptureState createState() => _CameraCaptureState();
}

class _CameraCaptureState extends State<CameraCapture> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras != null && cameras!.isNotEmpty) {
        _controller = CameraController(cameras![0], ResolutionPreset.high);
        await _controller!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _saveImage(XFile image) async {
    try {
      final directory = await getExternalStorageDirectory();
      final String path =
          '${directory!.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File newImage = await File(image.path).copy(path);
      print('Image saved to: ${newImage.path}');
    } catch (e) {
      print('Error saving image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Camera Capture'),
      ),
      body: _isCameraInitialized
          ? CameraPreview(_controller!)
          : Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_controller != null && _controller!.value.isInitialized) {
            try {
              final image = await _controller!.takePicture();
              await _saveImage(image);
            } catch (e) {
              print('Error capturing image: $e');
            }
          }
        },
        child: Icon(Icons.camera),
      ),
    );
  }
}
