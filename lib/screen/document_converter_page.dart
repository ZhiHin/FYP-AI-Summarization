import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';

import '../controller/document_converter_controller.dart';
import '../model/document_model.dart';

class DocumentConverterPage extends StatefulWidget {
  @override
  _DocumentConverterViewState createState() => _DocumentConverterViewState();
}

class _DocumentConverterViewState extends State<DocumentConverterPage> {
  final DocumentConverterController _controller = DocumentConverterController();
  List<Document> _documents = [];
  bool _isLoading = false;
  double _conversionProgress = 0;
  Document? _selectedDocument; // New property to store selected document

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      _documents = await _controller.getDocuments();
    } catch (e) {
      _showError('Failed to load documents: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndConvertDocument() async {
    // Show dialog to choose between picking a new file or selecting from Firebase
    final source = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Document Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.file_upload),
              title: const Text('Upload New File'),
              onTap: () => Navigator.pop(context, 'upload'),
            ),
            ListTile(
              leading: Icon(Icons.cloud),
              title: const Text('Select from Firebase'),
              onTap: () => Navigator.pop(context, 'firebase'),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    if (source == 'firebase') {
      // Show document selection dialog
      await _showDocumentSelectionDialog();
      return;
    }

    // Original file picking logic
    final format = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Conversion Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.description),
              title: const Text('PDF to Word'),
              onTap: () => Navigator.pop(context, 'word'),
            ),
            ListTile(
              leading: Icon(Icons.picture_as_pdf),
              title: const Text('Word to PDF'),
              onTap: () => Navigator.pop(context, 'pdf'),
            ),
          ],
        ),
      ),
    );

    if (format == null) return;

    try {
      // Pick file based on selected format
      final allowedExtensions = format == 'word' ? ['pdf'] : ['doc', 'docx'];
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );

      if (result == null) return;

      await _convertDocument(File(result.files.single.path!));
    } catch (e) {
      _showError('Error converting document: $e');
    }
  }

  Future<void> _showDocumentSelectionDialog() async {
    final selectedDoc = await showDialog<Document>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Document to Convert'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _documents.length,
            itemBuilder: (context, index) {
              final doc = _documents[index];
              return ListTile(
                title: Text(doc.title),
                subtitle: Text('Format: ${doc.originalFormat}'),
                onTap: () {
                  Navigator.pop(context, doc);
                },
              );
            },
          ),
        ),
      ),
    );

    if (selectedDoc == null) return;

    // Attempt to download and convert the selected document
    setState(() {
      _isLoading = true;
      _selectedDocument = selectedDoc;
    });

    try {
      final convertedDoc = await _controller.convertDocumentFromUrl(
        selectedDoc,
        onProgress: (progress) {
          setState(() => _conversionProgress = progress);
        },
      );

      if (convertedDoc != null) {
        _showSuccess('Document converted successfully');
        await _loadDocuments();
      } else {
        _showError('Conversion failed');
      }
    } catch (e) {
      _showError('Error converting document: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _conversionProgress = 0;
      });
    }
  }

  Future<void> _convertDocument(File file) async {
    setState(() {
      _isLoading = true;
      _conversionProgress = 0;
    });

    try {
      final convertedDoc = await _controller.convertDocument(
        file,
        onProgress: (progress) {
          setState(() => _conversionProgress = progress);
        },
      );

      if (convertedDoc != null) {
        _showSuccess('Document converted successfully');
        await _loadDocuments();
      } else {
        _showError('Conversion failed');
      }
    } catch (e) {
      _showError('Error converting document: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _conversionProgress = 0;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _downloadDocument(Document document) async {
  try {
    setState(() {
      _isLoading = true;
    });

    // Request permission to save file
    String? downloadPath = await FilePicker.platform.getDirectoryPath();
    if (downloadPath == null) {
      _showError('Download canceled');
      return;
    }

    // Create file path
    final fileName = document.title;
    final filePath = '$downloadPath/$fileName';

    // Download file
    final response = await http.get(Uri.parse(document.fileUrl));

    if (response.statusCode == 200) {
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      _showSuccess('Document downloaded successfully to $filePath');

      // Attempt to open the file
      final result = await OpenFile.open(filePath);
      switch (result.type) {
        case ResultType.done:
          print('File opened successfully');
          break;
        case ResultType.error:
          _showError('Could not open file: ${result.message}');
          break;
        default:
          break;
      }
    } else {
      _showError('Failed to download document');
    }
  } catch (e) {
    _showError('Error downloading document: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Document Converter'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDocuments,
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading && _conversionProgress > 0)
            LinearProgressIndicator(value: _conversionProgress),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Text(
                          'Convert your documents between PDF and Word formats',
                          style: Theme.of(context).textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed:
                              _isLoading ? null : _pickAndConvertDocument,
                          icon: const Icon(Icons.compare_arrows),
                          label: const Text('Convert Document'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _isLoading && _conversionProgress == 0
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _documents.length,
                          itemBuilder: (context, index) {
                            final doc = _documents[index];
                            return Card(
                              child: ListTile(
                                leading: Icon(_getFormatIcon(doc.documentType)),
                                title: Text(_getDisplayTitle(doc)),
                                subtitle: Text(
                                  doc.convertedFormat.isNotEmpty
                                      ? 'Converted from ${doc.originalFormat} to ${doc.convertedFormat}'
                                      : 'Original format: ${doc.originalFormat}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_formatFileSize(doc.size)),
                                    IconButton(
                                      icon: Icon(Icons.download),
                                      onPressed: _isLoading
                                          ? null
                                          : () => _downloadDocument(doc),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to display the correct title with extension
  String _getDisplayTitle(Document doc) {
    // If convertedFormat is not empty, use it to determine the display title
    if (doc.convertedFormat.isNotEmpty) {
      return '${doc.title.split('.').first}.${doc.convertedFormat}';
    }
    return doc.title;
  }

  IconData _getFormatIcon(DocumentType type) {
    switch (type) {
      case DocumentType.pdf:
        return Icons.picture_as_pdf;
      case DocumentType.document:
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
