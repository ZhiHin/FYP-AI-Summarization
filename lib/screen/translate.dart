import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../service/translation_service.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});

  @override
  _TranslateScreenState createState() => _TranslateScreenState();
}

class _TranslateScreenState extends State<TranslateScreen> {
  final TextEditingController _controller = TextEditingController();
  final TranslationService _translationService = TranslationService();
  final FlutterTts _flutterTts = FlutterTts();

  String _translatedText = 'Your translated text will appear here';
  bool _isTranslatingDoc = false;
  DateTime? _translationStartTime;
  int _totalCharacters = 0;
  double _translationProgress = 0.0;

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
        await _flutterTts.setLanguage(
            _outputLanguage); // Set to the selected output language
        await _flutterTts.speak(text);
      } else {
        // Fallback to English if the selected language is not available
        await _flutterTts.setLanguage('en');
        await _flutterTts.speak(text);
      }
    }
  }

  Future<void> _translateDocument() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String? selectedLanguage;
    DocumentSnapshot? selectedDoc;

    try {
      setState(() {
        _isTranslatingDoc = true;
        _translationStartTime = DateTime.now();
        _translationProgress = 0.0;
      });

      // Show progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Translation Progress'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(
                  value: _translationProgress,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
                const SizedBox(height: 16),
                Text(
                  'Progress: ${(_translationProgress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (_translationStartTime != null)
                  Text(
                      'Time elapsed: ${DateTime.now().difference(_translationStartTime!).inSeconds}s'),
                Text('Characters processed: $_totalCharacters'),
              ],
            ),
          ),
        ),
      );

      // Step 1: Select Document
      final documents = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .where('documentType', isEqualTo: 'pdf')
          .get();

      selectedDoc = await showDialog<DocumentSnapshot>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Document'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: documents.docs.length,
              itemBuilder: (context, index) {
                final doc = documents.docs[index];
                return ListTile(
                  leading: const Icon(Icons.picture_as_pdf),
                  title: Text(doc['name']),
                  subtitle: Text(
                      'Uploaded: ${doc['uploadedAt']?.toDate().toString() ?? 'N/A'}'),
                  onTap: () => Navigator.pop(context, doc),
                );
              },
            ),
          ),
        ),
      );

      // Update progress after document selection
      setState(() => _translationProgress = 0.2);

      if (selectedDoc == null) return;

      // Step 2: Select Target Language
      selectedLanguage = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Target Language'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: languageMap.length,
              itemBuilder: (context, index) {
                String langCode = languageMap.keys.elementAt(index);
                String langName = languageMap[langCode]!;
                return ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(langName),
                  onTap: () => Navigator.pop(context, langCode),
                );
              },
            ),
          ),
        ),
      );

      if (selectedLanguage == null) return;
      setState(() => _translationProgress = 0.4);

      // Step 3: Confirm Translation
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Translation'),
          content: Text(
              'Translate "${selectedDoc?['name']}" to ${languageMap[selectedLanguage]}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Translate'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      // Step 4: Perform Translation
      final translatedText = await _translationService.translateDocument(
        selectedDoc['fileUrl'],
        selectedLanguage,
        onProgress: (progress, characters) {
          setState(() {
            _translationProgress = progress;
            _totalCharacters = characters;
          });

          // Force dialog to update
          if (context.mounted) {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) => StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: const Text('Translation Progress'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LinearProgressIndicator(
                        value: _translationProgress,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Progress: ${(_translationProgress * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_translationStartTime != null)
                        Text(
                            'Time elapsed: ${DateTime.now().difference(_translationStartTime!).inSeconds}s'),
                      Text('Characters processed: $_totalCharacters'),
                    ],
                  ),
                ),
              ),
            );
          }
        },
      );

      setState(() => _translationProgress = 0.9);

      final downloadUrl = await _translationService.saveTranslatedDocument(
        translatedText,
        selectedDoc['name'],
        user.uid,
      );

      final sourceDoc = selectedDoc.data() as Map<String, dynamic>;
      final translatedContent = translatedText.codeUnits.length;

      // Step 5: Save Translation
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('documents')
          .add({
        'name': 'translated_${selectedDoc['name']}',
        'fileUrl': downloadUrl,
        'documentType': 'pdf',
        'translatedFrom': selectedDoc['name'],
        'targetLanguage': selectedLanguage,
        'uploadedAt': FieldValue.serverTimestamp(),
        'folderId': null,
        'pageCount': sourceDoc['pageCount'] ?? 0, // Copy source page count
        'size': translatedContent, // Size in bytes of translated content
      });

      setState(() => _translationProgress = 1.0);
      Navigator.pop(context); // Close progress dialog

      // Show completion stats
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Translation completed in ${DateTime.now().difference(_translationStartTime!).inSeconds}s\n'
            'Characters processed: $_totalCharacters'),
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Document translated to ${languageMap[selectedLanguage]}'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isTranslatingDoc = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Translator'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Document Translation Card
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Document Translation',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed:
                              _isTranslatingDoc ? null : _translateDocument,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _isTranslatingDoc
                                ? 'Translating...'
                                : 'Upload & Translate Document',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Language Selection Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'From',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    value: languageMap[_inputLanguage],
                                    isExpanded: true,
                                    underline: Container(
                                      height: 1,
                                      color: Colors.grey[300],
                                    ),
                                    items: languageMap.values
                                        .map((String language) {
                                      return DropdownMenuItem<String>(
                                        value: language,
                                        child: Text(language),
                                      );
                                    }).toList(),
                                    onChanged: (String? newLang) {
                                      setState(() {
                                        _inputLanguage =
                                            reverseLanguageMap[newLang!]!;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Icon(Icons.swap_horiz,
                                  color: Colors.grey[600]),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'To',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  DropdownButton<String>(
                                    value: languageMap[_outputLanguage],
                                    isExpanded: true,
                                    underline: Container(
                                      height: 1,
                                      color: Colors.grey[300],
                                    ),
                                    items: languageMap.values
                                        .map((String language) {
                                      return DropdownMenuItem<String>(
                                        value: language,
                                        child: Text(language),
                                      );
                                    }).toList(),
                                    onChanged: (String? newLang) {
                                      setState(() {
                                        _outputLanguage =
                                            reverseLanguageMap[newLang!]!;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Translation Area
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Input Card
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: _controller,
                            decoration: InputDecoration(
                              hintText: 'Enter text to translate',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              fillColor: Colors.white,
                              filled: true,
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            maxLines: 5,
                            style: const TextStyle(fontSize: 16),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.volume_up),
                                  onPressed: () =>
                                      _pronounceText(_controller.text),
                                  tooltip: 'Listen',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () =>
                                      _copyToClipboard(_controller.text),
                                  tooltip: 'Copy',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Output Card
                    if (_controller.text.isNotEmpty)
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                _translatedText,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.volume_up),
                                    onPressed: () =>
                                        _pronounceText(_translatedText),
                                    tooltip: 'Listen',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () =>
                                        _copyToClipboard(_translatedText),
                                    tooltip: 'Copy',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
