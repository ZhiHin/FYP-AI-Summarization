import 'package:ai_summarization/controller/camera_control.dart';
import 'package:ai_summarization/screen/image_list_view.dart';
import 'package:ai_summarization/screen/image_preview.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraView extends StatefulWidget {
  const CameraView({super.key});

  @override
  CameraViewState createState() => CameraViewState();
}

class CameraViewState extends State<CameraView> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? cameras;
  bool _isCameraInitialized = false;
  bool _isRearCameraSelected = true;
  bool _isFlashOn = false;
  final CameraUIController _cameraUIController = CameraUIController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
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
        final camera = _isRearCameraSelected ? cameras!.first : cameras!.last;
        _controller = CameraController(
          camera,
          ResolutionPreset.veryHigh,
          enableAudio: false,
        );
        await _controller!.initialize();
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      showSnackBar(context, "Error Initializing Camera");
    }
  }

  Future<void> _toggleCamera() async {
    setState(() {
      _isRearCameraSelected = !_isRearCameraSelected;
      _isCameraInitialized = false;
    });
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_controller?.value.isInitialized ?? false) {
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
      await _controller?.setFlashMode(
        _isFlashOn ? FlashMode.torch : FlashMode.off,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Camera Preview
            if (_isCameraInitialized)
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),

            // Top Controls
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleFlash,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.flip_camera_ios,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleCamera,
                  ),
                ],
              ),
            ),

            // Bottom Controls
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(20),
                color: Colors.black.withOpacity(0.5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32),
                    GestureDetector(
                      onTap: () async {
                        if (!_isCameraInitialized) return;

                        try {
                          final image = await _cameraUIController.captureImage(
                            context,
                            _controller!,
                          );
                          if (image != null && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ImagePreview(
                                  image: image,
                                  images: _cameraUIController.images,
                                  onAddMoreImages: () async {
                                    await _cameraUIController.addImages(
                                      context,
                                      image,
                                    );
                                  },
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          showSnackBar(context, "Failed to capture image");
                        }
                      },
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 4,
                          ),
                          color: Colors.white.withOpacity(0.5),
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.collections,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () => _viewImages(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
