import 'package:cloud_firestore/cloud_firestore.dart';

class AudioModel {
  final String audioId;
  final String fileName;
  final String fileUrl;
  final Timestamp uploadedAt;
  final bool transcribed;
  final String? transcriptText;

  AudioModel({
    required this.audioId,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedAt,
    this.transcribed = false,
    this.transcriptText,
  });

  factory AudioModel.fromFirestore(DocumentSnapshot doc) {
  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
  return AudioModel(
    audioId: doc.id, // Use document ID as audioId
    fileName: data['name'] ?? '',
    fileUrl: data['fileUrl'] ?? '',
    uploadedAt: data['uploadedAt'] ?? Timestamp.now(),
    transcribed: data['transcribed'] ?? false,
    transcriptText: data['transcriptText'],
  );
}

  Map<String, dynamic> toFirestore() {
    return {
      'audioId': audioId,
      'name': fileName,
      'fileUrl': fileUrl,
      'uploadedAt': uploadedAt,
      'transcribed': transcribed,
      'transcriptText': transcriptText,
    };
  }
}