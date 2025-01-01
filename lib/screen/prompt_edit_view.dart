import 'package:ai_summarization/controller/prompt_edit_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:ai_summarization/screen/prompt_history_view.dart';
import 'package:ai_summarization/screen/summarize_ocr_view.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:flutter/material.dart';

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
  String type = '';
  String name = '';
  int _currentPage = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _pageController.addListener(_onPageChange);
  }

  void _onPageChange() {
    setState(() {
      _currentPage = _pageController.page!.round();
    });
  }

  Future<void> _fetchData() async {
    final promptData = await _controller.fetchText(widget.promptId);
    setState(() {
      name = promptData['promptName'] as String;
      texts = List<String>.from(promptData['promptTexts']);
      imageUrls = List<String>.from(promptData['fileUrls']);
      type = promptData['type'] as String;
      _initializeTextControllers();
      _isLoading = false;
    });
  }

  void _initializeTextControllers() {
    _textControllers.clear();
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

  Widget _buildPageContent(int index) {
    if (type == 'summary') {
      int pairIndex = index ~/ 2;
      if (index % 2 == 0) {
        return _buildImageTextPage(pairIndex);
      } else {
        return _buildSummaryPage(pairIndex);
      }
    }
    return _buildImageTextPage(index);
  }

  Widget _buildImageTextPage(int index) {
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
                      onTap: () => _handleImageTap(index),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          imageUrls[index],
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
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
                        onPressed: () => _handleImageTap(index),
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
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: type == 'summary'
                          ? _textControllers[index * 2]
                          : _textControllers[index],
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
  }

  Widget _buildSummaryPage(int pairIndex) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
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
                  'Summary',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textControllers[pairIndex * 2 + 1],
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
      ),
    );
  }

  Future<void> _handleImageTap(int index) async {
    final updatedTexts = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullImageView(imageUrl: imageUrls[index]),
      ),
    );
    if (updatedTexts != null) {
      setState(() {
        texts = List<String>.from(updatedTexts);
        _initializeTextControllers();
      });
    }
  }

  List<PopupMenuItem<String>> _buildMenuItems() {
    return [
      const PopupMenuItem(value: 'save', child: Text('Save')),
      const PopupMenuItem(value: 'history', child: Text('History')),
      const PopupMenuItem(value: 'rename', child: Text('Rename')),
      if (type == 'prompt')
        const PopupMenuItem(value: 'summarize', child: Text('Summarize')),
    ];
  }

  Future<void> _handleMenuSelection(String value) async {
    switch (value) {
      case 'save':
        await _controller.updatePrompt(
          widget.promptId,
          _textControllers.map((c) => c.text).toList(),
        );
        if (mounted) showSnackBar(context, "Prompt saved");
        break;
      case 'history':
        final updatedTexts = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PromptHistoryView(promptId: widget.promptId),
          ),
        );
        if (updatedTexts != null && mounted) {
          setState(() {
            texts = List<String>.from(updatedTexts);
            _initializeTextControllers();
          });
        }
        break;
      case 'rename':
        if (mounted) _showRenameDialog(widget.promptId, name);
        break;
      case 'summarize':
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SummarizeOcrView(
                imageUrls: imageUrls,
                detectedTexts: _textControllers.map((c) => c.text).toList(),
              ),
            ),
          );
        }
        break;
    }
  }

  void _showRenameDialog(String promptId, String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Rename Prompt'),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: 'New Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            filled: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty) {
                await _controller.renamePrompt(promptId, newName);
                if (mounted) {
                  setState(() => name = newName);
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuSelection,
            itemBuilder: (_) => _buildMenuItems(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: texts.length,
                  onPageChanged: (index) =>
                      setState(() => _currentPage = index),
                  itemBuilder: (_, index) => _buildPageContent(index),
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
                if (_currentPage < texts.length - 1)
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
            ),
    );
  }
}
