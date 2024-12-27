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
  bool _selectionMode = false;
  Set<String> _selectedPromptIds = Set<String>();

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

  void _addSelection(String promptId) {
    setState(() {
      if (_selectedPromptIds.contains(promptId)) {
        _selectedPromptIds.remove(promptId);
      } else {
        _selectedPromptIds.add(promptId);
      }
      if (_selectedPromptIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPromptIds.clear();
      _selectionMode = false;
    });
  }

  void _deleteSelectedPrompts() {
    _selectedPromptIds.forEach((promptId) async {
      await _controller.deletePrompt(promptId);
    });
    _clearSelection();
    _fetchPromptHistory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prompt List'),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSelection,
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedPrompts,
                ),
              ]
            : [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _promptList.isEmpty
              ? const Center(child: Text('No prompts available'))
              : ListView.builder(
                  itemCount: _promptList.length,
                  itemBuilder: (context, index) {
                    Map<String, dynamic> prompt = _promptList[index];
                    bool isSelected =
                        _selectedPromptIds.contains(prompt['promptId']);
                    return GestureDetector(
                        onLongPress: () {
                          setState(() {
                            _selectionMode = true;
                            _addSelection(prompt['promptId']);
                          });
                        },
                        onTap: () async {
                          if (_selectedPromptIds.isNotEmpty) {
                            _addSelection(prompt['promptId']);
                          } else {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PromptEditView(
                                  promptId: prompt['promptId'],
                                ),
                              ),
                            );
                            _fetchPromptHistory();
                          }
                        },
                        child: Card(
                          margin: const EdgeInsets.all(8.0),
                          child: ListTile(
                            leading: _selectionMode
                                ? Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      _addSelection(prompt['promptId']);
                                    },
                                  )
                                : null,
                            title:
                                Text(prompt['promptName'] ?? 'Unnamed Prompt'),
                            subtitle: Text(
                                'Updated: ${prompt['timestamp'].toDate()}'),
                          ),
                        ));
                  },
                ),
    );
  }
}
