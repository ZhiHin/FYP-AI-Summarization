import 'package:cloud_firestore/cloud_firestore.dart';

// Enum for document types
enum DocumentType { pdf, document, spreadsheet, presentation, other }

// Utility function to determine document type
DocumentType getDocumentType(String fileName) {
  final extension = fileName.toLowerCase().split('.').last;
  switch (extension) {
    case 'pdf':
      return DocumentType.pdf;
    case 'docx':
    case 'doc':
      return DocumentType.document;
    case 'xlsx':
    case 'xls':
      return DocumentType.spreadsheet;
    case 'pptx':
    case 'ppt':
      return DocumentType.presentation;
    default:
      return DocumentType.other;
  }
}

// Document class to represent a document
class Document {
  final String id;
  final String title;
  final String? description;
  final int size;
  final DateTime uploadedAt;
  final int pageCount;
  final String fileUrl;
  final String? folderId;
  final DocumentType documentType;
  final String originalFormat;
  final String convertedFormat;

  Document({
    required this.id,
    required this.title,
    this.description,
    required this.size,
    required this.uploadedAt,
    this.pageCount = 0,
    required this.fileUrl,
    this.folderId,
    required this.documentType,
    this.originalFormat = '',
    this.convertedFormat = '',
  });

  Document copyWith({
    String? id,
    String? title,
    String? description,
    int? size,
    DateTime? uploadedAt,
    int? pageCount,
    String? fileUrl,
    String? folderId,
    DocumentType? documentType,
    String? originalFormat,
    String? convertedFormat,
  }) {
    return Document(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      size: size ?? this.size,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      pageCount: pageCount ?? this.pageCount,
      fileUrl: fileUrl ?? this.fileUrl,
      folderId: folderId ?? this.folderId,
      documentType: documentType ?? this.documentType,
      originalFormat: originalFormat ?? this.originalFormat,
      convertedFormat: convertedFormat ?? this.convertedFormat,
    );
  }

  // Factory constructor to create a Document from Firestore data
  factory Document.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Document(
      id: doc.id,
      title: data['title'],
      description: data['description'],
      size: data['size'],
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      pageCount: data['pageCount'] ?? 0,
      fileUrl: data['fileUrl'],
      folderId: data['folderId'],
      documentType: getDocumentType(data['title']),
      originalFormat: data['originalFormat'] ?? '',
      convertedFormat: data['convertedFormat'] ?? '',
    );
  }

  // Convert Document to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description ?? '',
      'size': size,
      'uploadedAt': uploadedAt,
      'pageCount': pageCount,
      'fileUrl': fileUrl,
      'folderId': folderId,
      'documentType': documentType.toString().split('.').last,
      'originalFormat': originalFormat,
      'convertedFormat': convertedFormat,
    };
  }
}

// Folder class to represent a folder
class Folder {
  final String id;
  final String name;
  final DateTime createdAt;
  final String? parentFolderId;
  final int documentCount;

  Folder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.parentFolderId,
    this.documentCount = 0,
  });

  // Factory constructor to create a Folder from Firestore data
  factory Folder.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Folder(
      id: doc.id,
      name: data['name'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      parentFolderId: data['parentFolderId'],
      documentCount: data['documentCount'] ?? 0,
    );
  }

  // Convert Folder to a map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'createdAt': createdAt,
      'parentFolderId': parentFolderId,
      'documentCount': documentCount,
    };
  }
}
