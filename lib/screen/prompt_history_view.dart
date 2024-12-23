import 'package:flutter/material.dart';
import 'package:ai_summarization/model/prompt_model.dart';
import 'package:ai_summarization/screen/prompt_history_detail_view.dart';

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
    _retrievePromptHistory();
  }

  Future<void> _retrievePromptHistory() async {
    List<Map<String, dynamic>> history =
        await _promptModel.fetchPromptHistory(widget.promptId);
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
              ? const Center(child: Text('No history available'))
              : ListView.builder(
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> historyItem = _history[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(
                          index == 0
                              ? 'Current'
                              : 'Updated: ${historyItem['timestamp']?.toDate() ?? 'Unknown'}',
                        ),
                        onTap: () {
                          Navigator.push(
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
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
