import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';

class PromptHistoryDetailView extends StatelessWidget {
  final Map<String, dynamic> historyItem;
  final Map<String, dynamic>? previousItem;

  const PromptHistoryDetailView({
    super.key,
    required this.historyItem,
    this.previousItem,
  });

  List<TextSpan> _buildDiffText(String oldText, String newText) {
    final dmp = DiffMatchPatch();
    final diffs = dmp.diff(oldText, newText);
    dmp.diffCleanupSemantic(diffs);

    return diffs.map((diff) {
      switch (diff.operation) {
        case DIFF_INSERT:
          return TextSpan(
            text: diff.text,
            style: const TextStyle(
              backgroundColor: Colors.green,
              color: Colors.white,
            ),
          );
        case DIFF_DELETE:
          return TextSpan(
            text: diff.text,
            style: const TextStyle(
              backgroundColor: Colors.red,
              color: Colors.white,
              decoration: TextDecoration.lineThrough,
            ),
          );
        default:
          return TextSpan(text: diff.text);
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final texts = historyItem['updatedTexts'] as List<dynamic>;
    final previousTexts = previousItem?['updatedTexts'] as List<dynamic>? ??
        List.filled(texts.length, '');

    return Scaffold(
      appBar: AppBar(
        title: Text(
            'History Detail - ${historyItem['timestamp']?.toDate().toString() ?? 'Unknown'}'),
      ),
      body: ListView.builder(
        itemCount: texts.length,
        itemBuilder: (context, index) {
          final oldText = previousTexts[index] as String? ?? '';
          final newText = texts[index] as String;

          return Card(
            margin: const EdgeInsets.all(8.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page ${index + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),
                      children: oldText.isEmpty
                          ? [
                              TextSpan(
                                text: newText,
                                style: const TextStyle(
                                  backgroundColor: Colors.green,
                                  color: Colors.white,
                                ),
                              )
                            ]
                          : _buildDiffText(oldText, newText),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
