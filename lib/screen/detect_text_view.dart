import 'package:ai_summarization/controller/detect_text_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:ai_summarization/screen/summarize_ocr_view.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:flutter/material.dart';

class DetectTextView extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> croppedImagesPath;

  const DetectTextView({
    super.key,
    required this.croppedImagesPath,
    required this.imageUrls,
  });

  @override
  _DetectTextViewState createState() => _DetectTextViewState();
}

class _DetectTextViewState extends State<DetectTextView> {
  final _control = DetectTextControl();
  final List<TextEditingController> _textControllers = [];
  bool _isLoading = true;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedOption = 'format';
  String type = 'prompt';
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _initializeTextControllers();
  }

  @override
  void dispose() {
    _isDisposed = true;
    for (var controller in _textControllers) {
      controller.dispose();
    }
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeTextControllers() async {
    try {
      setState(() => _isLoading = true);

      for (var imagePath in widget.croppedImagesPath) {
        if (_isDisposed) return;

        final text = await _control.generateFormatTextFromImage(
          imagePath,
          _selectedOption,
          true,
        );

        if (_isDisposed) return;

        _textControllers.add(TextEditingController(text: text));
      }

      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
        showSnackBar(context, "Error processing images: $e");
      }
    }
  }

  void _navigateToSummarize() {
    List<String> detectedTexts = [];
    for (var controller in _textControllers) {
      detectedTexts.add(controller.text);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SummarizeOcrView(
          imageUrls: widget.imageUrls,
          detectedTexts: detectedTexts,
        ),
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          widget.imageUrls.length,
          (index) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 8,
            width: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index == _currentPage
                  ? Theme.of(context).primaryColor
                  : Colors.grey.shade300,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitTextView() {
    return Stack(
      children: [
        Column(
          children: [
            _buildPageIndicator(),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.imageUrls.length,
                itemBuilder: (context, index) {
                  if (index >= _textControllers.length) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FullImageView(
                                            imageUrl: widget.imageUrls[index],
                                          ),
                                        ),
                                      );
                                    },
                                    child: AspectRatio(
                                      aspectRatio: 16 / 9,
                                      child: Image.network(
                                        widget.imageUrls[index],
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, progress) {
                                          if (progress == null) return child;
                                          return Center(
                                            child: CircularProgressIndicator(
                                              value: progress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? progress
                                                          .cumulativeBytesLoaded /
                                                      progress
                                                          .expectedTotalBytes!
                                                  : null,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: IconButton(
                                      icon: const Icon(Icons.fullscreen),
                                      color: Colors.white,
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FullImageView(
                                              imageUrl: widget.imageUrls[index],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Card(
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Detected Text - Page ${index + 1}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _textControllers[index],
                                    maxLines: null,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey.shade50,
                                    ),
                                    style: const TextStyle(height: 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                onPageChanged: (index) => setState(() => _currentPage = index),
              ),
            ),
          ],
        ),
        if (_currentPage > 0)
          Positioned(
            left: 8,
            top: MediaQuery.of(context).size.height / 2,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios),
              ),
              onPressed: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        if (_currentPage < widget.imageUrls.length - 1)
          Positioned(
            right: 8,
            top: MediaQuery.of(context).size.height / 2,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_forward_ios),
              ),
              onPressed: () {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _showSaveDialog() async {
    TextEditingController nameController = TextEditingController();
    List<String> detectedTexts = _textControllers.map((c) => c.text).toList();
    print(detectedTexts);
    if (_isLoading) {
      showSnackBar(context, "No text detected");
      return;
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Save Detected Text'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter a name for the saved data:'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        hintText: 'Name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                FilledButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    try {
                      await _control.saveOriginal(
                        widget.imageUrls,
                        detectedTexts,
                        nameController.text,
                        type,
                      );
                      showSnackBar(context, "Prompt saved successfully");
                      Navigator.of(context).pop();
                    } catch (e) {
                      showSnackBar(context, "Error saving prompt: $e");
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Detection'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _showSaveDialog,
            tooltip: 'Save',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing images...'),
                ],
              ),
            )
          : _buildSplitTextView(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton(
            onPressed: _navigateToSummarize,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Summarize Text'),
          ),
        ),
      ),
    );
  }
}
