import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:ai_summarization/model/prompt_model.dart';
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
      String imagePath, String selectedOption, bool isOnPage) async {
    if (!isOnPage) {
      throw Exception('Request canceled because not on page');
    }

    var request = http.MultipartRequest(
        'POST', Uri.parse('http://192.168.1.106:8000/format'));

    // Add file
    request.files.add(await http.MultipartFile.fromPath(
      'image',
      imagePath,
    ));

    request.fields['option'] = selectedOption;

    // Send request with timeout
    var response = await request.send().timeout(
          const Duration(minutes: 5),
          onTimeout: () => throw TimeoutException('Detection timeout'),
        );

    // Handle response
    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);
      return jsonResponse['extracted_text'];
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
