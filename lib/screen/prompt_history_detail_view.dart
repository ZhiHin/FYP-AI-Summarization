import 'package:ai_summarization/controller/prompt_history_control.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:diff_match_patch/diff_match_patch.dart';
import 'package:intl/intl.dart';

class PromptHistoryDetailView extends StatelessWidget {
  final Map<String, dynamic> historyItem;
  final Map<String, dynamic>? previousItem;

  PromptHistoryDetailView({
    super.key,
    required this.historyItem,
    this.previousItem,
  });
  final _controller = PromptHistoryControl();
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

  void _showRestoreDialog(
      BuildContext context, Map<String, dynamic> historyItem) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restore Version'),
          content: const Text('Do you want to restore this version?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                print(historyItem);
                final String promptId = historyItem['promptId'] as String;
                final List<String> updatedTexts =
                    List<String>.from(historyItem['updatedTexts']);
                final Timestamp timestamp =
                    historyItem['timestamp'] as Timestamp;
                _controller.restorePrompt(promptId, updatedTexts, timestamp);
                showSnackBar(context, "Prompt restored successfully");
                Navigator.pop(context, updatedTexts);
              },
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            onPressed: () {
              _showRestoreDialog(context, historyItem);
            },
          )
        ],
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
