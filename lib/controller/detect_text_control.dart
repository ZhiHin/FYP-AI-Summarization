import 'dart:convert';
import 'dart:io';
import 'package:ai_summarization/model/prompt_model.dart';
import 'package:ai_summarization/screen/utils.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class DetectTextControl {
  final PromptModel _promptModel = PromptModel();
  String? localIp;

  Future<String?> getLocalIp() async {
    for (var interface in await NetworkInterface.list()) {
      for (var addr in interface.addresses) {
        if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
          localIp = addr.address;
          return localIp!;
        }
      }
    }
    return null;
  }

  Future<String> generateFormatTextFromImage(
      String imageUrl, String selectedOption) async {
    final response = await http.post(
      Uri.parse('http://192.168.0.171:8000/format'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'image_url': imageUrl, 'option': selectedOption}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['generated_text'];
    } else {
      throw Exception('Failed to generate text');
    }
  }

  Future<void> saveOriginal(List<String> imageUrls, List<String> promptTexts,
      String promptName, String type) async {
    await _promptModel.savePromptToFirebase(
        imageUrls, promptTexts, promptName, type);
  }
}
