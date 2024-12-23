import 'package:ai_summarization/model/prompt_model.dart';

class PromptEditControl {
  PromptModel _model = PromptModel();
  Future<void> updatePrompt(String docId, List<String> promptTexts) async {
    await _model.updatePromptInFirebase(docId, promptTexts);
  }
}
