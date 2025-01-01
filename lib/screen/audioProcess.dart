import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import '../controller/audio_controller.dart';
import '../model/audio_model.dart';
import 'audioTranscript.dart';

class AudioProcessPage extends StatefulWidget {
  @override
  _AudioProcessPageState createState() => _AudioProcessPageState();
}

class _AudioProcessPageState extends State<AudioProcessPage> {
  final AudioController _audioController = AudioController();
  final AudioPlayer audioPlayer = AudioPlayer();
  bool _isLoading = false;
  String? currentlyPlayingId;
  bool isPlaying = false;
  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  double volume = 1.0;

  @override
  void initState() {
    super.initState();
    setupAudioPlayer();
  }

  void setupAudioPlayer() {
    audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() => duration = newDuration);
    });

    audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() => position = newPosition);
    });

    audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        isPlaying = false;
        position = Duration.zero;
        currentlyPlayingId = null;
      });
    });
  }

  String formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return [if (duration.inHours > 0) hours, minutes, seconds].join(':');
  }

  Future<void> handlePlayPause(AudioModel audio) async {
    try {
      if (currentlyPlayingId == audio.audioId) {
        if (isPlaying) {
          await audioPlayer.pause();
          setState(() => isPlaying = false);
        } else {
          await audioPlayer.resume();
          setState(() => isPlaying = true);
        }
      } else {
        if (currentlyPlayingId != null) {
          await audioPlayer.stop();
        }
        setState(() {
          currentlyPlayingId = audio.audioId;
          isPlaying = true;
        });
        await audioPlayer.play(UrlSource(audio.fileUrl));
        await audioPlayer.setVolume(volume);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Processing'),
        actions: [
          // Upload button in the app bar
          IconButton(
            icon: Icon(Icons.upload_file),
            tooltip: 'Upload Audio File',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _audioController.pickAndUploadAudioFile(context);
              setState(() => _isLoading = false);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildAudioList(),
          ),
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Processing...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
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
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.audio_file, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No audio files found',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 8),
                Text(
                  'Upload your first audio file using the button above',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: audios.length,
          itemBuilder: (context, index) {
            var audio = audios[index];
            bool isThisPlaying = currentlyPlayingId == audio.audioId;

            return Card(
              elevation: 2,
              margin: EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Icon(
                        isThisPlaying && isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    title: Text(
                      audio.fileName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    subtitle: Row(
                      children: [
                        Icon(
                          audio.transcribed ? Icons.check_circle : Icons.pending,
                          size: 16,
                          color: audio.transcribed ? Colors.green : Colors.orange,
                        ),
                        SizedBox(width: 4),
                        Text(
                          audio.transcribed ? 'Transcribed' : 'Pending transcription',
                          style: TextStyle(
                            color: audio.transcribed ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => handlePlayPause(audio),
                  ),
                  if (isThisPlaying) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(formatTime(position)),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: position.inSeconds.toDouble(),
                                    min: 0,
                                    max: duration.inSeconds.toDouble(),
                                    onChanged: (value) async {
                                      await audioPlayer.seek(Duration(seconds: value.toInt()));
                                    },
                                  ),
                                ),
                              ),
                              Text(formatTime(duration)),
                            ],
                          ),
                          Row(
                            children: [
                              Icon(Icons.volume_up, size: 20),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderThemeData(
                                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                    overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
                                    trackHeight: 4,
                                  ),
                                  child: Slider(
                                    value: volume,
                                    min: 0,
                                    max: 1,
                                    onChanged: (value) async {
                                      setState(() => volume = value);
                                      await audioPlayer.setVolume(value);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  ButtonBar(
                    children: [
                      IconButton(
                        icon: Icon(Icons.transcribe),
                        tooltip: 'Generate Transcript',
                        color: audio.transcribed ? Colors.grey : Theme.of(context).primaryColor,
                        onPressed: audio.transcribed ? null : () => _handleTranscription(audio),
                      ),
                      if (audio.transcribed)
                        IconButton(
                          icon: const Icon(Icons.text_snippet),
                          tooltip: 'View Transcript',
                          color: Theme.of(context).primaryColor,
                          onPressed: () => _viewTranscript(audio),
                        ),
                      IconButton(
                        icon: Icon(Icons.delete),
                        tooltip: 'Delete Audio',
                        color: Colors.red,
                        onPressed: () => _handleDelete(audio),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleTranscription(AudioModel audio) async {
    setState(() => _isLoading = true);
    try {
      String? transcriptText = await _audioController
          .generateTranscript(context, audio.audioId, audio.fileUrl);
      
      if (transcriptText != null && mounted) {
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
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _viewTranscript(AudioModel audio) {
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
  }

  Future<void> _handleDelete(AudioModel audio) async {
    if (currentlyPlayingId == audio.audioId) {
      await audioPlayer.stop();
      setState(() {
        currentlyPlayingId = null;
        isPlaying = false;
      });
    }
    await _audioController.deleteAudio(
      context,
      audio.audioId,
      audio.fileUrl,
      () => mounted,
    );
  }

  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }
}