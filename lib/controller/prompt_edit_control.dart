import 'package:ai_summarization/model/prompt_model.dart';

class PromptEditControl {
  PromptModel _model = PromptModel();
  Future<void> updatePrompt(String docId, List<String> promptTexts) async {
    await _model.updatePromptInFirebase(docId, promptTexts);
  }

  Future<Map<String, dynamic>> fetchText(String promptId) async {
    return await _model.fetchText(promptId);
  }

  Future<void> renamePrompt(String promptId, String promptName) async {
    await _model.renamePrompt(promptId, promptName);
  }
}
