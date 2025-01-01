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
              backgroundColor: Color(0xFF4CAF50),
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          );
        case DIFF_DELETE:
          return TextSpan(
            text: diff.text,
            style: const TextStyle(
              backgroundColor: Color(0xFFEF5350),
              color: Colors.white,
              decoration: TextDecoration.lineThrough,
              decorationColor: Colors.white70,
              decorationThickness: 2,
            ),
          );
        default:
          return TextSpan(
            text: diff.text,
            style: const TextStyle(
              color: Color(0xFF2C3E50),
              height: 1.5,
            ),
          );
      }
    }).toList();
  }

  Future<void> _showRestoreDialog(
      BuildContext context, Map<String, dynamic> historyItem) async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.restore, color: Theme.of(context).primaryColor),
              const SizedBox(width: 12),
              const Text('Restore Version'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to restore this version?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                'Version from: ${DateFormat.yMMMd().add_jm().format(historyItem['timestamp'].toDate())}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                final String promptId = historyItem['promptId'] as String;
                final List<String> updatedTexts =
                    List<String>.from(historyItem['updatedTexts']);
                final Timestamp timestamp =
                    historyItem['timestamp'] as Timestamp;
                _controller.restorePrompt(promptId, updatedTexts, timestamp);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 12),
                        Text('Version restored successfully'),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    backgroundColor: Color(0xFF4CAF50),
                  ),
                );

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
    final timestamp = historyItem['timestamp']?.toDate() ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Version Details',
              style: TextStyle(fontSize: 18),
            ),
            Text(
              DateFormat.yMMMd().add_jm().format(timestamp),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[200],
                    fontSize: 14,
                  ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: FilledButton.icon(
              onPressed: () => _showRestoreDialog(context, historyItem),
              icon: const Icon(Icons.restore),
              label: const Text('Restore'),
            ),
          ),
        ],
      ),
      body: Container(
        color: Colors.grey[100],
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: texts.length,
          itemBuilder: (context, index) {
            final oldText = previousTexts[index] as String? ?? '';
            final newText = texts[index] as String;

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Page ${index + 1}',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (oldText.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'New Content',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.6,
                        ),
                        children: oldText.isEmpty
                            ? [
                                TextSpan(
                                  text: newText,
                                  style: const TextStyle(
                                    backgroundColor: Color(0xFF4CAF50),
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              ]
                            : _buildDiffText(oldText, newText),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
