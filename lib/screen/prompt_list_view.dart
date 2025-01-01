import 'package:ai_summarization/controller/prompt_list_control.dart';
import 'package:ai_summarization/screen/gallery_tool_view.dart';
import 'package:ai_summarization/screen/prompt_edit_view.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PromptListView extends StatefulWidget {
  @override
  _PromptListViewState createState() => _PromptListViewState();
}

class _PromptListViewState extends State<PromptListView>
    with SingleTickerProviderStateMixin {
  final PromptListControl _controller = PromptListControl();
  List<Map<String, dynamic>> _promptList = [];
  bool _isLoading = true;
  bool _selectionMode = false;
  Set<String> _selectedPromptIds = Set<String>();
  late AnimationController _animationController;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredPromptList = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fetchPromptHistory();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPromptHistory() async {
    List<Map<String, dynamic>> promptHistory = await _controller.fetchPrompts();
    setState(() {
      _promptList = promptHistory;
      _filteredPromptList = promptHistory;
      _isLoading = false;
    });
  }

  void _filterPrompts(String query) {
    setState(() {
      _filteredPromptList = _promptList.where((prompt) {
        return prompt['promptName']
            .toString()
            .toLowerCase()
            .contains(query.toLowerCase());
      }).toList();
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
        _animationController.reverse();
      }
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPromptIds.clear();
      _selectionMode = false;
      _animationController.reverse();
    });
  }

  Future<void> _deleteSelectedPrompts() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Prompts'),
        content: Text(
            'Are you sure you want to delete ${_selectedPromptIds.length} prompt(s)?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              for (String promptId in _selectedPromptIds) {
                await _controller.deletePrompt(promptId);
              }
              _clearSelection();
              await _fetchPromptHistory();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Prompts deleted successfully')),
                );
              }
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              )
            : null,
        title: _selectionMode
            ? Text('${_selectedPromptIds.length} selected')
            : const Text('My Prompts'),
        actions: _selectionMode
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedPrompts,
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate:
                          _PromptSearchDelegate(_promptList, (prompt) async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PromptEditView(
                              promptId: prompt['promptId'],
                            ),
                          ),
                        );
                        _fetchPromptHistory();
                      }),
                    );
                  },
                ),
              ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _promptList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.note_alt_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No prompts yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create your first prompt to get started',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPromptHistory,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _filteredPromptList.length,
                    itemBuilder: (context, index) {
                      Map<String, dynamic> prompt = _filteredPromptList[index];
                      bool isSelected =
                          _selectedPromptIds.contains(prompt['promptId']);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: Material(
                          borderRadius: BorderRadius.circular(12),
                          elevation: 1,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onLongPress: () {
                              setState(() {
                                _selectionMode = true;
                                _animationController.forward();
                                _addSelection(prompt['promptId']);
                              });
                            },
                            onTap: () async {
                              if (_selectionMode) {
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
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  if (_selectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (value) =>
                                            _addSelection(prompt['promptId']),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          prompt['promptName'] ??
                                              'Unnamed Prompt',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Updated ${DateFormat.yMMMd().add_jm().format(prompt['timestamp'].toDate())}',
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
                                  if (!_selectionMode)
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
      floatingActionButton: !_selectionMode
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GalleryView(),
                  ),
                );
                _fetchPromptHistory();
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _PromptSearchDelegate extends SearchDelegate {
  final List<Map<String, dynamic>> prompts;
  final Function(Map<String, dynamic>) onPromptSelected;

  _PromptSearchDelegate(this.prompts, this.onPromptSelected);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    final filteredPrompts = prompts.where((prompt) {
      return prompt['promptName']
          .toString()
          .toLowerCase()
          .contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filteredPrompts.length,
      itemBuilder: (context, index) {
        final prompt = filteredPrompts[index];
        return ListTile(
          title: Text(prompt['promptName'] ?? 'Unnamed Prompt'),
          subtitle: Text(
            DateFormat.yMMMd().add_jm().format(prompt['timestamp'].toDate()),
          ),
          onTap: () {
            close(context, null);
            onPromptSelected(prompt);
          },
        );
      },
    );
  }
}
