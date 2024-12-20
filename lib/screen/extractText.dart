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
  final String fileUrl;

  const ExtractScreen({super.key, required this.fileUrl});

  @override
  State<ExtractScreen> createState() => _ExtractScreenState();
}

class _ExtractScreenState extends State<ExtractScreen> {
  String? _extractedText;
  String? _summary;
  String? _displayedSummary;
  bool _isLoading = false;
  bool _isGeneratingPdf = false;
  String _selectedSummarizationTechnique = 'extractive';
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _extractText(widget.fileUrl);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // New function to generate and upload PDF
  Future<void> _generateAndUploadPdf({
    required String content,
    required String contentType, // 'extracted' or 'summary'
  }) async {
    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document();

      // Define page format and margins
      final pageFormat = PdfPageFormat.a4;
      const margin = 40.0;

      // Define text styles
      final textStyle = pw.TextStyle(
        fontSize: 12,
        lineSpacing: 1.5,
      );
      final titleStyle = pw.TextStyle(
        fontSize: 16,
        fontWeight: pw.FontWeight.bold,
      );

      // Split content function
      List<String> _splitTextIntoPages(String text, pw.TextStyle style,
          double pageWidth, double pageHeight) {
        final pages = <String>[];
        String remainingText = text.trim();

        final lineHeight = style.fontSize! * 1.5;
        final availableHeight = pageHeight - 100;
        final linesPerPage = (availableHeight / lineHeight).floor();
        final charsPerLine = (pageWidth / (style.fontSize! * 0.6)).floor();
        final estimatedCharsPerPage = linesPerPage * charsPerLine;

        while (remainingText.isNotEmpty) {
          String pageText = remainingText.length > estimatedCharsPerPage
              ? remainingText.substring(0, estimatedCharsPerPage)
              : remainingText;

          final breakStrategies = [
            () => pageText.lastIndexOf('\n\n'),
            () => pageText.lastIndexOf('\n'),
            () => pageText.lastIndexOf(' ', (pageText.length * 0.75).toInt()),
            () => pageText.lastIndexOf(' '),
          ];

          int breakPoint = -1;
          for (var strategy in breakStrategies) {
            breakPoint = strategy();
            if (breakPoint != -1 && breakPoint > 0) {
              pageText = pageText.substring(0, breakPoint);
              break;
            }
          }

          pageText = pageText.trimRight();
          pages.add(pageText);
          remainingText = remainingText.substring(pageText.length).trimLeft();
        }

        return pages;
      }

      // Prepare content based on type
      final String formattedContent = content;

      // Split content into pages
      final contentPages = _splitTextIntoPages(
          formattedContent,
          textStyle,
          pageFormat.availableWidth - margin * 2,
          pageFormat.availableHeight - margin * 2);

      // Generate PDF pages
      for (int i = 0; i < contentPages.length; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(margin),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (i == 0) ...[
                    pw.Text(
                        contentType == 'extracted'
                            ? 'Extracted Document Text'
                            : 'Document Summary',
                        style: titleStyle),
                    pw.SizedBox(height: 20),
                  ],
                  pw.Text('Page ${i + 1} of ${contentPages.length}',
                      style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    contentPages[i],
                    style: textStyle,
                    textAlign: pw.TextAlign.justify,
                  ),
                ],
              );
            },
          ),
        );
      }

      // Get current user
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      String fileName = '${contentType}_${timestamp}.pdf';

      // Save PDF locally
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$fileName');
      final bytes = await pdf.save();
      await file.writeAsBytes(bytes);

      // Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/${user.uid}/documents/$fileName');

      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Save metadata to Firestore with content type specific fields
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .add({
        'title': fileName,
        'documentType': 'pdf',
        'contentType': contentType, // 'extracted' or 'summary'
        'fileUrl': downloadUrl,
        'folderId': null,
        'pageCount': contentPages.length,
        'size': bytes.length,
        'uploadedAt': FieldValue.serverTimestamp(),
        'summaryType':
            contentType == 'summary' ? _selectedSummarizationTechnique : null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${contentType == 'extracted' ? 'Extracted text' : 'Summary'} PDF saved successfully (${contentPages.length} pages)'),
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

  void _startDisplayingSummary() {
    _index = 0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 12), (timer) {
      if (_index < _summary!.length) {
        setState(() {
          _displayedSummary = _summary!.substring(0, _index) + '|';
          _index++;
        });
      } else {
        setState(() {
          _displayedSummary = _summary;
        });
        _timer?.cancel();
      }
    });
  }

  // Copy text to clipboard and show a snackbar
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label copied to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // Extract text from the document
  Future<void> _extractText(String fileUrl) async {
    if (fileUrl.isEmpty) {
      setState(() => _extractedText = 'No file selected for text extraction');
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _extractedText = 'Downloading and processing file...';
      });

      final fileResponse = await http.get(Uri.parse(fileUrl)).timeout(
            const Duration(minutes: 2),
            onTimeout: () => throw TimeoutException('File download timeout'),
          );

      if (fileResponse.statusCode != 200) {
        throw Exception('Failed to download file: ${fileResponse.statusCode}');
      }

      setState(() => _extractedText = 'Extracting text from PDF...');

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

      setState(() => _extractedText = extractedData['text']);
    } on TimeoutException catch (e) {
      setState(() => _extractedText = 'Error: Operation timed out - $e');
    } on http.ClientException catch (e) {
      setState(() => _extractedText = 'Error: Cannot connect to server - $e');
    } catch (e) {
      setState(() => _extractedText = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Summarize the extracted text
  Future<void> _summarizeText() async {
    if (_extractedText == null || _extractedText!.isEmpty) {
      setState(() => _summary = 'No text to summarize');
      return;
    }

    try {
      setState(() {
        _summary = 'Generating summary...';
        _displayedSummary = _summary;
      });

      final summarizeResponse = await http
          .post(
            Uri.parse('http://192.168.1.106:8000/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': _extractedText,
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
        _summary = summaryData['summary'];
        _displayedSummary = '';
      });
      _startDisplayingSummary();
    } on TimeoutException catch (e) {
      setState(() {
        _summary = 'Error: Operation timed out - $e';
        _displayedSummary = _summary;
      });
    } on http.ClientException catch (e) {
      setState(() {
        _summary = 'Error: Cannot connect to server - $e';
        _displayedSummary = _summary;
      });
    } catch (e) {
      setState(() {
        _summary = 'Error: ${e.toString()}';
        _displayedSummary = _summary;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extract & Summarize Text'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_isLoading) const CircularProgressIndicator(),
            if (_extractedText != null)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Extracted Text:',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          Row(
                            children: [
                              if (_extractedText != null &&
                                  !_extractedText!.startsWith('Error') &&
                                  !_extractedText!
                                      .startsWith('Downloading')) ...[
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyToClipboard(
                                      _extractedText!, 'Extracted text'),
                                  tooltip: 'Copy extracted text',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.picture_as_pdf),
                                  onPressed: _isGeneratingPdf
                                      ? null
                                      : () => _generateAndUploadPdf(
                                            content: _extractedText!,
                                            contentType: 'extracted',
                                          ),
                                ),
                              ]
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _extractedText!,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Radio<String>(
                            value: 'extractive',
                            groupValue: _selectedSummarizationTechnique,
                            onChanged: (value) {
                              setState(() {
                                _selectedSummarizationTechnique = value!;
                              });
                            },
                          ),
                          const Text('Extractive'),
                          Radio<String>(
                            value: 'abstractive',
                            groupValue: _selectedSummarizationTechnique,
                            onChanged: (value) {
                              setState(() {
                                _selectedSummarizationTechnique = value!;
                              });
                            },
                          ),
                          const Text('Abstractive'),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: _summarizeText,
                        child: const Text('Summarize Text'),
                      ),
                      if (_displayedSummary != null &&
                          _displayedSummary!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Summary:',
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  Row(
                                    children: [
                                      if (!_displayedSummary!
                                              .startsWith('Error') &&
                                          !_displayedSummary!
                                              .startsWith('Generating')) ...[
                                        IconButton(
                                          icon: const Icon(Icons.copy),
                                          onPressed: () => _copyToClipboard(
                                              _summary!, 'Summary'),
                                          tooltip: 'Copy summary',
                                        ),
                                        IconButton(
                                          icon:
                                              const Icon(Icons.picture_as_pdf),
                                          onPressed: _isGeneratingPdf
                                              ? null
                                              : () => _generateAndUploadPdf(
                                                    content: _summary!,
                                                    contentType: 'summary',
                                                  ),
                                        ),
                                      ]
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                _displayedSummary!,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
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
}
