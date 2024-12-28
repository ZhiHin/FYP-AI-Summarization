import 'package:ai_summarization/controller/summarize_ocr_control.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:flutter/material.dart';

class SummarizeOcrView extends StatefulWidget {
  final List<String> imageUrls; // Array of image URLs
  final List<String> detectedTexts; // Array of detected texts

  const SummarizeOcrView(
      {super.key, required this.imageUrls, required this.detectedTexts});

  @override
  State<SummarizeOcrView> createState() => _SummarizeOcrViewState();
}

class _SummarizeOcrViewState extends State<SummarizeOcrView> {
  final SummarizeOcrControl _control = SummarizeOcrControl();
  final PageController _pageController = PageController();
  String _summarizationType = 'extractive'; // Default summarization type
  final String type = 'summary';
  List<TextEditingController> _textControllers = [];
  List<TextEditingController> _summaryControllers = [];
  bool _isLoading = false;
  bool _summarized = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!.round();
        print('Current Page: $_currentPage'); // Debug print
      });
    });
  }

  void _initializeControllers() {
    for (var text in widget.detectedTexts) {
      _textControllers.add(TextEditingController(text: text));
      _summaryControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _textControllers) {
      controller.dispose();
    }
    for (var controller in _summaryControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _generateSummaries() async {
    setState(() {
      _isLoading = true;
      _summarized = true;
    });

    for (int i = 0; i < widget.detectedTexts.length; i++) {
      String summary = await _control.generateSummary(
          widget.detectedTexts[i], _summarizationType);
      if (mounted) {
        setState(() {
          _summaryControllers[i].text = summary;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showSaveDialog() async {
    TextEditingController _nameController = TextEditingController();
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
              onPressed: () async {
                try {
                  List<String> promptTexts =
                      _textControllers.map((c) => c.text).toList();
                  List<String> summaryTexts =
                      _summaryControllers.map((c) => c.text).toList();
                  List<String> combinedTexts = [];
                  for (int i = 0; i < promptTexts.length; i++) {
                    combinedTexts.add(promptTexts[i]);
                    if (i < summaryTexts.length) {
                      combinedTexts.add(summaryTexts[i]);
                    }
                  }
                  await _control.saveSummary(widget.imageUrls, combinedTexts,
                      _nameController.text, type);
                  Navigator.of(context).pop();
                  showSnackBar(context, "Summary saved successfully");
                } catch (e) {
                  showSnackBar(context, "Error saving summary: $e");
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
    int totalPages =
        _summarized ? widget.imageUrls.length * 2 : widget.imageUrls.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summarize OCR View'),
        actions: [
          if (_summarized)
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
              icon: const Icon(Icons.more_vert), // Three-dot menu icon
            ),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount:
                      totalPages, // Adjust itemCount based on summarized state
                  itemBuilder: (context, index) {
                    if (!_summarized) {
                      if (index < widget.imageUrls.length) {
                        return SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                // Radio buttons for summarization type
                                Column(
                                  children: [
                                    RadioListTile<String>(
                                      title: const Text(
                                          'Extractive Summarization'),
                                      value: 'extractive',
                                      groupValue: _summarizationType,
                                      onChanged: (value) {
                                        setState(() {
                                          _summarizationType = value!;
                                        });
                                      },
                                    ),
                                    RadioListTile<String>(
                                      title: const Text(
                                          'Abstractive Summarization'),
                                      value: 'abstractive',
                                      groupValue: _summarizationType,
                                      onChanged: (value) {
                                        setState(() {
                                          _summarizationType = value!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                // Display the image
                                Center(
                                  child: Image.network(widget.imageUrls[index]),
                                ),
                                const SizedBox(height: 16.0),
                                // Display the detected text and summarization options
                                Column(
                                  children: [
                                    TextField(
                                      controller: _textControllers[index],
                                      maxLines: null,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        labelText: 'Detected Text',
                                      ),
                                    ),
                                    const SizedBox(height: 16.0),
                                    ElevatedButton(
                                      onPressed: _generateSummaries,
                                      child: const Text('Summarize'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                    } else {
                      if (_isLoading) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      } else {
                        int pairIndex = index ~/ 2;
                        if (index % 2 == 0) {
                          // Original text and image page
                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  // Display the image
                                  Center(
                                    child: Image.network(
                                        widget.imageUrls[pairIndex]),
                                  ),
                                  const SizedBox(height: 16.0),
                                  // Display the detected text
                                  TextField(
                                    controller: _textControllers[pairIndex],
                                    maxLines: null,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Detected Text',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else {
                          // Summary page
                          return SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Summary:',
                                    style: TextStyle(
                                      fontSize: 20.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8.0),
                                  TextField(
                                    controller: _summaryControllers[pairIndex],
                                    maxLines: null,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Summary',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                      }
                    }
                    return Container(); // Return an empty container if no conditions are met
                  },
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                      print('Page changed to: $_currentPage');
                    });
                    if (_pageController.hasClients &&
                        index == widget.imageUrls.length) {
                      _pageController.jumpToPage(index);
                    }
                  },
                ),
          // Left arrow
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
          if (_currentPage < totalPages - 1)
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
      ),
    );
  }
}
