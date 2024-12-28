import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_summarization/model/prompt_model.dart';
import 'package:http/http.dart' as http;

PromptModel _model = PromptModel();

class SummarizeOcrControl {
  Future<String> generateSummary(
      String text, String selectedSummarizationTechnique) async {
    final response = await http
        .post(
          Uri.parse('http://192.168.0.171:8000/summarize'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'text': text,
            'summary_type': selectedSummarizationTechnique,
            'max_length': 150,
          }),
        )
        .timeout(
          const Duration(minutes: 5),
          onTimeout: () => throw TimeoutException('Summarization timeout'),
        );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['summary'];
    } else {
      throw Exception('Failed to generate text');
    }
  }

  Future<void> saveSummary(List<String> imageUrls, List<String> promptTexts,
      String promptName, String type) async {
    _model.savePromptToFirebase(imageUrls, promptTexts, promptName, type);
  }
}
