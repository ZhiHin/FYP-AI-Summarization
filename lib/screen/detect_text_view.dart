import 'package:ai_summarization/controller/detect_text_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:ai_summarization/screen/summarize_ocr_view.dart';
import 'package:flutter/material.dart';

class DetectTextView extends StatefulWidget {
  final List<String> imageUrls;

  const DetectTextView({super.key, required this.imageUrls});

  @override
  _DetectTextViewState createState() => _DetectTextViewState();
}

class _DetectTextViewState extends State<DetectTextView> {
  final _control = DetectTextControl();
  final List<TextEditingController> _textControllers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeTextControllers();
  }

  @override
  void dispose() {
    for (var controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _initializeTextControllers() async {
    for (var url in widget.imageUrls) {
      final text = await _control.generateFormatTextFromImage(url);
      _textControllers.add(TextEditingController(text: text));
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSplitTextView() {
    return PageView.builder(
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        return SingleChildScrollView(
          child: Column(
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
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _textControllers[index],
                  maxLines: null,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    labelText: 'Page ${index + 1}',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detect Text View'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'save') {
                _control.saveOriginal();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'save',
                child: Text('Save'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _buildSplitTextView(),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: _navigateToSummarize,
                    child: const Text('Summarize'),
                  ),
                ),
              ],
            ),
    );
  }
}
