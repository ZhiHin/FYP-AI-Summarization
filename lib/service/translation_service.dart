import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

class TranslationService {
  final String apiKey = 'AIzaSyByDAK7GNIOrmcpqq5wRozrxQUOSH5EOfA';
  static const int maxChunkSize = 1000; // Reduce chunk size
  static const int maxRetries = 3;

  Future<String> translateText(String text, String targetLanguage) async {
    final url = Uri.https(
      'translation.googleapis.com',
      '/language/translate/v2',
      {
        'q': text,
        'target': targetLanguage,
        'key': apiKey,
      },
    );

    final response = await http.post(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final translatedText = data['data']['translations'][0]['translatedText'];
      return translatedText;
    } else {
      throw Exception('Failed to translate text');
    }
  }

  Future<String> translateDocument(
    String fileUrl, 
    String targetLanguage,
    {required Function(double progress, int characters) onProgress}
  ) async {
    try {
      // Download PDF
      final ref = FirebaseStorage.instance.refFromURL(fileUrl);
      final bytes = await ref.getData();
      if (bytes == null) throw Exception('Could not download document');

      // Extract text properly from PDF
      final sf.PdfDocument document = sf.PdfDocument(inputBytes: bytes);
      final sf.PdfTextExtractor extractor = sf.PdfTextExtractor(document);
      String content = '';
      
      // Extract text page by page
      for (int i = 0; i < document.pages.count; i++) {
        content += extractor.extractText(startPageIndex: i) + '\n\n';
      }
      
      content = content.trim();
      onProgress(0.2, content.length);

      // Split into smaller chunks preserving paragraphs
      List<String> chunks = content
          .split('\n\n')
          .expand((paragraph) => _splitIntoChunks(paragraph, maxChunkSize))
          .toList();

      List<String> translatedChunks = [];
      
      // Translate each chunk
      for (var i = 0; i < chunks.length; i++) {
        String? translatedChunk;
        int retryCount = 0;
        
        while (retryCount < maxRetries && translatedChunk == null) {
          try {
            translatedChunk = await translateText(chunks[i].trim(), targetLanguage);
            print('Successfully translated chunk $i');
          } catch (e) {
            retryCount++;
            if (retryCount == maxRetries) throw e;
            await Future.delayed(Duration(seconds: 2 * retryCount));
          }
        }
        
        if (translatedChunk != null) {
          translatedChunks.add(translatedChunk);
          onProgress(0.2 + (0.7 * (i + 1) / chunks.length), content.length);
        }
      }

      document.dispose();
      return translatedChunks.join('\n\n');
    } catch (e) {
      print('Document translation error: $e');
      throw Exception('Document translation failed: $e');
    }
  }

  List<String> _splitIntoChunks(String text, int size) {
    List<String> chunks = [];
    for (var i = 0; i < text.length; i += size) {
      int end = (i + size < text.length) ? i + size : text.length;
      chunks.add(text.substring(i, end));
    }
    return chunks;
  }

  Future<String> saveTranslatedDocument(String text, String originalName, String userId) async {
  try {
    final pdf = pw.Document();
    
    // Load both Chinese and Korean fonts
    final chineseFontData = await rootBundle.load("assets/fonts/NotoSansSC-Regular.ttf");
    final koreanFontData = await rootBundle.load("assets/fonts/NotoSansKR-Regular.ttf");
    
    final chineseFont = pw.Font.ttf(chineseFontData);
    final koreanFont = pw.Font.ttf(koreanFontData);
    
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) => [
          pw.Header(
            child: pw.Text(
              'Translated Document',
              style: pw.TextStyle(
                font: chineseFont,
                fontFallback: [koreanFont],
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          ...text.split('\n').map((paragraph) => pw.Paragraph(
            text: paragraph,
            style: pw.TextStyle(
              font: chineseFont,
              fontFallback: [koreanFont],
              fontSize: 12,
              lineSpacing: 1.5,
            ),
          )).toList(),
        ],
      ),
    );

    // Generate PDF bytes
    final pdfBytes = await pdf.save();

    // Ensure filename ends with .pdf
    final fileName = originalName.toLowerCase().endsWith('.pdf') 
        ? 'translated_$originalName'
        : 'translated_$originalName.pdf';

    // Upload to Firebase Storage
    final ref = FirebaseStorage.instance
        .ref()
        .child('users/$userId/documents/$fileName');
    
    await ref.putData(
      pdfBytes,
      SettableMetadata(contentType: 'application/pdf'),
    );

    return await ref.getDownloadURL();
  } catch (e) {
    print('Error saving translated document: $e');
    throw Exception('Failed to save translated document: $e');
  }
}
}
