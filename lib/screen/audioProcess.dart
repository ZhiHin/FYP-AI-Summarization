// audio_process_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../controller/audio_controller.dart';
import '../model/audio_model.dart';
import 'audioTranscript.dart';


class AudioProcessPage extends StatefulWidget {
  @override
  _AudioProcessPageState createState() => _AudioProcessPageState();
}

class _AudioProcessPageState extends State<AudioProcessPage> {
  final AudioController _audioController = AudioController();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Processing'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton(
              onPressed: () async {
                setState(() => _isLoading = true);
                await _audioController.pickAndUploadAudioFile(context);
                setState(() => _isLoading = false);
              },
              child: Text('Select and Upload Audio File'),
            ),
            Expanded(child: _buildAudioList()),
            if (_isLoading) Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioList() {
    User? currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return Center(child: Text('Please log in to view your audios.'));
    }

    return StreamBuilder<List<AudioModel>>(
      stream: _audioController.getAudioList(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var audios = snapshot.data!;

        if (audios.isEmpty) {
          return Center(child: Text('No audio files found.'));
        }

        return ListView.builder(
          itemCount: audios.length,
          itemBuilder: (context, index) {
            var audio = audios[index];

            return Card(
              child: ListTile(
                title: Text(audio.fileName),
                subtitle: audio.transcribed
                    ? Text('Transcribed', style: TextStyle(color: Colors.green))
                    : Text('Not Transcribed', style: TextStyle(color: Colors.red)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.transcribe),
                      onPressed: audio.transcribed
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              String? transcriptText = await _audioController
                                  .generateTranscript(context, audio.audioId, audio.fileUrl);
                              
                              if (transcriptText != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AudioTranscriptPage(
                                      audioName: audio.fileName,
                                      transcript: transcriptText,
                                    ),
                                  ),
                                );
                              }
                              
                              setState(() => _isLoading = false);
                            },
                    ),
                    if (audio.transcribed)
                      IconButton(
                        icon: const Icon(Icons.text_snippet),
                        onPressed: () {
                          if (audio.transcriptText != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AudioTranscriptPage(
                                  audioName: audio.fileName,
                                  transcript: audio.transcriptText!,
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _audioController.deleteAudio(
                        context, 
                        audio.audioId, 
                        audio.fileUrl,
                        () => mounted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}