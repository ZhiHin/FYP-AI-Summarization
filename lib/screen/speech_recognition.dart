import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:avatar_glow/avatar_glow.dart';

import '../service/translation_service.dart';

class SpeechRecognitionScreen extends StatefulWidget {
  const SpeechRecognitionScreen({super.key});

  @override
  _SpeechRecognitionScreenState createState() =>
      _SpeechRecognitionScreenState();
}

class _SpeechRecognitionScreenState extends State<SpeechRecognitionScreen> {
  bool isListening = false;
  late stt.SpeechToText _speechToText;
  String text = "Press the button to start recording";
  String currentText = "";
  double confidence = 1.0;
  bool isInitialized = false;
  bool hasMicPermission = false;
  List<stt.LocaleName> _localeNames = [];
  String _currentLocaleId = '';
  final bool _isEarphoneConnected = false;

  bool _useBuiltInMic = true;
  double _inputGain = 1.0;
  bool _noiseReduction = true;
  bool _hasError = false;
  bool _isFirstRecognition = true;

  final TranslationService _translationService = TranslationService();
  String? _selectedTargetLanguage;
  bool _isTranslating = false;
  String? _translatedText;

  // Add language map
  final Map<String, String> _supportedLanguages = {
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Italian': 'it',
    'Portuguese': 'pt',
    'Chinese': 'zh',
    'Arabic': 'ar',
    'Malay': 'ms',
    'Korean': 'ko',
    'Japanese': 'ja'
  };

  // Add TTS controller
  final FlutterTts flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _speechToText = stt.SpeechToText();
    _checkPermissions();
    if (hasMicPermission) {
      _checkAudioDevices();
    }
  }

  // Add TTS method
  Future<void> _speakTranslatedText() async {
    if (_translatedText == null) return;

    if (_isSpeaking) {
      await flutterTts.stop();
      setState(() => _isSpeaking = false);
      return;
    }

    try {
      setState(() => _isSpeaking = true);
      await flutterTts.setLanguage(_selectedTargetLanguage ?? 'en-US');
      await flutterTts.speak(_translatedText!);

      flutterTts.setCompletionHandler(() {
        setState(() => _isSpeaking = false);
      });
    } catch (e) {
      setState(() => _isSpeaking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error speaking text: $e')),
      );
    }
  }

  // Add translation method
  Future<void> _translateText() async {
    if (text.isEmpty ||
        text == "Press the button to start recording" ||
        _selectedTargetLanguage == null) {
      return;
    }

    setState(() => _isTranslating = true);

    try {
      final translated = await _translationService.translateText(
        text,
        _selectedTargetLanguage!,
      );

      setState(() {
        _translatedText = translated;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Translation failed: $e')),
      );
    } finally {
      setState(() => _isTranslating = false);
    }
  }

  Future<void> _checkAudioDevices() async {
    try {
      if (!isInitialized) {
        await _initializeSpeech();
      }

      if (_hasError) {
        _handleError('Speech recognition initialization failed');
      }
    } catch (e) {
      print('Error checking audio devices: $e');
      if (!isInitialized) {
        _hasError = true;
        _handleError(e);
      }
    }
  }

  Future<void> _checkPermissions() async {
    final status = await Permission.microphone.status;
    setState(() => hasMicPermission = status.isGranted);
    if (status.isGranted) {
      await _initializeSpeech();
    } else {
      await _requestPermissions();
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    setState(() => hasMicPermission = status.isGranted);
    if (status.isGranted) {
      await _initializeSpeech();
    }
  }

  Future<void> _initializeSpeech() async {
    try {
      isInitialized = await _speechToText.initialize(
        onStatus: (status) {
          print('Speech recognition status: $status');
          if (status == 'done' && isListening) {
            _startListening();
          }
        },
        onError: (error) {
          _hasError = true;
          _handleError(error);
        },
        debugLogging: true,
      );

      if (isInitialized) {
        _hasError = false;
        final locales = await _speechToText.locales();

        setState(() {
          _localeNames = locales;
          _currentLocaleId = locales
              .firstWhere(
                (locale) => locale.localeId.startsWith('en_'),
                orElse: () => locales.first,
              )
              .localeId;
        });

        print('Initialized with locale: $_currentLocaleId');
      }
    } catch (e) {
      print('Error initializing speech recognition: $e');
      _hasError = true;
      _handleError(e);
    }
  }

  void _handleError(dynamic error) {
    if (!mounted) return;

    print('Speech recognition error: $error');
    setState(() {
      isListening = false;
    });

    if (_hasError) {
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Error'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                error is String ? error : 'Unable to process speech input.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                'Troubleshooting Steps:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _buildTroubleshootingStep(
                icon: Icons.mic,
                text: 'Check microphone connection',
              ),
              _buildTroubleshootingStep(
                icon: Icons.headphones,
                text: 'Try switching audio input device',
              ),
              _buildTroubleshootingStep(
                icon: Icons.settings_suggest,
                text: 'Adjust input sensitivity',
              ),
              _buildTroubleshootingStep(
                icon: Icons.refresh,
                text: 'Restart the application',
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.settings),
              label: const Text('Audio Settings'),
              onPressed: () {
                Navigator.pop(context);
                _showAudioSettings();
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              onPressed: () {
                Navigator.pop(context);
                _hasError = false;
                _initializeSpeech();
              },
            ),
          ],
        ),
      );
    }
  }

  void _showAudioSettings() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Audio Settings'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Use Built-in Microphone'),
                subtitle: Text(_useBuiltInMic
                    ? 'Using device microphone'
                    : 'Using external microphone/earphones'),
                value: _useBuiltInMic,
                onChanged: (value) {
                  setState(() => _useBuiltInMic = value);
                },
              ),
              ListTile(
                title: const Text('Input Sensitivity'),
                subtitle: Slider(
                  value: _inputGain,
                  min: 0.0,
                  max: 2.0,
                  divisions: 20,
                  label: '${(_inputGain * 100).round()}%',
                  onChanged: (value) {
                    setState(() => _inputGain = value);
                  },
                ),
              ),
              SwitchListTile(
                title: const Text('Noise Reduction'),
                subtitle: const Text('Reduce background noise'),
                value: _noiseReduction,
                onChanged: (value) {
                  setState(() => _noiseReduction = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _applyAudioSettings();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyAudioSettings() async {
    print('Applied audio settings:');
    print('Use built-in mic: $_useBuiltInMic');
    print('Input gain: $_inputGain');
    print('Noise reduction: $_noiseReduction');

    await _initializeSpeech();
  }

  Widget _buildTroubleshootingStep({
    required IconData icon,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startListening() async {
    if (!isInitialized) {
      print('Speech recognition not initialized');
      return;
    }

    try {
      final listenOptions = stt.SpeechListenOptions(
        partialResults: true,
        listenMode: stt.ListenMode.dictation,
        cancelOnError: true,
        onDevice: false,
      );

      await _speechToText.listen(
        onResult: (result) => setState(() {
          // Always show the current recognized words immediately
          if (result.recognizedWords.isNotEmpty) {
            if (_isFirstRecognition) {
              // First recognition - just show the text
              text = result.recognizedWords;
              _isFirstRecognition = false;
            } else {
              // For subsequent recognitions
              if (result.finalResult) {
                // When we get a final result, append it to the existing text
                if (text.endsWith('.') ||
                    text.endsWith('!') ||
                    text.endsWith('?')) {
                  text = '$text ${result.recognizedWords}';
                } else if (text.isNotEmpty &&
                    text != "Press the button to start recording") {
                  text = '$text. ${result.recognizedWords}';
                } else {
                  text = result.recognizedWords;
                }
              } else {
                // For partial results, show them in real-time
                // If we have existing text, append the partial result
                if (text.isNotEmpty &&
                    text != "Press the button to start recording") {
                  text = '$text ${result.recognizedWords}';
                } else {
                  text = result.recognizedWords;
                }
              }
            }
          }

          if (result.hasConfidenceRating && result.confidence > 0) {
            confidence = result.confidence;
          }
        }),
        localeId: _currentLocaleId,
        listenOptions: listenOptions,
      );
      print('Started listening');
    } catch (e) {
      print('Error starting listening: $e');
      _handleError(e);
    }
  }

  void _showDebugInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Initialized: $isInitialized'),
              Text('Has Permission: $hasMicPermission'),
              Text('Current Locale: $_currentLocaleId'),
              Text('Available Locales: ${_localeNames.length}'),
              Text('Earphones Connected: $_isEarphoneConnected'),
              Text('Using Built-in Mic: $_useBuiltInMic'),
              Text('Input Gain: $_inputGain'),
              Text('Noise Reduction: $_noiseReduction'),
              const Divider(),
              const Text('Troubleshooting Tips:'),
              const Text('1. Enable microphone in device settings'),
              const Text('2. Try switching between earphones and built-in mic'),
              const Text('3. Adjust input sensitivity in audio settings'),
              const Text('4. Check system audio input settings'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () => _showAudioSettings(),
            child: const Text('Audio Settings'),
          ),
        ],
      ),
    );
  }

  void _toggleListening() async {
    if (!hasMicPermission) {
      await _requestPermissions();
      return;
    }

    if (!isListening) {
      setState(() {
        isListening = true;
        // Don't reset the text when starting a new listening session
      });
      await _startListening();
    } else {
      setState(() => isListening = false);
      await _speechToText.stop();
      print('Stopped listening');
    }
  }

  Widget _buildClearButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        padding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 10,
        ),
      ),
      onPressed: () {
        setState(() {
          text = "Press the button to start recording";
          _isFirstRecognition = true;
        });
      },
      icon: const Icon(Icons.clear, color: Colors.white),
      label: const Text(
        "Clear Text",
        style: TextStyle(
          fontSize: 18,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue.shade50, Colors.white],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildCustomAppBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (!hasMicPermission) _buildPermissionWarning(),
                          _buildSpeechInputCard(),
                          const SizedBox(height: 24),
                          _buildTranslationSection(),
                          if (_translatedText != null) ...[
                            const SizedBox(height: 24),
                            _buildTranslatedOutput(),
                          ],
                          const SizedBox(height: 24),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: _buildMicButton(),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildCustomAppBar() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                "${(confidence * 100).toStringAsFixed(1)}%",
                style: TextStyle(
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: _showAudioSettings,
              color: Colors.grey.shade700,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: _showDebugInfo,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildPermissionWarning() {
  return Container(
    margin: const EdgeInsets.only(bottom: 20),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.orange.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.orange.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.mic_off, color: Colors.orange.shade700),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Microphone permission is required.\nTap the button to enable.',
            style: TextStyle(
              color: Colors.orange.shade900,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSpeechInputCard() {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Speech Input',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (text.isNotEmpty && text != "Press the button to start recording")
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Text copied to clipboard"),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  color: Colors.blue,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTranslationSection() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Translation',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedTargetLanguage,
              hint: const Text('Select target language'),
              underline: const SizedBox(),
              items: _supportedLanguages.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.value,
                  child: Text(entry.key),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedTargetLanguage = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isTranslating ? null : _translateText,
              child: _isTranslating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Translate'),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTranslatedOutput() {
  return Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Translation Output',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blue),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _translatedText ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Translation copied to clipboard"),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isSpeaking ? Icons.stop_circle : Icons.volume_up,
                      color: Colors.blue,
                    ),
                    onPressed: _speakTranslatedText,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _translatedText!,
              style: const TextStyle(fontSize: 16, height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildActionButtons() {
  return Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () {
          setState(() {
            text = "Press the button to start recording";
            _isFirstRecognition = true;
            _translatedText = null;
          });
        },
        icon: const Icon(Icons.delete_outline),
        label: const Text("Clear All"),
      ),
    ],
  );
}

Widget _buildMicButton() {
  return SizedBox(
    width: 80,
    height: 80,
    child: AvatarGlow(
      animate: isListening,
      glowColor: Theme.of(context).primaryColor,
      duration: const Duration(milliseconds: 2000),
      repeat: true,
      child: MaterialButton(
        onPressed: _toggleListening,
        elevation: 8.0,
        shape: const CircleBorder(),
        child: CircleAvatar(
          backgroundColor: !hasMicPermission
              ? Colors.grey
              : (isListening ? Colors.red : Colors.blue),
          radius: 30.0,
          child: Icon(
            !hasMicPermission
                ? Icons.mic_off
                : (isListening ? Icons.stop : Icons.mic),
            size: 28,
            color: Colors.white,
          ),
        ),
      ),
    ),
  );
}
}
