import 'dart:convert';
import 'package:http/http.dart' as http;

/// Google Apps Script(GAS)経由でGoogleスプレッドシートへ
/// 注文データを送信するサービス。
///
/// 旧Formrun方式(別タブを開いて手動送信)を置き換え、
/// アプリ内から直接送信を完了できるようにしている。
class GoogleSheetsService {
  // 🔒 Google Apps Scriptのウェブアプリ デプロイURL
  static const String _scriptUrl =
      'https://script.google.com/macros/s/AKfycbyrGbHHe6_bpEstTqpatzaD-0aAdLVqgecESBTFWopkVkrRJoNEpgDj8AOXwgDPpPOn/exec';

  /// 注文情報を送信する。成功した場合はtrue、失敗した場合はfalseを返す。
  Future<bool> submitOrder({
    required String name,
    required String address,
    required String phone,
    required String itemName,
    required int itemPoints,
    required String preferredDate,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'address': address,
          'phone': phone,
          'itemName': itemName,
          'itemPoints': itemPoints,
          'preferredDate': preferredDate,
        }),
      );

      // Google Apps ScriptのWebアプリは302リダイレクトを返すことがあり、
      // ステータスコードだけでは正確に成否を判定できない場合がある。
      // そのため、レスポンスボディの中身（GAS側が返すJSON）も確認する。
      if (response.statusCode == 200 || response.statusCode == 302) {
        return response.body.contains('success');
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}