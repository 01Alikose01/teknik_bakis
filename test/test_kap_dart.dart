import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('KAP connection test', () async {
    final url = Uri.parse('https://www.kap.org.tr/tr/api/disclosures?pageSize=5');
    print('Fetching KAP via Dart http client...');
    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'tr-TR,tr;q=0.9',
        'Referer': 'https://www.kap.org.tr/',
      });
      print('Status Code: ${response.statusCode}');
      print('Body length: ${response.body.length}');
      if (response.body.length > 500) {
        print('Body (first 500 chars): ${response.body.substring(0, 500)}');
      } else {
        print('Body: ${response.body}');
      }
    } catch (e) {
      print('Error during KAP fetch: $e');
    }
  });
}
