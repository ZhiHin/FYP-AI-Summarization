import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:process_run/process_run.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:docx_to_text/docx_to_text.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import 'package:path/path.dart' as path;
import '../model/document_model.dart';

class DocumentConverterController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final String _projectId = 'fyp-ai-summarization';
  final String _clientEmail =
      'rando-212@fyp-ai-summarization.iam.gserviceaccount.com';
  final String _privateKey =
      "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCrPiEpTLcIJQe7\nM3I+Q6r+QkPWiGDc5sOPz7Fb7fRb5hMfKfBMz9nSlExdtC+lqDZPKjBIM44dbFu8\nlzukAq4rN7k+uwuBxN7IuRLcD1KId2BqgMMRuBpE4uFUssE61DuuaMI9LEshcsHx\nzEgCC6XdcDN9P0RAqtv7tGNu+ouD4rNat1aq7lC/naIBzK+w9GnhKjgTYxgTNv2Y\nk2MYZ3HOwoFIqW4bkg3meggs4A+9ixFbXdcZZIHhGySOq+oVRUbAupgruMzSyqDK\nF+BdJ/MtbbtP7tH4nM7v0ku43/AU6zQn3OB599xDR1ehQHUAji/QSUfIJm01SiyJ\nhX9LLBT/AgMBAAECggEACO7hS6Zrspo9Qy1FtkImb0QlW3wwKBCbvr/+yG/Akci4\np6VdmqGJ2Jvm40ktO87rd7QY4l4EzxEiNKjjshnNBzEi0fHFAbyI7goFlgLwncYz\nJUCEAe52ObC864O1uSwYKZrfwybb4Sn7kccZMeN0qs7Ec4deN/dnKW7OycZ6imMu\nd5prYyXhXF7h3UUmpwjv9MxKR+pYTVbSi4tHsuHP4rfQgakn84XtXmfMtwgZdF2e\nOHMQkzyMJ4I5PItQV3MIXQilzIKD004v5EDqIhiRExHk4pUeKQKCNqNWBDIjBSoY\nA4A9FFw+hHFW1UIxkz1F1HoZPbCNZoHg8vAIQSCqiQKBgQDYezysgxrqXEScFYoE\nXR0+tdUAEF7efKyqHhbn9KibKukk4Sf4O12Ncfnl8ysiZdrhNiOa1/rkSJSZTAuX\naG756YN3DBcDseHGRCqX25mlP7UXAxCmeQTTWydV9mZpADwe/S39GPs/rtFsOJf7\npAgSjyi1q+3DOCCJnq2+yn2pRwKBgQDKgMPo7KN5/Ng873EQE4Mt/A2XPi/NCWIp\nd/p45/QYVPlBVlieLCRPm9ypvqTao0YD4vzh5BqNGwylopr3E/fF1Ag64fuXP1Wp\n2yRAziFHoOW8Kd+/yZMGI+VUUUIWmhkPoYw2iZWmM02NKnTR3IEK0L0aKCrniQdh\n4stuso6SiQKBgFHIpRBra2S0vPrWrFCfuOezHCgtBxo4saaHPZId/QC6AmB7a3U9\nQEeqkoVMC7SwFDPXFzZteAx8Wx9a+loWCy8BCDiWaa9sqWYU5J6ASRiD6+8oqkaq\nG6eZnU+9ic0LWKtAbPpcULcrXVTsQIbB3obcbL3NmUKSVsCHIQ6eQ0ELAoGAN7U2\nr+QxkMSDBDhmpSKJCuR1JK9B3SkArSHJcOt2lh8CNvw3AsRn9NKO4M+GcHNMNpOC\nN+5Vc44Ga6aQ9Pm0RuLupKw4V0JgIYscrQtH0nmr2Zi3af5dCOplE04LXUZlMIyj\nkvlEhuVEJ1qPqo/7m+sSqph0PR/QPRh0GG7ck+kCgYEAkTEixKgvsj+3HoVRUCd/\nEkmsjcBGVCwV76go99kagm+RAV0UOUhrPExSsKmzgFYbYmEE7W3h+rnCiLO7A53q\nUFO7Rn5xFuXDJneXJ33LEGHjSjVLqevY6JJUfvF8qnc+2NWsTyxaBNtIQC9yL/MA\nBTYNGwZPTmqZCCNr+sQ6xnQ=\n-----END PRIVATE KEY-----\n"; // Your private key

  Future<Document?> convertDocument(
    File sourceFile, {
    String? folderId,
    String? description,
    Function(double)? onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Validate file
      if (!await sourceFile.exists()) {
        throw Exception('Source file does not exist');
      }

      DocumentType inputType = getDocumentType(sourceFile.path);
      String fileName = sourceFile.path.split('/').last;
      int fileSize = await sourceFile.length();
      String targetFormat = _determineTargetFormat(inputType);

      // Create temp output path
      final tempDir = await Directory.systemTemp.createTemp();
      final outputPath =
          '${tempDir.path}/${fileName.replaceAll('.${fileName.split('.').last}', '.$targetFormat')}';

      // Convert file
      await _convertFile(
        sourceFile,
        outputPath,
        inputType,
        onProgress: onProgress,
      );

      // Upload to Firebase
      final storageRef = _storage
          .ref()
          .child('users/${user.uid}/converted_documents/$fileName');

      final uploadTask = storageRef.putFile(File(outputPath));

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Get page count
      final pageCount = await _getPageCount(sourceFile);

      // Create document
      final document = Document(
        id: '',
        title: fileName,
        description: description ?? '',
        size: fileSize,
        uploadedAt: DateTime.now(),
        pageCount: pageCount,
        fileUrl: downloadUrl,
        folderId: folderId,
        documentType: getDocumentType(outputPath),
        originalFormat: inputType.toString().split('.').last,
        convertedFormat: targetFormat,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .add(document.toFirestore());

      // Update folder count if needed
      if (folderId != null) {
        await _updateFolderDocumentCount(user.uid, folderId, 1);
      }

      // Cleanup temp files
      await tempDir.delete(recursive: true);

      return document.copyWith(id: docRef.id);
    } catch (e) {
      print('Document conversion error: $e');
      return null;
    }
  }

  Future<void> _convertFile(
    File sourceFile,
    String outputPath,
    DocumentType inputType, {
    Function(double)? onProgress,
  }) async {
    try {
      switch (inputType) {
        case DocumentType.pdf:
          await _convertPdfToWord(sourceFile, outputPath, onProgress);
          break;
        case DocumentType.word:
          await _convertWordToPdf(sourceFile, outputPath, onProgress);
          break;
        default:
          throw Exception('Unsupported conversion type');
      }
    } catch (e) {
      print('Conversion error: $e');
      rethrow;
    }
  }

  Future<void> _convertPdfToWord(
    File pdfFile,
    String outputPath,
    Function(double)? onProgress,
  ) async {
    try {
      final document =
          syncfusion_pdf.PdfDocument(inputBytes: await pdfFile.readAsBytes());

      final extractor = syncfusion_pdf.PdfTextExtractor(document);
      final totalPages = document.pages.count;
      String extractedText = '';

      for (var i = 0; i < totalPages; i++) {
        extractedText += extractor.extractText(startPageIndex: i);
        onProgress?.call((i + 1) / totalPages);
      }

      await File(outputPath).writeAsString(extractedText);
      document.dispose();
    } catch (e) {
      print('PDF conversion error: $e');
      rethrow;
    }
  }

  Future<void> _convertWordToPdf(
  File wordFile,
  String outputPath,
  Function(double)? onProgress,
) async {
  try {
    // Verify input file
    if (!wordFile.existsSync()) {
      throw Exception('Input file does not exist');
    }
    
    final extension = path.extension(wordFile.path).toLowerCase();
    if (extension != '.doc' && extension != '.docx') {
      throw Exception('Invalid Word document format');
    }

    onProgress?.call(0.2);

    // Create PDF document
    final pdf = pw.Document();
    
    String text;
    if (extension == '.docx') {
      // Extract text from DOCX
      final bytes = await wordFile.readAsBytes();
      text = await docxToText(bytes);
    } else {
      // For .doc files, you might need a different approach
      throw Exception('Legacy .doc format is not supported. Please convert to .docx first.');
    }

    onProgress?.call(0.5);

    // Create PDF page with text
    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(text),
            ],
          );
        },
      ),
    );

    onProgress?.call(0.8);

    // Save the PDF
    final file = File(outputPath);
    await file.writeAsBytes(await pdf.save());

    onProgress?.call(1.0);
  } catch (e) {
    print('Word to PDF conversion error: $e');
    rethrow;
  }
}

  Future<int> _getPageCount(File file) async {
    try {
      if (getDocumentType(file.path) == DocumentType.pdf) {
        final document =
            syncfusion_pdf.PdfDocument(inputBytes: await file.readAsBytes());
        final count = document.pages.count;
        document.dispose();
        return count;
      }
      return 0;
    } catch (e) {
      print('Error getting page count: $e');
      return 0;
    }
  }

  String _determineTargetFormat(DocumentType inputType) {
    switch (inputType) {
      case DocumentType.pdf:
        return 'docx';
      case DocumentType.word:
        return 'pdf';
      default:
        return 'pdf';
    }
  }

  Future<void> _updateFolderDocumentCount(
    String userId,
    String folderId,
    int increment,
  ) async {
    try {
      final folderRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('folders')
          .doc(folderId);

      await _firestore.runTransaction((transaction) async {
        final folderSnapshot = await transaction.get(folderRef);
        if (!folderSnapshot.exists) return;

        final currentCount = folderSnapshot.get('documentCount') ?? 0;
        transaction
            .update(folderRef, {'documentCount': currentCount + increment});
      });
    } catch (e) {
      print('Error updating folder count: $e');
    }
  }

  Future<List<Document>> getDocuments() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('Debug: User not authenticated');
        throw Exception('User not authenticated');
      }

      print('Debug: Fetching documents for user ${user.uid}');

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .get();

      print('Debug: Found ${querySnapshot.docs.length} documents');

      if (querySnapshot.docs.isEmpty) {
        print('Debug: No documents found');
        return [];
      }

      final documents = querySnapshot.docs.map((doc) {
        final data = doc.data();
        print('Debug: Document data: $data');

        return Document(
          id: doc.id,
          title: data['name'] ?? '',
          fileUrl: data['fileUrl'] ?? '',
          uploadedAt:
              (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          size: data['size'] ?? 0,
          documentType: _getDocumentType(data['documentType'] ?? ''),
          originalFormat: data['documentType'] ?? '',
          convertedFormat: data['convertedFormat'] ?? '',
          pageCount: data['pageCount'] ?? 0,
        );
      }).toList();

      print('Debug: Processed ${documents.length} documents');
      return documents;
    } catch (e) {
      print('Debug: Error in getDocuments: $e');
      return [];
    }
  }

  DocumentType _getDocumentType(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return DocumentType.pdf;
      case 'doc':
      case 'docx':
        return DocumentType.word;
      default:
        return DocumentType.other;
    }
  }

  Future<Document?> convertDocumentFromUrl(
    Document sourceDocument, {
    Function(double)? onProgress,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Download the file from the Firebase URL
      final tempDir = await Directory.systemTemp.createTemp();
      final fileName = sourceDocument.title;
      final tempFilePath = '${tempDir.path}/$fileName';

      // Download file from URL
      final HttpClient client = HttpClient();
      final request = await client.getUrl(Uri.parse(sourceDocument.fileUrl));
      final response = await request.close();
      final bytes = await consolidateHttpClientResponseBytes(response);
      await File(tempFilePath).writeAsBytes(bytes);

      // Determine input type and target format
      final inputType = getDocumentType(tempFilePath);
      final File sourceFile = File(tempFilePath);

      // Convert the downloaded file
      final targetFormat = _determineTargetFormat(inputType);
      final outputPath =
          '${tempDir.path}/${fileName.replaceAll('.${fileName.split('.').last}', '.$targetFormat')}';

      // Convert file
      await _convertFile(
        sourceFile,
        outputPath,
        inputType,
        onProgress: onProgress,
      );

      // Upload to Firebase
      final storageRef = _storage
          .ref()
          .child('users/${user.uid}/converted_documents/$fileName');

      final uploadTask = storageRef.putFile(File(outputPath));

      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Get page count
      final pageCount = await _getPageCount(sourceFile);

      // Create document
      final document = Document(
        id: '',
        title: fileName.replaceAll(
            '.${fileName.split('.').last}', '.$targetFormat'),
        description: sourceDocument.description ?? '',
        size: await File(outputPath).length(),
        uploadedAt: DateTime.now(),
        pageCount: pageCount,
        fileUrl: downloadUrl,
        folderId: sourceDocument.folderId,
        documentType: getDocumentType(outputPath),
        originalFormat: inputType.toString().split('.').last,
        convertedFormat: targetFormat,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .add(document.toFirestore());

      // Cleanup temp files
      await tempDir.delete(recursive: true);

      return document.copyWith(id: docRef.id);
    } catch (e) {
      print('Document conversion from URL error: $e');
      return null;
    }
  }
}
