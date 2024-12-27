import 'package:ai_summarization/controller/prompt_edit_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:ai_summarization/screen/prompt_history_view.dart';
import 'package:ai_summarization/screen/summarize_ocr_view.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PromptEditView extends StatefulWidget {
  final String promptId;

  const PromptEditView({
    super.key,
    required this.promptId,
  });

  @override
  _PromptEditViewState createState() => _PromptEditViewState();
}

class _PromptEditViewState extends State<PromptEditView> {
  final PageController _pageController = PageController();
  final PromptEditControl _controller = PromptEditControl();
  final List<TextEditingController> _textControllers = [];
  List<String> texts = [];
  List<String> imageUrls = [];
  String name = '';
  int _currentPage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final promptData = await _controller.fetchText(widget.promptId);
    setState(() {
      name = promptData['promptName'] as String;
      texts = List<String>.from(promptData['promptTexts'] as List<dynamic>);
      imageUrls = List<String>.from(promptData['imageUrls'] as List<dynamic>);
      _initializeTextControllers();
      _isLoading = false;
    });
  }

  void _initializeTextControllers() {
    for (var text in texts) {
      _textControllers.add(TextEditingController(text: text));
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _textControllers.clear();
      _initializeTextControllers();
    });
  }

  void _showRenameDialog(String promptId, String currentName) {
    TextEditingController nameController =
        TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Rename Prompt'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'New Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                String newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  await _controller.renamePrompt(promptId, newName);
                  setState(() {
                    name = newName;
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Rename'),
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
        title: Text(name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) async {
              if (result == 'save') {
                _controller.updatePrompt(
                  widget.promptId,
                  _textControllers
                      .map((controller) => controller.text)
                      .toList(),
                );
                showSnackBar(context, "Prompt saved");
              } else if (result == 'history') {
                final updatedTexts = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PromptHistoryView(promptId: widget.promptId),
                  ),
                );
                if (updatedTexts != null) {
                  setState(() {
                    texts = List<String>.from(updatedTexts);
                    _refresh();
                  });
                }
              } else if (result == 'rename') {
                _showRenameDialog(widget.promptId, name);
              } else if (result == 'summarize') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SummarizeOcrView(
                      imageUrls: imageUrls,
                      detectedTexts: _textControllers
                          .map((controller) => controller.text)
                          .toList(),
                    ),
                  ),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'save',
                child: Text('Save'),
              ),
              const PopupMenuItem<String>(
                value: 'history',
                child: Text('History'),
              ),
              const PopupMenuItem<String>(
                value: 'rename',
                child: Text('Rename'),
              ),
              const PopupMenuItem<String>(
                value: 'summarize',
                child: Text('Summarize'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final updatedTexts = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullImageView(
                                    imageUrl: imageUrls[index],
                                  ),
                                ),
                              );
                              if (updatedTexts != null) {
                                setState(() {
                                  texts = List<String>.from(updatedTexts);
                                  _initializeTextControllers();
                                });
                              }
                            },
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                imageUrls[index],
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
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                ),
                if (_currentPage > 0)
                  Positioned(
                    left: 16.0,
                    top: MediaQuery.of(context).size.height / 2 - 24,
                    child: GestureDetector(
                      onTap: () {
                        _pageController.previousPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Icon(
                        Icons.arrow_back_ios,
                        size: 48.0,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
                if (_currentPage < imageUrls.length - 1)
                  Positioned(
                    right: 16.0,
                    top: MediaQuery.of(context).size.height / 2 - 24,
                    child: GestureDetector(
                      onTap: () {
                        _pageController.nextPage(
                          duration: Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 48.0,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}