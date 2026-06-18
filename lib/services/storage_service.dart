import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// アプリ内のローカルデータ（ポイント・歩数・連携状態）の読み書きを
/// 一元管理するサービスクラス。
///
/// SharedPreferencesへの直接アクセスは、このクラスを経由して行う。
class StorageService {
  static const String _pointsKey = 'user_points';
  static const String _phoneLinkedKey = 'is_phone_linked';
  static const int defaultPoints = 1250;

  // --- ポイント関連 ---

  Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? defaultPoints;
  }

  Future<void> setPoints(int points) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pointsKey, points);
  }

  Future<int> addPoints(int delta) async {
    final current = await getPoints();
    final updated = current + delta;
    await setPoints(updated);
    return updated;
  }

  Future<int> subtractPoints(int delta) async {
    final current = await getPoints();
    final updated = current - delta;
    await setPoints(updated);
    return updated;
  }

  // --- 電話番号連携関連 ---

  Future<bool> isPhoneLinked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_phoneLinkedKey) ?? false;
  }

  Future<void> setPhoneLinked(bool linked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_phoneLinkedKey, linked);
  }

  // --- 歩数関連 ---

  String _monthKey(DateTime date) => "${date.year}-${date.month}";

  /// 指定した月の歩数データ（日付文字列 -> 歩数）を取得する
  Future<Map<String, int>> getMonthSteps(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _monthKey(DateTime(year, month));
    final savedJson = prefs.getString(key);
    if (savedJson == null) return {};
    final decoded = json.decode(savedJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  /// 指定した日の歩数を取得する
  Future<int> getStepsForDay(DateTime date) async {
    final monthData = await getMonthSteps(date.year, date.month);
    return monthData[date.day.toString()] ?? 0;
  }

  /// 指定した日の歩数に加算する（テスト用ボタンや将来のセンサー連携から呼ぶ）
  Future<int> addStepsForDay(DateTime date, int addedSteps) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _monthKey(date);
    final savedJson = prefs.getString(key);
    Map<String, dynamic> monthData =
        savedJson != null ? json.decode(savedJson) : {};

    final dayKey = date.day.toString();
    final current = monthData[dayKey] ?? 0;
    final updated = current + addedSteps;
    monthData[dayKey] = updated;

    await prefs.setString(key, json.encode(monthData));
    return updated;
  }

  /// 指定した日の歩数を、指定した値で直接上書きする
  /// （歩数センサーから取得した「今日の合計歩数」をそのまま保存する用途）
  Future<void> setStepsForDay(DateTime date, int steps) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _monthKey(date);
    final savedJson = prefs.getString(key);
    Map<String, dynamic> monthData =
        savedJson != null ? json.decode(savedJson) : {};

    final dayKey = date.day.toString();
    monthData[dayKey] = steps;

    await prefs.setString(key, json.encode(monthData));
  }

  // --- 歩数報酬（ポイント付与）関連 ---

  String _rewardCheckKey(DateTime date) =>
      "reward_done_${date.year}_${date.month}_${date.day}";

  Future<bool> isRewardAlreadyGiven(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rewardCheckKey(date)) ?? false;
  }

  Future<void> markRewardGiven(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rewardCheckKey(date), true);
  }

  /// 歩数に応じた獲得ポイントを計算する（5001歩以上で5pt、8001歩以上で10pt）
  int calculateEarnedPoints(int steps) {
    if (steps >= 8001) return 10;
    if (steps >= 5001) return 5;
    return 0;
  }

  /// 前日の歩数に応じてポイントを未付与なら付与する。
  /// 付与があった場合は (獲得ポイント, 加算後の合計ポイント) を返す。未付与/対象外ならnull。
  Future<RewardResult?> processYesterdayReward() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final alreadyRewarded = await isRewardAlreadyGiven(yesterday);
    if (alreadyRewarded) return null;

    final steps = await getStepsForDay(yesterday);
    final earnedPoints = calculateEarnedPoints(steps);
    if (earnedPoints <= 0) return null;

    final totalPoints = await addPoints(earnedPoints);
    await markRewardGiven(yesterday);

    return RewardResult(
      steps: steps,
      earnedPoints: earnedPoints,
      totalPoints: totalPoints,
    );
  }

  // --- ログインボーナス関連 ---

  String _loginBonusCheckKey(DateTime date) =>
      "login_bonus_done_${date.year}_${date.month}_${date.day}";

  Future<bool> isLoginBonusAlreadyGiven(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_loginBonusCheckKey(date)) ?? false;
  }

  Future<void> markLoginBonusGiven(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loginBonusCheckKey(date), true);
  }

  /// 今日まだログインボーナスを受け取っていなければ1ポイント付与する。
  /// 付与した場合は加算後の合計ポイントを返す。すでに受け取り済みならnullを返す。
  Future<int?> processTodayLoginBonus() async {
    final today = DateTime.now();
    final alreadyGiven = await isLoginBonusAlreadyGiven(today);
    if (alreadyGiven) return null;

    final totalPoints = await addPoints(1);
    await markLoginBonusGiven(today);
    return totalPoints;
  }
}

/// 前日の歩数報酬処理の結果を表すクラス
class RewardResult {
  final int steps;
  final int earnedPoints;
  final int totalPoints;

  RewardResult({
    required this.steps,
    required this.earnedPoints,
    required this.totalPoints,
  });
}