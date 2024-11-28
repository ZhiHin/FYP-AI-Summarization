import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DetectText extends StatelessWidget {
  final List<String> imageUrls;

  DetectText({required this.imageUrls});

  Future<String> _generateTextFromImage(String imageUrl) async {
    final response = await http.post(
      Uri.parse('http://192.168.1.106:8000/ocr'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image_url': imageUrl}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['generated_text'];
    } else {
      throw Exception('Failed to generate text');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detect Text from Images'),
      ),
      body: ListView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Column(
            children: [
              Image.network(imageUrls[index]),
              FutureBuilder<String>(
                future: _generateTextFromImage(imageUrls[index]),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return CircularProgressIndicator();
                  } else if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  } else {
                    return Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: TextEditingController(text: snapshot.data),
                        maxLines: null,
                        decoration: InputDecoration(
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
      ),
    );
  }
}
