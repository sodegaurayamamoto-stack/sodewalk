import 'package:flutter/material.dart';
import 'package:accurate_step_counter/accurate_step_counter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/location.dart';
import '../services/storage_service.dart';
import 'history_page.dart';
import 'destination_picker_page.dart';
import 'gaura_collection_page.dart';

class PedometerPage extends StatefulWidget {
  const PedometerPage({super.key});

  @override
  State<PedometerPage> createState() => _PedometerPageState();
}

class _PedometerPageState extends State<PedometerPage>
    with WidgetsBindingObserver {
  final StorageService _storage = StorageService();
  final AccurateStepCounter _stepCounter = AccurateStepCounter();

  int _steps = 0;
  String _statusMessage = '読み込み中...';
  bool _isError = false;
  bool _isSearchingGaura = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initStepCounter();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _stepCounter.setAppState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stepCounter.dispose();
    super.dispose();
  }

  Future<void> _initStepCounter() async {
    final savedSteps = await _storage.getStepsForDay(DateTime.now());
    if (mounted) {
      setState(() => _steps = savedSteps);
    }

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
      await _stepCounter.initializeLogging(useBackgroundIsolate: true);
      await _stepCounter.start(config: StepDetectorConfig.walking());
      await _stepCounter.startLogging(config: StepRecordConfig.aggregated());

      _stepCounter.watchAggregatedStepCounter().listen((steps) async {
        await _storage.setStepsForDay(DateTime.now(), steps);
        if (mounted) {
          setState(() {
            _steps = steps;
            _statusMessage = '';
            _isError = false;
          });
        }
      });

      _stepCounter.onTerminatedStepsDetected = (steps, from, to) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('未記録だった $steps 歩を反映しました')),
          );
        }
      };
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'この端末では歩数センサーが利用できません。';
          _isError = true;
        });
      }
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

      final collected = await _storage.getCollectedGaura();
      WalkLocation targetSpot;
      final uncollected = nearbySpots.where((s) => !collected.contains(s.id)).toList();
      if (uncollected.isNotEmpty) {
        targetSpot = uncollected.first;
      } else {
        targetSpot = nearbySpots.first;
      }

      final isNew = await _storage.addGaura(targetSpot.id);
      final earnedPoints = await _storage.tryGiveGauraPoint();

      if (mounted) {
        _showGauraFound(targetSpot, isNew, earnedPoints);
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

  void _showGauraFound(WalkLocation spot, bool isNew, int? earnedPoints) {
    final numStr = int.tryParse(spot.id.replaceAll('l', ''))?.toString().padLeft(3, '0') ?? '001';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isNew ? '🎉' : '✨', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              isNew ? 'ガウラくんをゲット！' : 'ガウラくんはゲット済み！',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isNew ? Colors.orange : Colors.blue,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Image.asset(
                    'assets/gaura/gaura_$numStr.png',
                    width: 80,
                    height: 80,
                  ),
                  const SizedBox(height: 4),
                  Text('No.$numStr', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  Text(spot.name, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (earnedPoints != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  '+5pt ゲット！（合計 ${earnedPoints}pt）',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              )
            else
              Text(
                '今日のポイントはすでにゲット済みです',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
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