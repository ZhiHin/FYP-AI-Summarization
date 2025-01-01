import 'package:ai_summarization/controller/summarize_ocr_control.dart';
import 'package:ai_summarization/screen/image_zoom.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:ai_summarization/service/translation_service.dart';
import 'package:flutter/material.dart';

class SummarizeOcrView extends StatefulWidget {
  final List<String> imageUrls;
  final List<String> detectedTexts;

  const SummarizeOcrView(
      {super.key, required this.imageUrls, required this.detectedTexts});

  @override
  State<SummarizeOcrView> createState() => _SummarizeOcrViewState();
}

class _SummarizeOcrViewState extends State<SummarizeOcrView> {
  final SummarizeOcrControl _control = SummarizeOcrControl();
  final PageController _pageController = PageController();
  final TranslationService _translationService = TranslationService();
  String _summarizationType = 'extractive';
  String? _selectedLanguage;
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
    _pageController.addListener(_onPageChange);
  }

  void _onPageChange() {
    setState(() {
      _currentPage = _pageController.page!.round();
      print('Current page: $_currentPage');
    });
  }

  void _initializeControllers() {
    _textControllers = widget.detectedTexts
        .map((text) => TextEditingController(text: text))
        .toList();
    _summaryControllers =
        widget.detectedTexts.map((_) => TextEditingController()).toList();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _textControllers.forEach((controller) => controller.dispose());
    _summaryControllers.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _generateSummaries() async {
    setState(() {
      _isLoading = true;
      _summarized = true;
    });

    for (int i = 0; i < widget.detectedTexts.length; i++) {
      if (!mounted) return;
      String summary = await _control.generateSummary(
          widget.detectedTexts[i], _summarizationType);
      setState(() {
        _summaryControllers[i].text = summary;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _translateTexts() async {
    if (_selectedLanguage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      for (int i = 0; i < _textControllers.length; i++) {
        print('Translating detected text $i');
        String translatedDetectedText = await _translationService.translateText(
            _textControllers[i].text, _selectedLanguage!);
        setState(() {
          _textControllers[i].text = translatedDetectedText;
        });

        if (_summarized) {
          print('Translating summarized text $i');
          String translatedSummaryText = await _translationService
              .translateText(_summaryControllers[i].text, _selectedLanguage!);
          setState(() {
            _summaryControllers[i].text = translatedSummaryText;
          });
        }
      }
    } catch (e) {
      showSnackBar(context, "Failed to translate text: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildSummarizationTypeSelector() {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select Summarization Type',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          RadioListTile<String>(
            title: const Text('Extractive Summarization'),
            subtitle:
                const Text('Selects key sentences from the original text'),
            value: 'extractive',
            groupValue: _summarizationType,
            onChanged: (value) => setState(() => _summarizationType = value!),
          ),
          RadioListTile<String>(
            title: const Text('Abstractive Summarization'),
            subtitle: const Text('Generates new text to capture main ideas'),
            value: 'abstractive',
            groupValue: _summarizationType,
            onChanged: (value) => setState(() => _summarizationType = value!),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalPages =
        _summarized ? widget.imageUrls.length * 2 : widget.imageUrls.length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Image Summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_summarized)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: () => _showSaveDialog(),
              tooltip: 'Save Summary',
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing...'),
                ],
              ),
            )
          else
            PageView.builder(
              controller: _pageController,
              itemCount: totalPages,
              itemBuilder: (context, index) {
                if (!_summarized) {
                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSummarizationTypeSelector(),
                        Padding(
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
                                              builder: (context) =>
                                                  FullImageView(
                                                imageUrl:
                                                    widget.imageUrls[index],
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
                                              if (progress == null)
                                                return child;
                                              return Center(
                                                child:
                                                    CircularProgressIndicator(
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
                                                builder: (context) =>
                                                    FullImageView(
                                                  imageUrl:
                                                      widget.imageUrls[index],
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Detected Text - Page ${index + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: _textControllers[index],
                                        maxLines: null,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
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
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton.icon(
                            onPressed: _generateSummaries,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Generate Summary'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  int pairIndex = index ~/ 2;
                  if (index % 2 == 0) {
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
                                              imageUrl:
                                                  widget.imageUrls[pairIndex],
                                            ),
                                          ),
                                        );
                                      },
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: Image.network(
                                          widget.imageUrls[pairIndex],
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
                                              builder: (context) =>
                                                  FullImageView(
                                                imageUrl:
                                                    widget.imageUrls[pairIndex],
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
                                      'Original Text',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _textControllers[pairIndex],
                                      maxLines: null,
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
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
                  } else {
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
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _summaryControllers[pairIndex],
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
                }
              },
            ),

          // Navigation arrows
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
          if (_currentPage < widget.imageUrls.length * 2 - 1)
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  value: _selectedLanguage,
                  hint: const Text('Select Language'),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedLanguage = newValue;
                    });
                  },
                  items: [
                    DropdownMenuItem(
                      value: 'en',
                      child: Row(
                        children: [
                          const Text('🇺🇸'),
                          const SizedBox(width: 4),
                          const Text('English'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'zh',
                      child: Row(
                        children: [
                          const Text('🇨🇳'),
                          const SizedBox(width: 4),
                          const Text('Chinese'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: _selectedLanguage != null ? _translateTexts : null,
                child: const Text('Translate'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSaveDialog() async {
    final TextEditingController nameController = TextEditingController();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Save Summary'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Enter a name for the summary:'),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
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

                      await _control.saveSummary(
                        widget.imageUrls,
                        combinedTexts,
                        nameController.text,
                        type,
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        showSnackBar(context, "Summary saved successfully");
                      }
                    } catch (e) {
                      showSnackBar(context, "Error saving summary: $e");
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
