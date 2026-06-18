import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// アプリ内データ（ポイント・歩数履歴）をQRコード等で
/// 別端末へ引き継ぐためのバックアップ・復元処理。
class BackupService {
  final StorageService _storage = StorageService();

  /// 現在のポイントと、保存されている全月の歩数データをまとめて
  /// 1つのJSON文字列にエンコードする。
  Future<String> exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final points = await _storage.getPoints();

    // SharedPreferencesに保存されている「年-月」形式のキー
    // （歩数データ）を全部探して集める。
    final allKeys = prefs.getKeys();
    final Map<String, String> monthlyStepsRaw = {};
    for (final key in allKeys) {
      if (_isMonthKey(key)) {
        final value = prefs.getString(key);
        if (value != null) {
          monthlyStepsRaw[key] = value;
        }
      }
    }

    final payload = {
      'version': 1,
      'points': points,
      'monthlySteps': monthlyStepsRaw,
    };

    return json.encode(payload);
  }

  /// "2026-6" のような「年-月」キーかどうかを判定する。
  bool _isMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return false;
    return int.tryParse(parts[0]) != null && int.tryParse(parts[1]) != null;
  }

  /// QRコード等から読み取った文字列をデコードし、
  /// ポイント・歩数データを上書き保存する。
  /// 成功した場合はtrue、フォーマットが不正な場合はfalseを返す。
  Future<bool> importData(String rawData) async {
    try {
      final decoded = json.decode(rawData) as Map<String, dynamic>;
      final points = decoded['points'] as int;
      final monthlySteps = decoded['monthlySteps'] as Map<String, dynamic>;

      await _storage.setPoints(points);

      final prefs = await SharedPreferences.getInstance();
      for (final entry in monthlySteps.entries) {
        await prefs.setString(entry.key, entry.value as String);
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
