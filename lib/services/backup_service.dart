import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'storage_service.dart';

/// アプリ内データ（ポイント・歩数履歴・ガウラ図鑑・ガウラコイン）を
/// QRコード等で別端末へ引き継ぐためのバックアップ・復元処理。
class BackupService {
  final StorageService _storage = StorageService();

  // storage_service.dart と同じキー名
  static const String _gauraKey = 'collected_gaura';
  static const String _gauraCoinKey = 'gaura_coins';

  /// 現在のポイント・歩数データ・ガウラ図鑑・ガウラコインを
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
      'version': 2,
      'points': points,
      'monthlySteps': monthlyStepsRaw,
      'gaura': prefs.getStringList(_gauraKey) ?? <String>[],
      'gauraCoins': prefs.getInt(_gauraCoinKey) ?? 0,
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
  /// ガウラ図鑑は、この端末にある分と足し合わせる（減らさない）。
  /// ガウラコインは、多いほうを採用する。
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

      // --- ガウラ図鑑（旧形式のコードには無いので、あるときだけ処理） ---
      final gauraRaw = decoded['gaura'];
      if (gauraRaw is List) {
        final merged = <String>{
          ...(prefs.getStringList(_gauraKey) ?? <String>[]),
          ...gauraRaw.map((e) => e.toString()),
        };
        await prefs.setStringList(_gauraKey, merged.toList());
      }

      // --- ガウラコイン ---
      final coinRaw = decoded['gauraCoins'];
      if (coinRaw is int) {
        final current = prefs.getInt(_gauraCoinKey) ?? 0;
        final best = coinRaw > current ? coinRaw : current;
        await prefs.setInt(_gauraCoinKey, best.clamp(0, 999));
      }

      return true;
    } catch (e) {
      return false;
    }
  }
}
