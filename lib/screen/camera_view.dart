import 'package:ai_summarization/controller/camera_control.dart';
import 'package:ai_summarization/screen/image_list_view.dart';
import 'package:ai_summarization/screen/image_preview.dart';
import 'package:ai_summarization/screen/upload_gallery.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraView extends StatefulWidget {
  final CameraController? controller;

  const CameraView({Key? key, this.controller}) : super(key: key);

  @override
  _CameraViewState createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  final CameraUIController _cameraUIController = CameraUIController();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _viewImages(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageListView(images: _cameraUIController.images),
      ),
    );
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
      showSnackBar(context, "Error Initializing Camera");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              switch (result) {
                case 'view':
                  _viewImages(context);
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'view',
                child: Text('Upload Images'),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          _isCameraInitialized
              ? Column(
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ],
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
        ],
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const SizedBox(width: 48), // Space for the custom round button
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.photo_library),
                  onPressed: () {
                    // Navigate to the gallery page
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UploadGallery()),
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 10.0,
            child: GestureDetector(
              onTap: () async {
                final image = await _cameraUIController.captureImage(
                    context, _controller!);
                if (image != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImagePreview(
                        image: image,
                        images: _cameraUIController.images,
                        onAddMoreImages: () async {
                          await _cameraUIController.addImages(image);
                        },
                      ),
                    ),
                  );
                } else {
                  showSnackBar(context, "Unable to capture image");
                }
              },
              child: Container(
                width: 56.0,
                height: 56.0,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
