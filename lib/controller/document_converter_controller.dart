import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as syncfusion_pdf;
import '../model/document_model.dart';

class DocumentConverterController {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    // TODO: Implement Word to PDF conversion
    throw UnimplementedError();
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
        uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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
