import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class EditPdfPage extends StatefulWidget {
  final String pdfUrl;
  final String fileName;
  final String documentId;

  const EditPdfPage({
    Key? key,
    required this.pdfUrl,
    required this.fileName,
    required this.documentId,
  }) : super(key: key);

  @override
  _EditPdfPageState createState() => _EditPdfPageState();
}

class _EditPdfPageState extends State<EditPdfPage> {
  List<TextEditingController> _pageControllers = [];
  bool _isLoading = true;
  late PdfDocument _pdfDoc;
  int _currentPage = 0;
  int _totalPages = 0;
  bool _showPreview = true;

  void _toggleView() {
    setState(() {
      _showPreview = !_showPreview;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.get(Uri.parse(widget.pdfUrl));
      final bytes = response.bodyBytes;

      _pdfDoc = PdfDocument(inputBytes: bytes);
      _totalPages = _pdfDoc.pages.count;

      // Modified text extraction to preserve layout
      _pageControllers = List.generate(_totalPages, (index) {
        final page = _pdfDoc.pages[index];

        // Create text extractor with layout preservation
        final extractor = PdfTextExtractor(_pdfDoc);

        // Extract text with layout
        final text = extractor.extractText(
          startPageIndex: index,
          layoutText: true, // This preserves the text layout
        );

        // Process the text to maintain paragraph structure
        final processedText = _processExtractedText(text);

        return TextEditingController(text: processedText);
      });
    } catch (e) {
      _showError('Error loading PDF: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper method to process extracted text
  String _processExtractedText(String text) {
    // Remove excessive newlines while preserving paragraphs
    final lines = text.split('\n');
    final processedLines = <String>[];
    String currentParagraph = '';

    for (var line in lines) {
      // Trim the line
      final trimmedLine = line.trim();

      if (trimmedLine.isEmpty) {
        // Empty line indicates paragraph break
        if (currentParagraph.isNotEmpty) {
          processedLines.add(currentParagraph);
          currentParagraph = '';
        }
        processedLines.add(''); // Add empty line for paragraph spacing
      } else {
        // Check if this line should be part of the current paragraph
        if (currentParagraph.isEmpty) {
          currentParagraph = trimmedLine;
        } else {
          // Check if line ends with sentence-ending punctuation
          if (currentParagraph.endsWith('.') ||
              currentParagraph.endsWith('!') ||
              currentParagraph.endsWith('?')) {
            processedLines.add(currentParagraph);
            currentParagraph = trimmedLine;
          } else {
            // Add space and continue paragraph
            currentParagraph += ' ' + trimmedLine;
          }
        }
      }
    }

    // Add the last paragraph if any
    if (currentParagraph.isNotEmpty) {
      processedLines.add(currentParagraph);
    }

    // Join processed lines with proper spacing
    return processedLines.join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit PDF - ${widget.fileName}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        elevation: 2,
        actions: [
          if (!_isLoading)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.preview_rounded),
                  onPressed: _toggleView,
                  tooltip: 'Toggle Preview',
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: Icon(Icons.save_rounded),
                    onPressed: _savePdf,
                    tooltip: 'Save Changes',
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading PDF...'),
                  ],
                ),
              )
            : Column(
                children: [
                  // Page Navigation Bar
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_ios_rounded),
                          onPressed: _currentPage > 0
                              ? () => setState(() => _currentPage--)
                              : null,
                          color: _currentPage > 0 ? Colors.blue : Colors.grey,
                        ),
                        SizedBox(width: 16),
                        Container(
                          padding:
                              EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            'Page ${_currentPage + 1} of $_totalPages',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(width: 16),
                        IconButton(
                          icon: Icon(Icons.arrow_forward_ios_rounded),
                          onPressed: _currentPage < _totalPages - 1
                              ? () => setState(() => _currentPage++)
                              : null,
                          color: _currentPage < _totalPages - 1
                              ? Colors.blue
                              : Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  // Editor and Preview Area
                  Expanded(
                    child: Column(
                      children: [
                        // PDF Preview (now at the top)
                        if (_showPreview)
                          Expanded(
                            flex: 1,
                            child: Container(
                              margin: EdgeInsets.fromLTRB(16, 16, 16, 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: SfPdfViewer.network(
                                  widget.pdfUrl,
                                  initialPageNumber: _currentPage + 1,
                                  pageSpacing: 0,
                                  enableDoubleTapZooming: true,
                                ),
                              ),
                            ),
                          ),
                        // Text Editor (now at the bottom)
                        Expanded(
                          flex: _showPreview ? 1 : 2,
                          child: Container(
                            margin: EdgeInsets.fromLTRB(
                                16, 8, 16, 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  TextField(
                                    controller: _pageControllers[_currentPage],
                                    maxLines: null,
                                    textAlign: TextAlign.justify,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: Colors.black87,
                                    ),
                                    decoration: InputDecoration(
                                      contentPadding: EdgeInsets.all(16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.grey[300]!),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.grey[300]!),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                            color: Colors.blue, width: 2),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      hintText: 'Edit text here...',
                                      hintStyle:
                                          TextStyle(color: Colors.grey[400]),
                                    ),
                                  ),
                                  Positioned(
                                    right: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.grey[200]?.withOpacity(0.8),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${_pageControllers[_currentPage].text.split(' ').where((word) => word.isNotEmpty).length} words',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: EdgeInsets.all(16),
      ),
    );
  }

Future<void> _savePdf() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get original document data
    final docSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('documents')
        .doc(widget.documentId)
        .get();
    
    final originalData = docSnapshot.data() ?? {};

    // Create new PDF document
    final newPdfDoc = PdfDocument();

    // Transfer content to new document
    for (int i = 0; i < _totalPages; i++) {
      // Add new page
      final page = newPdfDoc.pages.add();
      
      // Clear existing content by setting white background
      page.graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(255, 255, 255)),
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, page.getClientSize().height)
      );

      // Add new text content
      page.graphics.drawString(
        _pageControllers[i].text,
        PdfStandardFont(PdfFontFamily.helvetica, 12),
        brush: PdfSolidBrush(PdfColor(0, 0, 0)),
        bounds: Rect.fromLTWH(
          0, 0, page.getClientSize().width, page.getClientSize().height
        ),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.left,
          lineAlignment: PdfVerticalAlignment.top
        )
      );
    }

    // Save new PDF
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/${widget.fileName}';
    final file = File(path);
    final pdfBytes = await newPdfDoc.save();
    await file.writeAsBytes(pdfBytes);

    // Upload to Firebase
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users/${user.uid}/documents/${widget.fileName}');
    await storageRef.putFile(file);
    final newUrl = await storageRef.getDownloadURL();

    // Update Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('documents')
        .doc(widget.documentId)
        .update({
      ...originalData,
      'size': pdfBytes.length,
      'fileUrl': newUrl,
      'pageCount': _totalPages,
      'lastEdited': FieldValue.serverTimestamp(),
    });

    _showSuccess('PDF saved successfully!');
    
    // Cleanup
    newPdfDoc.dispose();
    
  } catch (e) {
    _showError('Error saving PDF: $e');
  }
}

  @override
  void dispose() {
    for (var controller in _pageControllers) {
      controller.dispose();
    }
    super.dispose();
  }
}
