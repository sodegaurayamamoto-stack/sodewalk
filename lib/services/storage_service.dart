import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<Map<String, int>> getMonthSteps(int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _monthKey(DateTime(year, month));
    final savedJson = prefs.getString(key);
    if (savedJson == null) return {};
    final decoded = json.decode(savedJson) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v as int));
  }

  Future<int> getStepsForDay(DateTime date) async {
    final monthData = await getMonthSteps(date.year, date.month);
    return monthData[date.day.toString()] ?? 0;
  }

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

  int calculateEarnedPoints(int steps) {
    if (steps >= 8000) return 10;
    if (steps >= 5000) return 5;
    return 0;
  }

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

  Future<int?> processTodayLoginBonus() async {
    final today = DateTime.now();
    final alreadyGiven = await isLoginBonusAlreadyGiven(today);
    if (alreadyGiven) return null;
    final totalPoints = await addPoints(1);
    await markLoginBonusGiven(today);
    return totalPoints;
  }

  // --- 到着ボーナス関連 ---

  static const String _arrivalBonusDateKey = 'arrival_bonus_date';
  static const String _arrivalBonusLocationKey = 'arrival_bonus_location';

  /// 今日すでに到着ボーナスを取得済みかチェック
  Future<bool> hasArrivalBonusToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_arrivalBonusDateKey);
    if (savedDate == null) return false;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    return savedDate == todayStr;
  }

  /// 今日到着ボーナスを取得した場所のIDを取得
  Future<String?> getTodayArrivalLocationId() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_arrivalBonusDateKey);
    if (savedDate == null) return null;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    if (savedDate != todayStr) return null;
    return prefs.getString(_arrivalBonusLocationKey);
  }

  /// 到着ボーナスを付与して記録する
  Future<int> giveArrivalBonus(String locationId) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    await prefs.setString(_arrivalBonusDateKey, todayStr);
    await prefs.setString(_arrivalBonusLocationKey, locationId);
    // ガウラくんを追加
    await addGaura(locationId);
    return await addPoints(5);
  }

  // --- ガウラくん収集関連 ---

  static const String _gauraKey = 'collected_gaura';

  /// 収集済みガウラくんのIDセットを取得
  Future<Set<String>> getCollectedGaura() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_gauraKey) ?? [];
    return list.toSet();
  }

  /// ガウラくんを追加
  Future<void> addGaura(String locationId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_gauraKey) ?? [];
    if (!list.contains(locationId)) {
      list.add(locationId);
      await prefs.setStringList(_gauraKey, list);
    }
  }

  /// 指定したガウラくんを取得済みかチェック
  Future<bool> hasGaura(String locationId) async {
    final collected = await getCollectedGaura();
    return collected.contains(locationId);
  }
}

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