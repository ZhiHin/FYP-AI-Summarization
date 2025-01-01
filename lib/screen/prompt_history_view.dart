import 'package:flutter/material.dart';
import 'package:ai_summarization/model/prompt_model.dart';
import 'package:ai_summarization/screen/prompt_history_detail_view.dart';
import 'package:intl/intl.dart';

class PromptHistoryView extends StatefulWidget {
  final String promptId;

  const PromptHistoryView({super.key, required this.promptId});

  @override
  _PromptHistoryViewState createState() => _PromptHistoryViewState();
}

class _PromptHistoryViewState extends State<PromptHistoryView> {
  final PromptModel _promptModel = PromptModel();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (mounted) {
      _retrievePromptHistory();
    }
  }

  Future<void> _retrievePromptHistory() async {
    List<Map<String, dynamic>> history =
        await _promptModel.fetchPromptHistory(widget.promptId);
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return DateFormat.yMMMd().add_jm().format(dateTime);
    } else if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Version History'),
            Text(
              '${_history.length} versions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[200],
                    fontSize: 14,
                  ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No History Available',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Changes will appear here when you make edits',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _retrievePromptHistory,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _history.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> historyItem = _history[index];
                      DateTime timestamp =
                          historyItem['timestamp']?.toDate() ?? DateTime.now();
                      bool isCurrent = index == 0;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final updatedTexts = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PromptHistoryDetailView(
                                    historyItem: historyItem,
                                    previousItem: index < _history.length - 1
                                        ? _history[index + 1]
                                        : null,
                                  ),
                                ),
                              );
                              if (updatedTexts != null) {
                                Navigator.pop(context, updatedTexts);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isCurrent
                                          ? Theme.of(context)
                                              .primaryColor
                                              .withOpacity(0.1)
                                          : Colors.grey[100],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Icon(
                                      isCurrent ? Icons.edit : Icons.history,
                                      color: isCurrent
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isCurrent
                                              ? 'Current Version'
                                              : 'Previous Version',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: isCurrent
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _getTimeAgo(timestamp),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: Colors.grey[600],
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey[400],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
