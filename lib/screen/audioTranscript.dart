import 'package:flutter/material.dart';

class AudioTranscriptPage extends StatelessWidget {
  final String audioName;
  final String transcript;

  const AudioTranscriptPage({
    required this.audioName,
    required this.transcript,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transcript'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display audio name
            _buildSectionTitle('Audio Name:'),
            const SizedBox(height: 8),
            _buildContentText(audioName.isNotEmpty ? audioName : 'No audio name provided.'),

            const SizedBox(height: 16),

            // Display transcript
            _buildSectionTitle('Transcript:'),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: _buildContentText(
                  transcript.isNotEmpty
                      ? transcript
                      : 'No transcript available for this audio.',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Reusable widget for section titles
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

  // Reusable widget for content text
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
