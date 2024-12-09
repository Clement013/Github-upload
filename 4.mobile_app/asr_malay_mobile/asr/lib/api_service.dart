import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService {
  final String baseUrl = 'https://asr.clementzq.top/api/transcribe';

  Future<String> transcribeAudio(File audioFile, String secret) async {
    var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
    request.files
        .add(await http.MultipartFile.fromPath('audio', audioFile.path));
    request.fields['secret'] = secret;

    var response = await request.send();
    if (response.statusCode == 200) {
      final responseData = await response.stream.bytesToString();
      return json.decode(responseData)['Data'];
    } else {
      throw Exception('Failed to transcribe audio');
    }
  }
}
