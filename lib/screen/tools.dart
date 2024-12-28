import 'package:ai_summarization/screen/gallery_tool_view.dart';
import 'package:ai_summarization/screen/prompt_list_view.dart';
import 'package:flutter/material.dart';
import 'audioProcess.dart';
import 'document_converter_page.dart';
import 'document_summarize.dart';
import 'speech_recognition.dart';
import 'translate.dart';

class ToolsPage extends StatelessWidget {
  const ToolsPage({super.key});

  Widget _buildToolCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String description,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> tools = [
      {
        'title': 'Document Converter',
        'icon': Icons.description,
        'color': Colors.blue,
        'page': DocumentConverterPage(),
        'description': 'Convert documents between different formats',
      },
      {
        'title': 'Document Summarizer',
        'icon': Icons.summarize,
        'color': Colors.green,
        'page': const DocumentSummarizePage(),
        'description': 'Get quick summaries of your documents',
      },
      {
        'title': 'Speech Recognition',
        'icon': Icons.mic,
        'color': Colors.orange,
        'page': const SpeechRecognitionScreen(),
        'description': 'Convert speech to text in real-time',
      },
      {
        'title': 'Translation',
        'icon': Icons.translate,
        'color': Colors.purple,
        'page': const TranslateScreen(),
        'description': 'Translate text between languages',
      },
      {
        'title': 'Text Detection',
        'icon': Icons.document_scanner,
        'color': Colors.red,
        'page': GalleryView(),
        'description': 'Detect and extract text from images',
      },
      {
        'title': 'Prompt History',
        'icon': Icons.history,
        'color': Colors.teal,
        'page': PromptListView(),
        'description': 'View and manage your prompt history',
      },
      {
        'title': 'Audio Processing',
        'icon': Icons.audio_file,
        'color': Colors.amber,
        'page': AudioProcessPage(),
        'description': 'Process and analyze audio files',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        title: const Text('AI Tools'),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a tool to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final tool = tools[index];
                  return _buildToolCard(
                    title: tool['title'],
                    icon: tool['icon'],
                    color: tool['color'],
                    description: tool['description'],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => tool['page'],
                        ),
                      );
                    },
                  );
                },
                childCount: tools.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}