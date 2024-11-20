import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Clipboard functionality
import 'package:flutter_tts/flutter_tts.dart'; // For Text-to-Speech functionality
import '../service/translation_service.dart'; // Import the translation service

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  _TranslateScreenState createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _controller = TextEditingController();
  final TranslationService _translationService = TranslationService();
  final FlutterTts _flutterTts = FlutterTts(); // Initialize Text-to-Speech

  String _translatedText = 'Your translated text will appear here';

  // Language codes and full names mapping
  final Map<String, String> languageMap = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'zh': 'Chinese',
    'ar': 'Arabic',
    'ms': 'Malay',
    'ko': 'Korean',
    'ja': 'Japanese',
  };

  // Reverse map for selecting the language codes for translation
  final Map<String, String> reverseLanguageMap = {
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
    'Japanese': 'ja',
  };

  String _inputLanguage = 'en'; // Default input language code
  String _outputLanguage = 'zh'; // Default output language code

  // Method to handle translation
  void _translateText() async {
    if (_controller.text.isNotEmpty) {
      try {
        final translated = await _translationService.translateText(
            _controller.text, _outputLanguage);
        setState(() {
          _translatedText = translated;
        });
      } catch (e) {
        print('Translation error: $e');
        setState(() {
          _translatedText = 'Translation failed';
        });
      }
    }
  }

  // Method to copy text to clipboard
  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to Clipboard')),
    );
  }

  // Method to pronounce text
  void _pronounceText(String text) async {
    if (text.isNotEmpty) {
      // Check if the TTS engine is properly initialized
      bool isAvailable = await _flutterTts.isLanguageAvailable(_outputLanguage);
      if (isAvailable) {
        await _flutterTts.setLanguage(_outputLanguage); // Set to the selected output language
        await _flutterTts.speak(text);
      } else {
        // Fallback to English if the selected language is not available
        await _flutterTts.setLanguage('en');
        await _flutterTts.speak(text);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_translateText); // Auto translate on text change
  }

  @override
  void dispose() {
    _controller.removeListener(_translateText);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Translator'),
        backgroundColor: Colors.blueAccent,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // Row with Input and Output Language Dropdowns
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Input Language Dropdown
                Expanded(
                  child: DropdownButton<String>(
                    value: languageMap[_inputLanguage],
                    items: languageMap.values.map((String language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: (String? newLang) {
                      setState(() {
                        _inputLanguage = reverseLanguageMap[newLang!]!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                // Output Language Dropdown
                Expanded(
                  child: DropdownButton<String>(
                    value: languageMap[_outputLanguage],
                    items: languageMap.values.map((String language) {
                      return DropdownMenuItem<String>(
                        value: language,
                        child: Text(language),
                      );
                    }).toList(),
                    onChanged: (String? newLang) {
                      setState(() {
                        _outputLanguage = reverseLanguageMap[newLang!]!;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Input Text Field with flexible height and copy button
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Enter text to translate',
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () => _copyToClipboard(_controller.text),
                  ),
                ),
                maxLines: null, // Allow flexible height
                keyboardType: TextInputType.text,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 20),

            // Pronounce Input Text Button
            if (_controller.text.isNotEmpty) 
              IconButton(
                icon: const Icon(Icons.volume_up),
                onPressed: () => _pronounceText(_controller.text),
              ),

            const SizedBox(height: 20),

            // Conditionally render the translated text (Output box) only when there's input
            if (_controller.text.isNotEmpty) ...[
              const Text(
                'Translated Text:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _translatedText,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      onPressed: () => _copyToClipboard(_translatedText),
                    ),
                    // Pronounce Translated Text Button
                    IconButton(
                      icon: const Icon(Icons.volume_up),
                      onPressed: () => _pronounceText(_translatedText),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
