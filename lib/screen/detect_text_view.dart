import 'package:ai_summarization/controller/detect_text_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:ai_summarization/screen/summarize_ocr_view.dart';
import 'package:ai_summarization/screen/utils.dart';
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
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _selectedLanguage = 'en';
  String _selectedOption = 'format'; // Default selected option

  @override
  void initState() {
    super.initState();
    _initializeTextControllers();
  }

  Future<void> _initializeTextControllers() async {
    for (var url in widget.imageUrls) {
      final text =
          await _control.generateFormatTextFromImage(url, _selectedOption);
      _textControllers.add(TextEditingController(text: text));
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSplitTextView() {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
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
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      DropdownButton<String>(
                        value: _selectedOption,
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedOption = newValue!;
                            _textControllers.clear();
                            _initializeTextControllers();
                          });
                        },
                        items: <String>['format', 'fine-grained']
                            .map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ],
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
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
              print('Page changed to: $_currentPage'); // Debug print
            });
          },
        ),
        if (_currentPage > 0)
          Positioned(
            left: 16.0,
            top: MediaQuery.of(context).size.height / 2 - 24,
            child: Icon(
              Icons.arrow_back_ios,
              size: 48.0,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
        // Right arrow
        if (_currentPage < widget.imageUrls.length - 1)
          Positioned(
            right: 16.0,
            top: MediaQuery.of(context).size.height / 2 - 24,
            child: Icon(
              Icons.arrow_forward_ios,
              size: 48.0,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
      ],
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

  Future<void> _showSaveDialog() async {
    TextEditingController _nameController = TextEditingController();
    List<String> detectedTexts = [];
    for (var controller in _textControllers) {
      detectedTexts.add(controller.text);
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap a button to dismiss the dialog
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Save'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Enter a name for the saved data:'),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Name',
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                try {
                  _control.saveOriginal(widget.imageUrls, detectedTexts,
                      _nameController.text, context);
                  Navigator.of(context).pop();
                  showSnackBar(context, "Prompt saved successfully");
                } catch (e) {
                  showSnackBar(context, "Error saving prompt: $e");
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detect Text View'),
        actions: [
          DropdownButton<String>(
            value: _selectedLanguage,
            onChanged: (String? newValue) {
              setState(() {
                _selectedLanguage = newValue!;
                _isLoading = true;
                _textControllers.clear();
                _initializeTextControllers();
              });
            },
            items: <String>['en', 'cn']
                .map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value.toUpperCase()),
              );
            }).toList(),
          ),
          PopupMenuButton<String>(
            onSelected: (String result) {
              if (result == 'save') {
                _showSaveDialog();
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
