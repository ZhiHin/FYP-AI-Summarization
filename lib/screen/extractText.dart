import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExtractScreen extends StatefulWidget {
  final List<String> fileUrls;
  final List<String> documentNames;

  const ExtractScreen({
    super.key,
    required this.fileUrls,
    required this.documentNames,
  });

  @override
  State<ExtractScreen> createState() => _ExtractScreenState();
}

class _ExtractScreenState extends State<ExtractScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, String> _extractedTexts = {};
  final Map<String, String?> _summaries = {};
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  String _selectedSummarizationTechnique = 'extractive';
  Timer? _timer;
  int _index = 0;
  String? _currentSummary;
  late Map<String, String?> _displayedSummaries = {};

  final Map<int, bool> _selectedDocuments = {};
  bool _isSummarizing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.fileUrls.length + 1,
      vsync: this,
    );
    _extractTexts();

    // Initialize document selection map
    for (int i = 0; i < widget.fileUrls.length; i++) {
      _selectedDocuments[i] = false;
      _summaries[i.toString()] = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _extractTexts() async {
    setState(() => _isLoading = true);

    try {
      for (int i = 0; i < widget.fileUrls.length; i++) {
        final url = widget.fileUrls[i];
        if (!_extractedTexts.containsKey(url)) {
          final extractedText = await _extractSingleText(url);
          setState(() => _extractedTexts[url] = extractedText);
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _extractSingleText(String fileUrl) async {
    if (fileUrl.isEmpty) {
      return 'No file selected for text extraction';
    }

    try {
      final fileResponse = await http.get(Uri.parse(fileUrl)).timeout(
            const Duration(minutes: 2),
            onTimeout: () => throw TimeoutException('File download timeout'),
          );

      if (fileResponse.statusCode != 200) {
        throw Exception('Failed to download file: ${fileResponse.statusCode}');
      }

      final extractRequest = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.1.106:8000/extract_text'),
      );

      extractRequest.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileResponse.bodyBytes,
          filename: 'document.pdf',
        ),
      );

      final extractResponse = await extractRequest.send().timeout(
            const Duration(minutes: 5),
            onTimeout: () => throw TimeoutException('Text extraction timeout'),
          );

      final extractedData = json.decode(
        await extractResponse.stream.bytesToString(),
      );

      if (extractResponse.statusCode != 200) {
        throw Exception(
          'Failed to extract text: ${extractedData['error'] ?? 'Unknown error'}',
        );
      }

      return extractedData['text'];
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  Future<void> _summarizeText() async {
    final selectedIndices = _selectedDocuments.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one document')),
      );
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      for (final index in selectedIndices) {
        final url = widget.fileUrls[index];
        final text = _extractedTexts[url];

        if (text == null || text.isEmpty) continue;

        setState(() {
          _summaries[index.toString()] = 'Generating summary...';
          _displayedSummaries[index.toString()] = '';
        });

        final summarizeResponse = await http
            .post(
              Uri.parse('http://192.168.1.106:8000/summarize'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'text': text,
                'summary_type': _selectedSummarizationTechnique,
                'max_length': 150,
              }),
            )
            .timeout(
              const Duration(minutes: 5),
              onTimeout: () => throw TimeoutException('Summarization timeout'),
            );

        if (summarizeResponse.statusCode != 200) {
          final error = json.decode(summarizeResponse.body)['error'];
          throw Exception('Failed to summarize text: $error');
        }

        final summaryData = json.decode(summarizeResponse.body);
        setState(() {
          _summaries[index.toString()] = summaryData['summary'];
          // Start displaying the summary with typewriter effect
          _currentSummary = summaryData['summary'];
          _startDisplayingSummaryForIndex(index.toString());
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating summaries: $e')),
      );
    } finally {
      setState(() => _isSummarizing = false);
    }
  }

  void _startDisplayingSummaryForIndex(String index) {
    if (_summaries[index] == null) return;

    int charIndex = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 12), (timer) {
      if (charIndex < _summaries[index]!.length) {
        setState(() {
          _displayedSummaries[index] =
              _summaries[index]!.substring(0, charIndex) + '|';
          charIndex++;
        });
      } else {
        setState(() {
          _displayedSummaries[index] = _summaries[index];
        });
        timer.cancel();
      }
    });
  }

  Future<void> _generateAndUploadPdf({
    required String content,
    required String contentType,
    String? documentName,
  }) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document();
      final pageFormat = PdfPageFormat.a4;
      const margin = 40.0;

      final textStyle = pw.TextStyle(
        fontSize: 12,
        lineSpacing: 1.5,
      );
      final titleStyle = pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
      );

      // Split content into pages
      final pages = _splitTextIntoPages(
        content,
        textStyle,
        pageFormat.availableWidth - margin * 2,
        pageFormat.availableHeight - margin * 2,
      );

      for (int i = 0; i < pages.length; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(margin),
            build: (context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (i == 0) ...[
                  pw.Text(
                    documentName ??
                        (contentType == 'extracted'
                            ? 'Extracted Text'
                            : 'Document Summary'),
                    style: titleStyle,
                  ),
                  pw.SizedBox(height: 20),
                ],
                pw.Text(
                  'Page ${i + 1} of ${pages.length}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  pages[i],
                  style: textStyle,
                  textAlign: pw.TextAlign.justify,
                ),
              ],
            ),
          ),
        );
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Remove .pdf if it exists in documentName and add it back once
      final baseFileName =
          documentName?.replaceAll('.pdf', '') ?? timestamp.toString();
      final fileName = '${contentType}_$baseFileName.pdf';

      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$fileName');
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/documents/$fileName');

      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .add({
        'name': fileName,
        'documentType': 'pdf',
        'contentType': contentType,
        'fileUrl': downloadUrl,
        'folderId': null,
        'pageCount': pages.length,
        'size': bytes.length,
        'uploadedAt': FieldValue.serverTimestamp(),
        'summaryType':
            contentType == 'summary' ? _selectedSummarizationTechnique : null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF saved successfully (${pages.length} pages)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    } finally {
      setState(() => _isGeneratingPdf = false);
    }
  }

 List<String> _splitTextIntoPages(
  String text,
  pw.TextStyle style,
  double pageWidth,
  double pageHeight,
) {
  final pages = <String>[];
  String remainingText = text.trim();

  final lineHeight = style.fontSize! * style.lineSpacing!;
  final availableHeight = pageHeight - 100; // Adjust for margins, headers, footers
  final maxLinesPerPage = (availableHeight / lineHeight).floor();

  while (remainingText.isNotEmpty) {
    // Estimate the number of characters that can fit on one page
    final charsPerLine = (pageWidth / (style.fontSize! * 0.5)).floor();
    final estimatedCharsPerPage = charsPerLine * maxLinesPerPage;

    // Extract a chunk of text for this page
    String pageText = remainingText.length > estimatedCharsPerPage
        ? remainingText.substring(0, estimatedCharsPerPage)
        : remainingText;

    // Try to find a good break point
    int breakPoint = _findBreakPoint(pageText);
    if (breakPoint > 0) {
      pageText = pageText.substring(0, breakPoint).trimRight();
    }

    // Add the text for this page
    pages.add(pageText);

    // Remove the processed content
    remainingText = remainingText.substring(pageText.length).trimLeft();
  }

  return pages;
}

int _findBreakPoint(String text) {
  // Strategies to find the best split point
  final breakStrategies = [
    () => text.lastIndexOf('\n\n'), // Double line break
    () => text.lastIndexOf('\n'),  // Single line break
    () => text.lastIndexOf('. '),  // Sentence boundary
    () => text.lastIndexOf(' ', (text.length * 0.75).toInt()), // Word boundary
    () => text.lastIndexOf(' '),   // Last word boundary
  ];

  for (var strategy in breakStrategies) {
    int breakPoint = strategy();
    if (breakPoint != -1 && breakPoint > 0) {
      return breakPoint;
    }
  }
  return -1; // No valid break point found
}


  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Widget _buildActionButtons(String content, String label,
      [String? documentName]) {
    if (content.startsWith('Error') ||
        content.startsWith('Downloading') ||
        content.startsWith('Generating') ||
        content.startsWith('Processing')) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        IconButton.filled(
          icon: const Icon(Icons.copy),
          onPressed: () => _copyToClipboard(content, label),
          tooltip: 'Copy $label',
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: _isGeneratingPdf
              ? null
              : () => _generateAndUploadPdf(
                    content: content,
                    contentType: label.toLowerCase(),
                    documentName: documentName,
                  ),
          tooltip: 'Save $label as PDF',
        ),
      ],
    );
  }

  Widget _buildContentCard(String title, String content, String label) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildActionButtons(content, label, title),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                content,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryTab() {
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Summarization Options',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Select Documents to Summarize:',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    widget.fileUrls.length,
                    (index) => FilterChip(
                      label: Text(widget.documentNames[index]),
                      selected: _selectedDocuments[index] ?? false,
                      onSelected: (selected) {
                        setState(() {
                          _selectedDocuments[index] = selected;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Extractive'),
                        value: 'extractive',
                        groupValue: _selectedSummarizationTechnique,
                        dense: true,
                        onChanged: (value) {
                          setState(() {
                            _selectedSummarizationTechnique = value!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Abstractive'),
                        value: 'abstractive',
                        groupValue: _selectedSummarizationTechnique,
                        dense: true,
                        onChanged: (value) {
                          setState(() {
                            _selectedSummarizationTechnique = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isSummarizing ? null : _summarizeText,
                  icon: _isSummarizing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.summarize),
                  label: Text(
                      _isSummarizing ? 'Generating...' : 'Generate Summaries'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: widget.fileUrls.length,
            itemBuilder: (context, index) {
              final summary = _summaries[index.toString()];
              if (summary == null) return const SizedBox.shrink();

              final displayedSummary =
                  _displayedSummaries[index.toString()] ?? summary;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Summary of ${widget.documentNames[index]}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _buildActionButtons(
                              summary, 'Summary', widget.documentNames[index]),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        displayedSummary,
                        style: const TextStyle(fontSize: 16, height: 1.5),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract & Summarize Text'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            ...List.generate(
              widget.fileUrls.length,
              (index) => Tab(
                icon: const Icon(Icons.text_fields),
                text: 'Document ${index + 1}',
              ),
            ),
            const Tab(
              icon: Icon(Icons.summarize),
              text: 'Summary',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Processing documents...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                ...widget.fileUrls.map((url) {
                  final index = widget.fileUrls.indexOf(url);
                  final documentName = widget.documentNames[index];
                  return _buildContentCard(
                    documentName,
                    _extractedTexts[url] ?? 'No text extracted yet',
                    'Extracted text',
                  );
                }),
                _buildSummaryTab(),
              ],
            ),
    );
  }
}
