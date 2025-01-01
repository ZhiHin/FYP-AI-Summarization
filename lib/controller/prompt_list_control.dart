import 'package:ai_summarization/model/prompt_model.dart';

class PromptListControl {
  PromptModel _model = PromptModel();
  Future<List<Map<String, dynamic>>> fetchPrompts() async {
    return await _model.fetchPrompts();
  }

  Future<void> deletePrompt(String promptId) async {
    await _model.deletePrompt(promptId);
  }

  Future<void> appendPrompt(
      String promptId, List<String> promptTexts, List<String> imageUrls) async {
    await _model.appendPagesToPrompt(promptId, promptTexts, imageUrls);
  }
}
