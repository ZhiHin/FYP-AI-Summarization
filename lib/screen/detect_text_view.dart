import 'package:ai_summarization/controller/detect_text_control.dart';
import 'package:flutter/material.dart';

class DetectTextView extends StatefulWidget {
  final List<String> imageUrls;

  const DetectTextView({Key? key, required this.imageUrls}) : super(key: key);

  @override
  _DetectTextViewState createState() => _DetectTextViewState();
}

class _DetectTextViewState extends State<DetectTextView> {
  final DetectTextControl _control = DetectTextControl();
  bool _combineText = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _control.getLocalIp();
      setState(() {
        _isLoading = false;
      });
      _showSplitOrCombineDialog();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Failed to get local IP address');
    }
  }

  Future<void> _showSplitOrCombineDialog() async {
    bool? combine = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Split or Combine'),
          content: const Text(
              'Do you want to split or combine the text from all images?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // Split
              },
              child: const Text('Split'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Combine
              },
              child: const Text('Combine'),
            ),
          ],
        );
      },
    );

    if (combine != null) {
      setState(() {
        _combineText = combine;
      });
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Text Detection'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _combineText
              ? _buildCombinedTextView()
              : _buildSplitTextView(),
    );
  }

  Widget _buildCombinedTextView() {
    return FutureBuilder<List<String>>(
      future: Future.wait(
          widget.imageUrls.map((url) => _control.generateTextFromImage(url))),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          String combinedText = snapshot.data!.join('\n\n');
          return Column(
            children: [
              Expanded(
                child: PageView.builder(
                  itemCount: widget.imageUrls.length,
                  itemBuilder: (context, index) {
                    return Image.network(widget.imageUrls[index]);
                  },
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: TextEditingController(text: combinedText),
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Combined Text',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildSplitTextView() {
    return ListView.builder(
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        return Column(
          children: [
            Image.network(widget.imageUrls[index]),
            FutureBuilder<String>(
              future: _control.generateTextFromImage(widget.imageUrls[index]),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: TextEditingController(text: snapshot.data),
                      maxLines: null,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Generated Text',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
