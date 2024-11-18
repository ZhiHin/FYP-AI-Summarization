import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechRecognitionScreen extends StatefulWidget {
  const SpeechRecognitionScreen({super.key});

  @override
  _SpeechRecognitionScreenState createState() =>
      _SpeechRecognitionScreenState();
}

class _SpeechRecognitionScreenState extends State<SpeechRecognitionScreen> {
  bool isListening = false; // Tracks whether speech recognition is active
  late stt.SpeechToText _speechToText; // Speech recognition instance
  String text = "Press the button & start speaking"; // Default text
  double confidence = 1.0; // Confidence level of speech recognition (range 0-1)

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText(); // Initialize speech-to-text object
  }

  // Build the UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Display confidence percentage in the app bar
        title: Text("Confidence: ${(confidence * 100).toStringAsFixed(1)}%"),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AvatarGlow(
        animate: isListening, // Animate glow when listening
        glowColor: Colors.blue, // Glow color
        duration: const Duration(milliseconds: 1000),
        repeat: true, // Repeat the glow animation
        child: FloatingActionButton(
          backgroundColor: isListening ? Colors.green : Colors.blue, // Change color based on state
          onPressed: _captureVoice, // Start or stop listening
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none, // Change icon when listening
            size: 30,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        reverse: true, // Scroll from bottom up
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              // Display recognized text
              Text(
                text,
                style: const TextStyle(fontSize: 30),
              ),
              const SizedBox(height: 20),
              // Copy text button
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text)); // Copy text to clipboard
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Successfully copied text")),
                    );
                  },
                  child: const Text(
                    "Copy Text",
                    style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Handle voice input capture
  void _captureVoice() async {
    if (!isListening) {
      // Start listening if not already listening
      bool isAvailable = await _speechToText.initialize();
      if (isAvailable) {
        setState(() => isListening = true); // Update state to reflect listening
        _speechToText.listen(
          onResult: (result) => setState(() {
            text = result.recognizedWords; // Update text with recognized speech
            if (result.hasConfidenceRating && result.confidence > 0) {
              confidence = result.confidence; // Update confidence rating
            }
          }),
        );
      }
    } else {
      // Stop listening if already listening
      setState(() => isListening = false);
      _speechToText.stop();
    }
  }
}
