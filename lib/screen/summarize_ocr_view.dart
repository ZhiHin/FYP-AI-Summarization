import 'package:ai_summarization/controller/summarize_ocr_control.dart';
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
  List<String> _summaries = [];
  List<String> _promptAndSummaryPair = [];
  bool _isLoading = false;
  bool _summarized = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _summaries = List.filled(widget.detectedTexts.length, '');
    _pageController.addListener(() {
      setState(() {
        _currentPage = _pageController.page!.round();
        print('Current Page: $_currentPage'); // Debug print
      });
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _generateSummaries() async {
    setState(() {
      _isLoading = true;
      _summarized = true;
    });

    _promptAndSummaryPair.clear(); // Clear the list before adding new pairs

    for (int i = 0; i < widget.detectedTexts.length; i++) {
      String summary = await _control.generateSummary(
          widget.detectedTexts[i], _summarizationType);
      if (mounted) {
        setState(() {
          _summaries[i] = summary;
          _promptAndSummaryPair.add(widget.detectedTexts[i]);
          _promptAndSummaryPair.add(summary);
        });
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int totalPages =
        _summarized ? widget.imageUrls.length * 2 : widget.imageUrls.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summarize OCR View'),
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
                                    Text(
                                      widget.detectedTexts[index],
                                      style: const TextStyle(fontSize: 16.0),
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
                                  Text(
                                    _promptAndSummaryPair[pairIndex * 2],
                                    style: const TextStyle(fontSize: 16.0),
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
                                  Text(
                                    _promptAndSummaryPair[pairIndex * 2 + 1],
                                    style: const TextStyle(
                                      fontSize: 16.0,
                                      color: Colors.blue,
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
                      print('Page changed to: $_currentPage'); // Debug print
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
