import 'package:flutter/material.dart';
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
  int? _currentTotalSteps;

  late Stream<StepCount> _stepCountStream;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addObserver(this);
    _initPedometer();
    _loadCoins();
    _processRewardOnOpen();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSavedSteps();
      _loadCoins();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // アプリを開いた時に昨日の歩数報酬を処理
  Future<void> _processRewardOnOpen() async {
    final reward = await _storage.processYesterdayReward();
    if (reward != null && mounted) {
      setState(() => _steps = reward.totalPoints);
      _showRewardDialog(reward);
    }
  }

  // 夜間歩数を記録（21時通知タップ時に呼ばれる）
  Future<void> _saveEveningStepsIfNeeded() async {
    if (_currentTotalSteps == null) return;
    final now = DateTime.now();
    // 20時〜23時の間に開いた場合のみ夜間歩数として記録
    if (now.hour >= 20 && now.hour <= 23) {
      await _storage.saveEveningSteps(_currentTotalSteps!);
    }
  }

  void _showRewardDialog(RewardResult reward) {
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
            const Text(
              '昨日の歩数ボーナス！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Text(
              '昨日は ${reward.steps} 歩歩きました！',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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

  Future<void> _loadCoins() async {
    final coins = await _storage.getGauraCoins();
    if (mounted) setState(() => _gauraCoins = coins);
  }

  Future<void> _loadSavedSteps() async {
    final saved = await _storage.getStepsForDay(DateTime.now());
    if (mounted) setState(() => _steps = saved);
  }

  Future<void> _initPedometer() async {
    final saved = await _storage.getStepsForDay(DateTime.now());
    if (mounted) setState(() => _steps = saved);

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
      _stepCountStream = Pedometer.stepCountStream;
      _stepCountStream.listen(
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

  Future<void> _onStepCount(StepCount event) async {
    final totalSteps = event.steps;
    _currentTotalSteps = totalSteps;

    int? base = await _storage.getStepBase();
    if (base == null) {
      await _storage.saveStepBase(totalSteps);
      base = totalSteps;
    }
    final todaySteps = (totalSteps - base).clamp(0, 999999);
    await _storage.setStepsForDay(DateTime.now(), todaySteps);

    // 20〜23時の間なら夜間歩数を自動保存
    await _saveEveningStepsIfNeeded();

    if (mounted) {
      setState(() {
        _steps = todaySteps;
        _statusMessage = '';
        _isError = false;
      });
    }
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
                    const Text('今日の歩数', style: TextStyle(fontSize: 18, color: Colors.grey)),
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
