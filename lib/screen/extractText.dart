import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ExtractScreen extends StatefulWidget {
  final String fileUrl;

  const ExtractScreen({super.key, required this.fileUrl});

  @override
  State<ExtractScreen> createState() => _ExtractScreenState();
}

class _ExtractScreenState extends State<ExtractScreen> {
  String? _extractedText;
  String? _summary;
  bool _isLoading = false;
  String _selectedSummarizationTechnique = 'extractive';

  @override
  void initState() {
    super.initState();
    _extractText(widget.fileUrl);
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

     print("Selected Summarization Technique: $_selectedSummarizationTechnique"); 

    try {
      setState(() => _summary = 'Generating summary...');

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
      setState(() => _summary = summaryData['summary']);
    } on TimeoutException catch (e) {
      setState(() => _summary = 'Error: Operation timed out - $e');
    } on http.ClientException catch (e) {
      setState(() => _summary = 'Error: Cannot connect to server - $e');
    } catch (e) {
      setState(() => _summary = 'Error: ${e.toString()}');
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
                          if (_extractedText != null &&
                              !_extractedText!.startsWith('Error') &&
                              !_extractedText!.startsWith('Downloading'))
                            IconButton(
                              icon: const Icon(Icons.copy),
                              onPressed: () => _copyToClipboard(
                                  _extractedText!, 'Extracted text'),
                              tooltip: 'Copy extracted text',
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
                                print(
                                    "Selected summarization technique: $_selectedSummarizationTechnique");
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
                                print(
                                    "Selected summarization technique: $_selectedSummarizationTechnique");
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
                      if (_summary != null && _summary!.isNotEmpty)
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
                                  if (!_summary!.startsWith('Error') &&
                                      !_summary!.startsWith('Generating'))
                                    IconButton(
                                      icon: const Icon(Icons.copy),
                                      onPressed: () => _copyToClipboard(
                                          _summary!, 'Summary'),
                                      tooltip: 'Copy summary',
                                    ),
                                ],
                              ),
                              Text(
                                _summary!,
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
