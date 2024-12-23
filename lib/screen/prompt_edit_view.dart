import 'package:ai_summarization/controller/prompt_edit_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:ai_summarization/screen/prompt_history_view.dart';
import 'package:flutter/material.dart';

class PromptEditView extends StatefulWidget {
  final String promptId;
  final List<String> imageUrls;
  final List<String> texts;
  final String promptName;
  const PromptEditView(
      {super.key,
      required this.promptId,
      required this.imageUrls,
      required this.texts,
      required this.promptName});
  @override
  _PromptEditViewState createState() => _PromptEditViewState();
}

class _PromptEditViewState extends State<PromptEditView> {
  final PageController _pageController = PageController();
  final PromptEditControl _controller = PromptEditControl();
  final List<TextEditingController> _textControllers = [];
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _initializeTextControllers();
  }

  void _initializeTextControllers() {
    for (var text in widget.texts) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.promptName),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              // Handle menu selection
              if (result == 'save') {
                _controller.updatePrompt(
                    widget.promptId,
                    _textControllers
                        .map((controller) => controller.text)
                        .toList());
                print(widget.promptId);
              } else if (result == 'history') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PromptHistoryView(promptId: widget.promptId),
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
            ],
          ),
        ],
      ),
      body: Stack(
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
          if (_currentPage < widget.imageUrls.length - 1)
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
