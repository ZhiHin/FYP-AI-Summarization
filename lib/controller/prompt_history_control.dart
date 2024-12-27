import 'package:ai_summarization/model/prompt_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromptHistoryControl {
  final PromptModel _model = PromptModel();
  Future<void> restorePrompt(
      String promptId, List<String> promptTexts, Timestamp date) async {
    await _model.restorePrompt(promptId, promptTexts, date);
  }
}
