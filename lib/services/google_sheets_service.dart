import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsService {
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbyrGbHHe6_bpEstTqpatzaD-0aAdLVqgecESBTFWopkVkrRJoNEpgDj8AOXwgDPpPOn/exec';

  static String lastDebugInfo = '';

  Future<bool> submitOrder({
    required String name,
    required String address,
    required String phone,
    required String itemName,
    required int itemPoints,
    required String preferredDate,
  }) async {
    try {
      // GASはPOSTに対して302リダイレクトを返す仕様のため、
      // クエリパラメータ付きのGETリクエストで送信する
      final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
        'name': name,
        'address': address,
        'phone': phone,
        'itemName': itemName,
        'itemPoints': itemPoints.toString(),
        'preferredDate': preferredDate,
      });

      final response = await http.get(uri);

      GoogleSheetsService.lastDebugInfo =
          'statusCode: ${response.statusCode}\nbody: ${response.body}';

      if (response.statusCode == 200) {
        return response.body.contains('success');
      }
      return false;
    } catch (e) {
      GoogleSheetsService.lastDebugInfo = 'エラー: $e';
      return false;
    }
  }
}