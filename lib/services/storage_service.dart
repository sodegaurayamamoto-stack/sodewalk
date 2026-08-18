import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _pointsKey = 'user_points';
  static const int defaultPoints = 0;

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

  String _dayKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  // --- 歩数ボーナス（今日の歩数をリアルタイム判定） ---
  // tier: 0 = 未獲得, 1 = 5000歩ボーナス獲得済み, 2 = 8000歩ボーナス獲得済み（合計10pt）

  static const String _dailyRewardTierKey = 'daily_reward_tier_';

  Future<int> getDailyRewardTier(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_dailyRewardTierKey${_dayKey(date)}') ?? 0;
  }

  Future<void> setDailyRewardTier(DateTime date, int tier) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_dailyRewardTierKey${_dayKey(date)}', tier);
  }

  /// 今日の歩数を渡して、閾値を超えていればポイントを加算する。
  /// 5000歩以上で+5pt、8000歩以上で合計10pt（5000達成済みなら追加+5pt）。
  /// 1日のうち、それぞれの段階は1回だけ加算される。
  Future<StepRewardResult?> processStepReward(int todaySteps) async {
    final today = DateTime.now();
    final currentTier = await getDailyRewardTier(today);

    int newTier = currentTier;
    int earned = 0;

    if (todaySteps >= 8000 && currentTier < 2) {
      earned = currentTier == 1 ? 5 : 10;
      newTier = 2;
    } else if (todaySteps >= 5000 && currentTier < 1) {
      earned = 5;
      newTier = 1;
    }

    if (earned <= 0) return null;

    final totalPoints = await addPoints(earned);
    await setDailyRewardTier(today, newTier);

    return StepRewardResult(
      steps: todaySteps,
      earnedPoints: earned,
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

  // --- ガウラコイン関連 ---

  static const String _gauraCoinKey = 'gaura_coins';
  static const String _gauraCoinDateKey = 'gaura_coin_date';
  static const int maxGauraCoins = 999;

  Future<int> getGauraCoins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_gauraCoinKey) ?? 0;
  }

  Future<int> addGauraCoin() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_gauraCoinKey) ?? 0;
    final updated = (current + 1).clamp(0, maxGauraCoins);
    await prefs.setInt(_gauraCoinKey, updated);
    return updated;
  }

  Future<bool> useGauraCoin() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_gauraCoinKey) ?? 0;
    if (current <= 0) return false;
    await prefs.setInt(_gauraCoinKey, current - 1);
    return true;
  }

  Future<bool> hasGauraCoinToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_gauraCoinDateKey);
    if (savedDate == null) return false;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    return savedDate == todayStr;
  }

  Future<int?> tryGiveGauraCoin() async {
    final already = await hasGauraCoinToday();
    if (already) return null;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    await prefs.setString(_gauraCoinDateKey, todayStr);
    return await addGauraCoin();
  }

  // --- ガウラガチャ関連 ---

  Future<String?> drawGauraGacha(List<String> allIds) async {
    final collected = await getCollectedGaura();
    final uncollected = allIds.where((id) => !collected.contains(id)).toList();
    if (uncollected.isEmpty) return null;
    final random = Random();
    final drawn = uncollected[random.nextInt(uncollected.length)];
    await addGaura(drawn);
    return drawn;
  }

  // --- ガウラくん探索ポイント（1日1回）関連 ---

  static const String _gauraPointDateKey = 'gaura_point_date';

  Future<bool> hasGauraPointToday() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDate = prefs.getString(_gauraPointDateKey);
    if (savedDate == null) return false;
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    return savedDate == todayStr;
  }

  Future<int?> tryGiveGauraPoint() async {
    final already = await hasGauraPointToday();
    if (already) return null;
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month}-${today.day}';
    await prefs.setString(_gauraPointDateKey, todayStr);
    return await addPoints(5);
  }

  // --- ガウラくん収集関連 ---

  static const String _gauraKey = 'collected_gaura';

  Future<Set<String>> getCollectedGaura() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_gauraKey) ?? [];
    return list.toSet();
  }

  Future<bool> addGaura(String locationId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_gauraKey) ?? [];
    if (!list.contains(locationId)) {
      list.add(locationId);
      await prefs.setStringList(_gauraKey, list);
      return true;
    }
    return false;
  }

  Future<bool> hasGaura(String locationId) async {
    final collected = await getCollectedGaura();
    return collected.contains(locationId);
  }
}

class StepRewardResult {
  final int steps;
  final int earnedPoints;
  final int totalPoints;

  StepRewardResult({
    required this.steps,
    required this.earnedPoints,
    required this.totalPoints,
  });
}
