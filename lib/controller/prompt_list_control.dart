import 'package:ai_summarization/model/prompt_model.dart';

class PromptListControl {
  PromptModel _model = PromptModel();
  Future<List<Map<String, dynamic>>> fetchPrompts() async {
    return await _model.fetchPrompts();
  }
}
