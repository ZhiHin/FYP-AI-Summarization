import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class PdfGenerator {
  Future<Uint8List?> _loadImageFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error loading image: $e');
    }
    return null;
  }

  Future<void> generateSummaryPdf({
    required List<String> imageUrls,
    required List<TextEditingController> textControllers,
    required List<TextEditingController> summaryControllers,
    required String language,
    required String documentName,
  }) async {
    final pdf = pw.Document();
    final fontData;
    // Load the Noto Sans font
    if (language == 'en' || language == 'es') {
      fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    } else {
      fontData = await rootBundle.load('assets/fonts/NotoSansSC-Regular.ttf');
    }

    final ttf = pw.Font.ttf(fontData);

    // Load all images first
    List<Uint8List?> imageDataList = [];
    for (String url in imageUrls) {
      final imageData = await _loadImageFromUrl(url);
      imageDataList.add(imageData);
    }

    // Create PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          List<pw.Widget> widgets = [];

          // Add title
          widgets.add(
            pw.Header(
              level: 0,
              child: pw.Text(
                documentName,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          );
          widgets.add(pw.SizedBox(height: 20));

          // Add content for each page
          for (var i = 0; i < textControllers.length; i++) {
            // Add page number
            widgets.add(
              pw.Header(
                level: 1,
                text: 'Page ${i + 1}',
                textStyle: pw.TextStyle(
                  font: ttf,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 10));

            // Add image if available
            if (i < imageDataList.length && imageDataList[i] != null) {
              try {
                final image = pw.MemoryImage(imageDataList[i]!);
                widgets.add(
                  pw.Center(
                    child: pw.Container(
                      width: 400,
                      height: 300,
                      child: pw.Image(image, fit: pw.BoxFit.contain),
                    ),
                  ),
                );
                widgets.add(pw.SizedBox(height: 15));
              } catch (e) {
                print('Error adding image to PDF: $e');
              }
            }

            // Add original text
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Original Text:',
                      style: pw.TextStyle(
                        font: ttf,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      textControllers[i].text,
                      style: pw.TextStyle(font: ttf),
                    ),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 15));

            // Add summary
            widgets.add(
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Summary:',
                      style: pw.TextStyle(
                        font: ttf,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      summaryControllers[i].text,
                      style: pw.TextStyle(font: ttf),
                    ),
                  ],
                ),
              ),
            );
            widgets.add(pw.SizedBox(height: 20));
          }
          return widgets;
        },
      ),
    );

    // Get directory for saving PDF
    final dir = await getApplicationDocumentsDirectory();
    final String filePath =
        '${dir.path}/${documentName.replaceAll(' ', '_')}.pdf';

    // Save PDF and get page count
    final bytes = await pdf.save();
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // Open the saved PDF
    await OpenFile.open(filePath);
  }
}
