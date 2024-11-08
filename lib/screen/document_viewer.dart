import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class DocumentViewer extends StatelessWidget {
  final String fileName;
  final int fileSize;
  final int pageCount;
  final String fileUrl;

  const DocumentViewer({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.pageCount,
    required this.fileUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document Name: $fileName'),
            Text('File Size: ${fileSize / 1024} KB'),
            Text('Page Count: $pageCount'),
            const SizedBox(height: 16),
            Expanded(
              child: SfPdfViewer.network(fileUrl), // Displaying PDF content
            ),
          ],
        ),
      ),
    );
  }
}

