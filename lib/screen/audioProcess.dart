import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';

import 'audioTranscript.dart';

class AudioProcessPage extends StatefulWidget {
  @override
  _AudioProcessPageState createState() => _AudioProcessPageState();
}

class _AudioProcessPageState extends State<AudioProcessPage> {
  String? _transcribedText;
  bool _isLoading = false;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // Function to pick and upload the audio file
  Future<void> _pickAndUploadAudioFile() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to upload audio')),
      );
      return;
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _transcribedText = null;
      });

      try {
        File selectedFile = File(result.files.single.path!);
        String fileName = result.files.single.name;
        String audioId = DateTime.now().millisecondsSinceEpoch.toString();

        // Upload to Firebase Storage
        Reference firebaseStorageRef = FirebaseStorage.instance
            .ref()
            .child('users/${currentUser!.uid}/audios/$fileName');

        UploadTask uploadTask = firebaseStorageRef.putFile(selectedFile);
        TaskSnapshot taskSnapshot = await uploadTask;
        String fileUrl = await taskSnapshot.ref.getDownloadURL();

        // Save metadata to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('audios')
            .doc(audioId)
            .set({
          'audioId': audioId,
          'fileName': fileName,
          'fileUrl': fileUrl,
          'uploadedAt': Timestamp.now(),
          'transcribed': false, // Add a flag to track transcription status
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Audio uploaded successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Function to delete the audio from Firestore and Firebase Storage
  Future<void> _deleteAudio(String audioId, String fileUrl) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to delete audio')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Delete from Firebase Storage
      final ref = FirebaseStorage.instance.refFromURL(fileUrl);
      await ref.delete();

      // Delete metadata from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('audios')
          .doc(audioId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Audio deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting audio: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to generate a transcript
  Future<void> _generateTranscript(String audioId, String fileUrl) async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please log in to generate transcript')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _transcribedText = null;
    });

    try {
      // Fetch the file URL from Firestore
      DocumentSnapshot audioDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('audios')
          .doc(audioId)
          .get();

      String correctFileUrl = audioDoc['fileUrl'];

      // Validate the URL
      if (correctFileUrl.isEmpty || !correctFileUrl.startsWith('https://')) {
        throw Exception('Invalid file URL');
      }

      // Download the file from Firebase Storage
      final tempDir = await getTemporaryDirectory();
      final localFilePath = '${tempDir.path}/$audioId.mp3';

      final ref = FirebaseStorage.instance.refFromURL(correctFileUrl);
      await ref.writeToFile(File(localFilePath));

      // Verify file exists and is not empty
      File downloadedFile = File(localFilePath);
      if (!await downloadedFile.exists() ||
          await downloadedFile.length() == 0) {
        throw Exception('Failed to download audio file');
      }

      // Detailed file information logging
      print('Audio ID: $audioId');
      print('Local File Path: $localFilePath');
      print('File Exists: ${await downloadedFile.exists()}');
      print('File Size: ${await downloadedFile.length()} bytes');

      // Create a multipart request manually with more detailed logging
      var uri = Uri.parse('http://192.168.1.106:8000/audio_to_text');
      var request = http.MultipartRequest('POST', uri);

      // Add ALL possible fields
      request.fields['audioId'] = audioId;
      request.fields['audiold'] = audioId;
      request.fields['audio_id'] = audioId;

      var multipartFile = await http.MultipartFile.fromPath(
          'file', localFilePath,
          filename: 'audio.mp3', contentType: MediaType('audio', 'mpeg'));

      // Log multipart file details
      print('Multipart Filename: ${multipartFile.filename}');
      print('Multipart Content Type: ${multipartFile.contentType}');

      request.files.add(multipartFile);

      // Log all fields being sent
      print('Request Fields: ${request.fields}');
      print('Request Files: ${request.files.map((f) => f.filename)}');

      try {
        var response = await request.send();

        // Get the response body for more detailed error information
        var responseBody = await response.stream.bytesToString();

        print('Response Status Code: ${response.statusCode}');
        print('Full Response Body: $responseBody');

        if (response.statusCode == 200) {
          var decodedResponse = json.decode(responseBody);

          setState(() {
            _transcribedText =
                decodedResponse['transcription'] ?? 'No text transcribed';
          });

          // Update Firestore to mark as transcribed
          await FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser!.uid)
              .collection('audios')
              .doc(audioId)
              .update({
            'transcribed': true,
            'transcriptText': _transcribedText,
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Transcription completed')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Transcription failed: ${response.statusCode}\n$responseBody'),
              duration: Duration(seconds: 5),
            ),
          );
        }
      } catch (sendError) {
        print('Request Send Error: $sendError');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request Send Error: $sendError'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Transcription Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error in transcription: $e'),
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Function to build the list of uploaded audios
  Widget _buildAudioList() {
    if (currentUser == null) {
      return Center(child: Text('Please log in to view your audios.'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('audios')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        var audios = snapshot.data!.docs;

        if (audios.isEmpty) {
          return Center(child: Text('No audio files found.'));
        }

        return ListView.builder(
          itemCount: audios.length,
          itemBuilder: (context, index) {
            var audio = audios[index];
            String audioId = audio['audioId'];
            String audioName = audio['fileName'];
            String fileUrl = audio['fileUrl'];
            bool isTranscribed = audio['transcribed'] ?? false;

            return Card(
              child: ListTile(
                title: Text(audioName),
                subtitle: isTranscribed
                    ? Text('Transcribed', style: TextStyle(color: Colors.green))
                    : Text('Not Transcribed',
                        style: TextStyle(color: Colors.red)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.transcribe),
                      onPressed: isTranscribed
                          ? null // Disable the button if already transcribed
                          : () async {
                              setState(() {
                                _isLoading = true; // Show loading indicator
                              });

                              try {
                                // Call the transcription method to generate the transcript
                                await _generateTranscript(audioId, fileUrl);

                                if (!mounted) return;

                                // Fetch the updated transcript from Firestore after generating
                                DocumentSnapshot docSnapshot =
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(currentUser!.uid)
                                        .collection('audios')
                                        .doc(audioId)
                                        .get();

                                String transcriptText =
                                    docSnapshot['transcriptText'] ??
                                        'No transcript available';

                                if (!mounted) return;

                                // Navigate to the transcript page with the transcript content
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AudioTranscriptPage(
                                      audioName: audioName,
                                      transcript: transcriptText,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;

                                // Show error message if any issue occurs
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Error generating transcript: $e')),
                                );
                              } finally {
                                if (mounted) {
                                  setState(() {
                                    _isLoading =
                                        false; // Hide loading indicator
                                  });
                                }
                              }
                            },
                    ),
                    if (isTranscribed)
                      IconButton(
                        icon: const Icon(Icons.text_snippet),
                        onPressed: () async {
                          try {
                            // Show loading indicator
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) {
                                return const Center(
                                    child: CircularProgressIndicator());
                              },
                            );

                            // Retrieve the transcript from Firestore
                            DocumentSnapshot doc = await FirebaseFirestore
                                .instance
                                .collection('users')
                                .doc(currentUser!.uid)
                                .collection('audios')
                                .doc(audioId)
                                .get();

                            // Close the loading indicator
                            Navigator.of(context).pop();

                            if (doc.exists) {
                              String transcriptText = doc['transcriptText'] ??
                                  'No transcript available';
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AudioTranscriptPage(
                                    audioName: audioName,
                                    transcript: transcriptText,
                                  ),
                                ),
                              );
                            } else {
                              // Show error message if document doesn't exist
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Transcript not found.')),
                              );
                            }
                          } catch (e) {
                            // Close the loading indicator if an error occurs
                            Navigator.of(context).pop();

                            // Display an error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Failed to fetch transcript: $e')),
                            );
                          }
                        },
                      ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _deleteAudio(audioId, fileUrl),
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
              onPressed: _pickAndUploadAudioFile,
              child: Text('Select and Upload Audio File'),
            ),
            Expanded(child: _buildAudioList()),
            if (_isLoading) Center(child: CircularProgressIndicator()),
            // if (_transcribedText != null)
            //   Expanded(
            //     child: SingleChildScrollView(
            //       child: Card(
            //         child: Padding(
            //           padding: const EdgeInsets.all(16.0),
            //           child: Text(
            //             _transcribedText!,
            //             style: TextStyle(fontSize: 16),
            //           ),
            //         ),
            //       ),
            //     ),
            //   ),
          ],
        ),
      ),
    );
  }
}
