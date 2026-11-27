import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:confetti/confetti.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/location.dart';
import '../services/storage_service.dart';
import 'history_page.dart';
import 'destination_picker_page.dart';
import 'gaura_collection_page.dart';
import 'gaura_gacha_page.dart';

class PedometerPage extends StatefulWidget {
  const PedometerPage({super.key});

  @override
  State<PedometerPage> createState() => _PedometerPageState();
}

class _PedometerPageState extends State<PedometerPage>
    with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  late ConfettiController _confettiController;

  int _steps = 0;
  int _gauraCoins = 0;
  String _statusMessage = '読み込み中...';
  bool _isError = false;
  bool _isSearchingGaura = false;

  // --- 歩数の計算に使う値 ---
  // 今日の歩数 = 端末の現在の累計歩数 − 今日の0時時点の累計歩数（基準値）
  int _currentSystemSteps = 0; // 端末が最後に報告した累計歩数
  bool _hasSystemReading = false; // センサーから1回でも値を受け取ったか
  int? _baseline; // 今日の基準値（0時時点の累計歩数）
  String? _baselineDay; // 基準値が決まった日
  int? _lastValue; // 前回読み取った累計歩数（保存済み）
  int? _lastMs; // 前回読み取った時刻（保存済み）

  // 0時をまたいだとき、前回の読み取りが0時の何時間前までなら
  // 「その値＝0時時点の歩数」とみなすか
  static const int _maxGapBeforeMidnightMs = 3 * 60 * 60 * 1000;

  // --- ヘルスコネクト方式（メイン） ---
  // Android の「ヘルスコネクト」に溜まっている歩数から、
  // 「今日の0時〜今」の合計を直接取得する。アプリを閉じていた間の歩数も入る。
  final Health _health = Health();
  bool _useHealth = false; // ヘルスコネクトを使えているか
  int? _healthSteps; // 最後にヘルスコネクトから取得した今日の歩数
  int? _healthReadMs; // その取得時刻
  String _healthState = '未確認'; // 確認用画面に出す状態
  bool _refreshingHealth = false;
  String? _backfilledDay; // 過去分の履歴を補完した日
  Timer? _healthTimer;

  StreamSubscription<StepCount>? _stepSub;
  Timer? _midnightTimer;
  Future<void> _queue = Future.value();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addObserver(this);
    _loadCoins();
    _initPedometer();
    _scheduleMidnightTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _saveCurrentSteps();
    }
    if (state == AppLifecycleState.resumed) {
      _loadCoins();
      _scheduleMidnightTimer();
      // 画面を閉じている間に日付が変わっていたら、0時のリセットを反映する
      if (_useHealth) {
        _refreshFromHealth();
      } else if (_hasSystemReading) {
        final value = _currentSystemSteps;
        _enqueue(() => _processReading(value, fromSensor: false));
      }
    }
  }

  @override
  void dispose() {
    _midnightTimer?.cancel();
    _healthTimer?.cancel();
    _stepSub?.cancel();
    _confettiController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 歩数の処理を1件ずつ順番に実行する（同時に走って値が混ざるのを防ぐ）
  void _enqueue(Future<void> Function() job) {
    _queue = _queue.then((_) => job()).catchError((_) {});
  }

  Future<void> _saveCurrentSteps() async {
    await _storage.setStepsForDay(DateTime.now(), _steps);
  }

  String _dayKeyString(DateTime date) => '${date.year}-${date.month}-${date.day}';

  int _clampSteps(int value) {
    if (value < 0) return 0;
    if (value > 999999) return 999999;
    return value;
  }

  // アプリを開いたまま0時を迎えたときに、自動で歩数を0に戻すタイマー
  void _scheduleMidnightTimer() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(
      nextMidnight.difference(now) + const Duration(seconds: 1),
      () {
        if (_useHealth) {
          _refreshFromHealth();
        } else if (_hasSystemReading) {
          final value = _currentSystemSteps;
          _enqueue(() => _processReading(value, fromSensor: false));
        }
        _scheduleMidnightTimer();
      },
    );
  }

  Future<void> _loadStepState() async {
    _baselineDay = await _storage.getStepBaseDay();
    _baseline = await _storage.getStepBase();
    _lastValue = await _storage.getLastSystemSteps();
    _lastMs = await _storage.getLastSystemStepsMs();
  }

  Future<void> _setBaseline(DateTime day, int value) async {
    _baseline = value;
    _baselineDay = _dayKeyString(day);
    await _storage.setStepBase(day, value);
  }

  // 日付が変わって最初の歩数データが来たときに、今日の基準値を決める
  Future<void> _startNewDay(int systemSteps, DateTime now) async {
    int base;
    final lastV = _lastValue;
    final lastMs = _lastMs;

    if (_baselineDay == null) {
      // この方式で初めて起動したとき。今日すでに記録済みの歩数があれば引き継ぐ
      final saved = await _storage.getStepsForDay(now);
      base = systemSteps - saved;
    } else if (lastV != null && systemSteps < lastV) {
      // 端末が再起動されて累計が0から数え直しになっている
      base = 0;
    } else if (lastV != null && lastMs != null) {
      final midnight = DateTime(now.year, now.month, now.day);
      final gapMs = midnight.millisecondsSinceEpoch - lastMs;
      if (gapMs >= 0 && gapMs <= _maxGapBeforeMidnightMs) {
        // 0時の直前に読み取った値 ＝ 0時時点の歩数
        base = lastV;
      } else {
        // 0時の頃の記録がない場合は、今日最初に読み取った値を基準にする
        base = systemSteps;
      }
    } else {
      base = systemSteps;
    }

    await _setBaseline(now, base);
  }

  // 歩数データ1件の処理（fromSensor=false は日付変更の確認だけ）
  Future<void> _processReading(int systemSteps, {required bool fromSensor}) async {
    final now = DateTime.now();
    final today = _dayKeyString(now);

    if (_baselineDay != today) {
      await _startNewDay(systemSteps, now);
    } else if (fromSensor && _lastValue != null && systemSteps < _lastValue!) {
      // 同じ日のうちに端末が再起動された: 再起動前の歩数 + 再起動後の累計
      final savedToday = await _storage.getStepsForDay(now);
      await _setBaseline(now, -savedToday);
    }

    if (fromSensor) {
      _currentSystemSteps = systemSteps;
      _hasSystemReading = true;
      _lastValue = systemSteps;
      _lastMs = now.millisecondsSinceEpoch;
      await _storage.setLastSystemSteps(systemSteps, now);
    }

    final todaySteps = _clampSteps(systemSteps - (_baseline ?? systemSteps));

    if (mounted) {
      setState(() {
        _steps = todaySteps;
        if (fromSensor) {
          _statusMessage = '';
          _isError = false;
        }
      });
    }

    await _storage.setStepsForDay(now, todaySteps);
    await _checkStepReward(todaySteps);
  }

  Future<void> _checkStepReward(int todaySteps) async {
    final reward = await _storage.processStepReward(todaySteps);
    if (reward != null && mounted) {
      _showStepRewardDialog(reward);
    }
  }

  void _showStepRewardDialog(StepRewardResult reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              '今日は ${reward.steps} 歩達成！',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              '+${reward.earnedPoints} pt ゲット！',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('閉じる', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // 「今日の歩数」の文字を長押しすると、基準値の確認画面が開く（動作確認用）
  void _showStepDiagnostics() {
    String fmtTime(int? ms) {
      if (ms == null) return '-';
      final t = DateTime.fromMillisecondsSinceEpoch(ms);
      String two(int n) => n.toString().padLeft(2, '0');
      return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('歩数の確認用情報', style: TextStyle(fontSize: 18)),
        content: Text(
          '今日の歩数: $_steps\n'
          'データ元: ${_useHealth ? 'ヘルスコネクト' : '端末センサー'}\n'
          'ヘルスコネクト: $_healthState\n'
          'ヘルスコネクトの今日の歩数: ${_healthSteps ?? '-'} (${fmtTime(_healthReadMs)})\n'
          '--- センサー方式（予備） ---\n'
          '端末の現在の累計: ${_hasSystemReading ? _currentSystemSteps : '-'}\n'
          '基準値(0時の累計): ${_baseline ?? '-'}\n'
          '基準値の日付: ${_baselineDay ?? '-'}\n'
          '前回の読み取り: ${_lastValue ?? '-'} (${fmtTime(_lastMs)})',
          style: const TextStyle(fontSize: 14, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadCoins() async {
    final coins = await _storage.getGauraCoins();
    if (mounted) setState(() => _gauraCoins = coins);
  }

  Future<void> _initPedometer() async {
    final saved = await _storage.getStepsForDay(DateTime.now());
    if (mounted) setState(() => _steps = saved);

    await _loadStepState();
    await _checkStepReward(saved);

    // まずヘルスコネクトを試す（0時からの合計を直接取れるので一番正確）
    if (await _setupHealthConnect()) {
      await _refreshFromHealth();
      _startHealthTimer();
      return;
    }

    // ヘルスコネクトが使えない場合は、前回作った端末センサー方式に切り替える
    await _startSensor();
  }

  // ヘルスコネクトが使える状態か確認し、歩数の読み取り許可をもらう
  Future<bool> _setupHealthConnect() async {
    try {
      await _health.configure();

      final sdk = await _health.getHealthConnectSdkStatus();
      if (sdk != HealthConnectSdkStatus.sdkAvailable) {
        _healthState = '使えません ($sdk)';
        return false;
      }

      const types = [HealthDataType.STEPS];
      const access = [HealthDataAccess.READ];

      var granted = await _health.hasPermissions(types, permissions: access) ?? false;
      if (!granted) {
        granted = await _health.requestAuthorization(types, permissions: access);
      }
      if (!granted) {
        _healthState = '歩数の読み取りが許可されていません';
        return false;
      }

      _useHealth = true;
      _healthState = '許可済み';
      return true;
    } catch (e) {
      _healthState = 'エラー: $e';
      return false;
    }
  }

  void _startHealthTimer() {
    _healthTimer?.cancel();
    // 画面を開いている間は30秒ごとに最新の歩数を読み直す
    _healthTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshFromHealth(),
    );
  }

  // 「今日の0時〜今」の歩数をヘルスコネクトから取得して表示・保存する
  Future<void> _refreshFromHealth() async {
    if (!_useHealth || _refreshingHealth) return;
    _refreshingHealth = true;
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final hc = await _health.getTotalStepsInInterval(midnight, now);

      _healthSteps = hc;
      _healthReadMs = now.millisecondsSinceEpoch;

      // 取得に失敗した時や、記録が始まった直後で少ない時に、
      // すでに保存してある今日の歩数を下回らないようにする
      final savedToday = await _storage.getStepsForDay(now);
      final todaySteps = _clampSteps(max(hc ?? 0, savedToday));

      if (mounted) {
        setState(() {
          _steps = todaySteps;
          _statusMessage = '';
          _isError = false;
        });
      }

      await _storage.setStepsForDay(now, todaySteps);
      await _checkStepReward(todaySteps);
      await _backfillHistory(now);
    } catch (e) {
      _healthState = 'エラー: $e';
    } finally {
      _refreshingHealth = false;
    }
  }

  // アプリを開かなかった日の歩数を、ヘルスコネクトから履歴に補完する（過去7日分・1日1回）
  // ※ポイントは付与しません。履歴の歩数だけを正しくします。
  Future<void> _backfillHistory(DateTime now) async {
    final todayKey = _dayKeyString(now);
    if (_backfilledDay == todayKey) return;
    _backfilledDay = todayKey;

    for (int i = 1; i <= 7; i++) {
      final dayStart = DateTime(now.year, now.month, now.day - i);
      final dayEnd = DateTime(now.year, now.month, now.day - i + 1);
      try {
        final hc = await _health.getTotalStepsInInterval(dayStart, dayEnd);
        final saved = await _storage.getStepsForDay(dayStart);
        if (hc != null && hc > saved) {
          await _storage.setStepsForDay(dayStart, _clampSteps(hc));
        }
      } catch (_) {
        // 補完は失敗しても本体の動作に影響しない
      }
    }
  }

  // 端末の歩数センサー方式（ヘルスコネクトが使えない時の予備）
  Future<void> _startSensor() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _statusMessage = '歩数センサーの利用が許可されていません。設定から許可してください。';
          _isError = true;
        });
      }
      return;
    }

    try {
      _stepSub = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
      );
      if (mounted) {
        setState(() {
          _statusMessage = '';
          _isError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'この端末では歩数センサーが利用できません。';
          _isError = true;
        });
      }
    }
  }

  void _onStepCount(StepCount event) {
    final systemSteps = event.steps;
    _enqueue(() => _processReading(systemSteps, fromSensor: true));
  }

  void _onStepCountError(error) {
    if (mounted) {
      setState(() {
        _statusMessage = '歩数センサーの利用が許可されていません。設定から許可してください。';
        _isError = true;
      });
    }
  }

  Future<void> _searchGaura() async {
    setState(() => _isSearchingGaura = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showGauraMessage('位置情報が無効です。設定から有効にしてください。');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showGauraMessage('位置情報の利用を許可してください。');
          return;
        }
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final jsonString = await rootBundle.loadString('assets/locations.json');
      final data = json.decode(jsonString);
      final locations = (data['locations'] as List)
          .map((e) => WalkLocation.fromJson(e as Map<String, dynamic>))
          .toList();

      final nearbySpots = locations.where((loc) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          loc.lat,
          loc.lng,
        );
        return distance <= 100;
      }).toList();

      if (nearbySpots.isEmpty) {
        _showGauraNotFound();
        return;
      }

      final spot = nearbySpots.first;
      final coinResult = await _storage.tryGiveGauraCoin();
      final pointResult = await _storage.tryGiveGauraPoint();

      if (mounted) {
        _showGauraFound(spot, coinResult, pointResult);
      }
    } catch (e) {
      if (mounted) {
        _showGauraMessage('エラーが発生しました。もう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _isSearchingGaura = false);
    }
  }

  void _showGauraNotFound() {
    setState(() => _isSearchingGaura = false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              '近くにはガウラくんは\nいないみたい。',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '目的地を決めるを押して\nガウラくんを探そう！',
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('閉じる', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _showGauraFound(WalkLocation spot, int? coinResult, int? pointResult) {
    final alreadyToday = coinResult == null && pointResult == null;

    if (!alreadyToday) {
      _confettiController.play();
    }

    showDialog(
      context: context,
      builder: (context) => Stack(
        children: [
          AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(alreadyToday ? '✨' : '🎉', style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  alreadyToday ? '今日はもう出会ったよ！' : 'ガウラくんに出会った！',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: alreadyToday ? Colors.blue : Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Image.asset('assets/gaura_normal.png', width: 140, height: 140),
                const SizedBox(height: 8),
                Text(
                  'スポット名：${spot.name}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                if (!alreadyToday) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/gaura_coin.png', width: 28, height: 28),
                      const SizedBox(width: 6),
                      const Text('+1', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber)),
                      const SizedBox(width: 16),
                      const Text('+5pt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _loadCoins();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('閉じる', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 20,
              gravity: 0.1,
              emissionFrequency: 0.05,
              colors: const [
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.pink,
              ],
              createParticlePath: (size) {
                final path = Path();
                path.addRect(Rect.fromCenter(
                  center: Offset.zero,
                  width: size.width,
                  height: size.height,
                ));
                return path;
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showGauraMessage(String message) {
    setState(() => _isSearchingGaura = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.orange),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final stepsText = '$_steps';
    double stepsFontSize;
    if (stepsText.length <= 3) {
      stepsFontSize = 80;
    } else if (stepsText.length == 4) {
      stepsFontSize = 64;
    } else {
      stepsFontSize = 50;
    }
    if (screenWidth < 360) stepsFontSize *= 0.85;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.blueGrey),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryPage()),
                );
              },
              icon: const Icon(Icons.history, color: Colors.blueGrey, size: 26),
              label: const Text('履歴', style: TextStyle(fontSize: 18, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom -
                  kToolbarHeight,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset('assets/gaura_coin.png', width: 32, height: 32),
                        const SizedBox(width: 8),
                        Text(
                          '× $_gauraCoins',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onLongPress: _showStepDiagnostics,
                      child: const Text('今日の歩数', style: TextStyle(fontSize: 18, color: Colors.grey)),
                    ),
                    const SizedBox(height: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        stepsText,
                        style: TextStyle(fontSize: stepsFontSize, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ),
                    const Text('歩', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    if (_statusMessage.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _statusMessage,
                          style: TextStyle(fontSize: 14, color: _isError ? Colors.red : Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 40),
                    SizedBox(
                      width: screenWidth * 0.7,
                      child: ElevatedButton(
                        onPressed: _isSearchingGaura ? null : _searchGaura,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: _isSearchingGaura
                            ? const Text('探索中...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                            : const Text(
                                'ガウラくんを探して\nポイントゲット',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildWideButton(
                      label: '目的地を決める',
                      color: Colors.green,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DestinationPickerPage()),
                        );
                      },
                      fontSize: 20,
                    ),
                    const SizedBox(height: 16),
                    _buildWideButton(
                      label: 'ガウラガチャ',
                      color: Colors.amber.shade600,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GauraGachaPage()),
                        ).then((_) => _loadCoins());
                      },
                      fontSize: 20,
                    ),
                    const SizedBox(height: 16),
                    _buildWideButton(
                      label: 'ガウラ図鑑',
                      color: Colors.indigo.shade400,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const GauraCollectionPage()),
                        );
                      },
                      fontSize: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    double fontSize = 20,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.7;

    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
      ),
    );
  }
}
