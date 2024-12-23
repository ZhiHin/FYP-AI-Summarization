import 'package:ai_summarization/controller/prompt_list_control.dart';
import 'package:ai_summarization/screen/prompt_edit_view.dart';
import 'package:flutter/material.dart';

class PromptListView extends StatefulWidget {
  @override
  _PromptListViewState createState() => _PromptListViewState();
}

class _PromptListViewState extends State<PromptListView> {
  final PromptListControl _controller = PromptListControl();
  List<Map<String, dynamic>> _promptList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPromptHistory();
  }

  Future<void> _fetchPromptHistory() async {
    List<Map<String, dynamic>> promptHistory = await _controller.fetchPrompts();
    setState(() {
      _promptList = promptHistory;
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
          : _promptList.isEmpty
              ? const Center(child: Text('No prompts available'))
              : ListView.builder(
                  itemCount: _promptList.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> prompt = _promptList[index];
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text(prompt['promptName'] ?? 'Unnamed Prompt'),
                        subtitle:
                            Text('Updated: ${prompt['timestamp'].toDate()}'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PromptEditView(
                                promptId: prompt['promptId'],
                                promptName: prompt['promptName'],
                                imageUrls:
                                    List<String>.from(prompt['imageUrls']),
                                texts: List<String>.from(prompt['promptTexts']),
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
