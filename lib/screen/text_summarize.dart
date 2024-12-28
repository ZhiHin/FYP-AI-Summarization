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

enum SaveOption {
  textAndSummary,
  textOnly,
  summaryOnly,
}

class SavePdfDialog extends StatelessWidget {
  const SavePdfDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save PDF'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.article),
            title: const Text('Text and Summary'),
            onTap: () => Navigator.pop(context, SaveOption.textAndSummary),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Text Only'),
            onTap: () => Navigator.pop(context, SaveOption.textOnly),
          ),
          ListTile(
            leading: const Icon(Icons.summarize),
            title: const Text('Summary Only'),
            onTap: () => Navigator.pop(context, SaveOption.summaryOnly),
          ),
        ],
      ),
    );
  }
}

class TextSummarizeScreen extends StatefulWidget {
  const TextSummarizeScreen({super.key});

  @override
  State<TextSummarizeScreen> createState() => _TextSummarizeScreenState();
}

class _TextSummarizeScreenState extends State<TextSummarizeScreen> {
  final TextEditingController _textController = TextEditingController();
  String _selectedTechnique = 'extractive';
  String? _summary;
  bool _isLoading = false;
  bool _isGeneratingPdf = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _summarizeText() async {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter some text to summarize')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('http://192.168.1.106:8000/summarize'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'text': _textController.text,
              'summary_type': _selectedTechnique,
              'max_length': 150,
            }),
          )
          .timeout(const Duration(minutes: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to summarize text');
      }

      final summaryData = json.decode(response.body);
      setState(() => _summary = summaryData['summary']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating summary: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generateAndSavePdf() async {
    if (_summary == null) return;

    final saveOption = await showDialog<SaveOption>(
      context: context,
      builder: (context) => const SavePdfDialog(),
    );

    if (saveOption == null) return;

    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document();
      final pageFormat = PdfPageFormat.a4;
      const margin = 40.0;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(margin),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Text Summary',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              if (saveOption != SaveOption.summaryOnly) ...[
                pw.Text(
                  'Original Text:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  _textController.text,
                  style: const pw.TextStyle(
                    fontSize: 12,
                    lineSpacing: 1.5,
                  ),
                ),
                pw.SizedBox(height: 20),
              ],
              if (saveOption != SaveOption.textOnly) ...[
                pw.Text(
                  'Summary:',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  _summary!,
                  style: const pw.TextStyle(
                    fontSize: 12,
                    lineSpacing: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'summary_$timestamp.pdf';

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
        'contentType': 'summary',
        'fileUrl': downloadUrl,
        'folderId': null,
        'pageCount': 1,
        'size': bytes.length,
        'uploadedAt': FieldValue.serverTimestamp(),
        'summaryType': _selectedTechnique,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF saved successfully')),
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

  Future<void> _copyToClipboard() async {
    if (_summary == null) return;
    await Clipboard.setData(ClipboardData(text: _summary!));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Summary copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Text Summarization'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Input Card
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enter Text',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _textController,
                              maxLines: 8,
                              decoration: InputDecoration(
                                hintText: 'Paste or type your text here...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: theme.colorScheme.surface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Summarization Options
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Summarization Type',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryTypeCard(
                                    title: 'Extractive',
                                    isSelected:
                                        _selectedTechnique == 'extractive',
                                    onTap: () => setState(() =>
                                        _selectedTechnique = 'extractive'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryTypeCard(
                                    title: 'Abstractive',
                                    isSelected:
                                        _selectedTechnique == 'abstractive',
                                    onTap: () => setState(() =>
                                        _selectedTechnique = 'abstractive'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Generate Button
                    FilledButton.icon(
                      onPressed: _isLoading ? null : _summarizeText,
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        _isLoading
                            ? 'Generating Summary...'
                            : 'Generate Summary',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Summary Section
                    if (_summary != null) ...[
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Summary',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: _copyToClipboard,
                                        icon: const Icon(Icons.copy),
                                        tooltip: 'Copy to Clipboard',
                                      ),
                                      IconButton(
                                        onPressed: _isGeneratingPdf
                                            ? null
                                            : _generateAndSavePdf,
                                        icon: _isGeneratingPdf
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : const Icon(
                                                Icons.picture_as_pdf_outlined),
                                        tooltip: 'Save as PDF',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: theme.colorScheme.outline
                                        .withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  _summary!,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _SummaryTypeCard extends StatelessWidget {
  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  const _SummaryTypeCard({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 1,
      color: isSelected ? Theme.of(context).primaryColor : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
