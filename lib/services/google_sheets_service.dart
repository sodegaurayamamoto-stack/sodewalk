import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/vegetable.dart';

class GoogleSheetsService {
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbyrGbHHe6_bpEstTqpatzaD-0aAdLVqgecESBTFWopkVkrRJoNEpgDj8AOXwgDPpPOn/exec';

  static String lastDebugInfo = '';

  Future<List<Vegetable>> fetchVegetables() async {
    try {
      final uri = Uri.parse(_scriptUrl).replace(queryParameters: {
        'action': 'getVegetables',
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = (data['items'] as List<dynamic>? ?? [])
            .map((item) => Vegetable.fromJson(item as Map<String, dynamic>))
            .toList();
        return items;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> submitOrder({
    required String name,
    required String address,
    required String phone,
    required String itemName,
    required int itemPoints,
    String pickupLocation = '',
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
        'pickupLocation': pickupLocation,
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
