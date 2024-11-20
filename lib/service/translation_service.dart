import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  final String apiKey = 'AIzaSyBhfIFnrXINh1sm30nDnFwv0SCrGa4y5zI';

  Future<String> translateText(String text, String targetLanguage) async {
    final url = Uri.https(
      'translation.googleapis.com',
      '/language/translate/v2',
      {
        'q': text,
        'target': targetLanguage,
        'key': apiKey,
      },
    );

    final response = await http.post(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final translatedText = data['data']['translations'][0]['translatedText'];
      return translatedText;
    } else {
      throw Exception('Failed to translate text');
    }
  }
}
