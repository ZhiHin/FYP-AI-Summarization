// audioTranscript.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AudioTranscriptPage extends StatefulWidget {
  final String audioName;
  final String transcript;

  const AudioTranscriptPage({
    required this.audioName,
    required this.transcript,
    Key? key,
  }) : super(key: key);

  @override
  State<AudioTranscriptPage> createState() => _AudioTranscriptPageState();
}

class _AudioTranscriptPageState extends State<AudioTranscriptPage> {
  bool _isGeneratingPdf = false;

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.transcript));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript copied to clipboard')),
    );
  }

Future<void> _generateAndUploadPdf() async {
  setState(() => _isGeneratingPdf = true);
  
  try {
    final pdf = pw.Document();
    
    // Define page format and margins
    final pageFormat = PdfPageFormat.a4;
    const margin = 40.0;
    
    // Improved text styles with better sizing and line height
    final textStyle = pw.TextStyle(
      fontSize: 20,
      lineSpacing: 1.5,
    );
    final titleStyle = pw.TextStyle(
      fontSize: 25, 
      fontWeight: pw.FontWeight.bold,
    );
    
    // Create title and get content
    final title = 'Audio Transcript: ${widget.audioName}';
    final content = widget.transcript;
    
    // Enhanced text splitting function
    List<String> _splitTextIntoPages(
      String text, 
      pw.TextStyle style, 
      double pageWidth, 
      double pageHeight
    ) {
      final pages = <String>[];
      String remainingText = text.trim();
      
      // More precise page capacity calculation
      final lineHeight = style.fontSize! * 1.5;
      final availableHeight = pageHeight - 100; // Reserve space for title and margins
      final linesPerPage = (availableHeight / lineHeight).floor();
      final charsPerLine = (pageWidth / (style.fontSize! * 0.2)).floor();
      final estimatedCharsPerPage = linesPerPage * charsPerLine;
      
      while (remainingText.isNotEmpty) {
        // Intelligent page breaking
        String pageText = remainingText.length > estimatedCharsPerPage
            ? remainingText.substring(0, estimatedCharsPerPage)
            : remainingText;
        
        // Advanced breaking strategies
        final breakStrategies = [
          // 1. Break at double newline (paragraph)
          () => pageText.lastIndexOf('\n\n'),
          
          // 2. Break at single newline
          () => pageText.lastIndexOf('\n'),
          
          // 3. Break at full words near page end
          () {
            final threeQuarterIndex = (pageText.length * 0.75).toInt();
            return pageText.lastIndexOf(' ', threeQuarterIndex);
          },
          
          // 4. Break at the last space
          () => pageText.lastIndexOf(' '),
        ];
        
        // Find optimal break point
        int breakPoint = -1;
        for (var strategy in breakStrategies) {
          breakPoint = strategy();
          if (breakPoint != -1 && breakPoint > 0) {
            pageText = pageText.substring(0, breakPoint);
            break;
          }
        }
        
        // Finalize page text
        pageText = pageText.trimRight();
        pages.add(pageText);
        
        // Remove used text
        remainingText = remainingText.substring(pageText.length).trimLeft();
        
        // Prevent tiny last pages
        if (remainingText.length < estimatedCharsPerPage / 4 && pages.isNotEmpty) {
          pages[pages.length - 1] += ' ' + remainingText;
          remainingText = '';
        }
      }
      
      return pages;
    }
    
    // Split content into pages with improved calculation
    final contentPages = _splitTextIntoPages(
      content, 
      textStyle, 
      pageFormat.availableWidth - margin * 2, 
      pageFormat.availableHeight - margin * 2
    );
    
    // Generate PDF pages with better layout
    for (int i = 0; i < contentPages.length; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(margin),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Title only on first page
                if (i == 0) ...[
                  pw.Text(title, style: titleStyle),
                  pw.SizedBox(height: 20),
                ],
                
                // Page number
                pw.Text(
                  'Page ${i + 1} of ${contentPages.length}', 
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey)
                ),
                pw.SizedBox(height: 10),
                
                // Content with improved readability
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
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Check for existing documents with the same name
    String baseFileName = '${widget.audioName}_transcript.pdf';
    String fileName = baseFileName;
    int counter = 1;

    // Query Firestore to check for existing documents
    final existingDocsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('documents')
        .where('title', isEqualTo: fileName)
        .get();

    // Modify filename if document already exists
    while (existingDocsQuery.docs.isNotEmpty) {
      fileName = '${widget.audioName}_transcript(${counter}).pdf';
      
      // Re-check with the new filename
      final reCheckQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .where('title', isEqualTo: fileName)
          .get();
      
      if (reCheckQuery.docs.isEmpty) {
        break;
      }
      
      counter++;
    }

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
      'title': fileName,
      'documentType': 'pdf',
      'fileUrl': downloadUrl,
      'folderId': null,
      'pageCount': contentPages.length,
      'size': bytes.length,
      'uploadedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF saved successfully (${contentPages.length} pages) as $fileName')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: _copyToClipboard,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _isGeneratingPdf ? null : _generateAndUploadPdf,
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Audio Name:'),
                const SizedBox(height: 8),
                _buildContentText(widget.audioName),
                const SizedBox(height: 16),
                _buildSectionTitle('Transcript:'),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildContentText(widget.transcript),
                  ),
                ),
              ],
            ),
          ),
          if (_isGeneratingPdf)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Colors.blueAccent,
      ),
    );
  }

  Widget _buildContentText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        color: Colors.black87,
      ),
    );
  }
}