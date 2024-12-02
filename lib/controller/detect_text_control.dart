import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class DetectTextControl {
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

  Future<String> generateTextFromImage(String imageUrl) async {
    if (localIp == null) {
      throw Exception('Local IP is not set');
    }

    final response = await http.post(
      Uri.parse('http://192.168.0.171:8000/ocr'),
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
}
