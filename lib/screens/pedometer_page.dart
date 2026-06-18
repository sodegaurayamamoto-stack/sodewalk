import 'package:flutter/material.dart';
import 'package:accurate_step_counter/accurate_step_counter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/storage_service.dart';
import 'history_page.dart';
import 'destination_picker_page.dart';

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
    // まず今日保存済みの歩数を読み込んで表示しておく（センサー初期化中も画面が空白にならないように）。
    final savedSteps = await _storage.getStepsForDay(DateTime.now());
    if (mounted) {
      setState(() => _steps = savedSteps);
    }

    // Android 10以上では身体活動（歩数センサー）の権限を明示的にリクエストする必要がある。
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _statusMessage = '歩数センサーの利用が許可されていません。設定から許可してください。';
        });
      }
      return;
    }

    try {
      // SQLiteでの歩数ログ機能を初期化し、検出を開始する。
      // useBackgroundIsolate: trueにすることで、低スペック端末でもUIがスムーズに動く。
      await _stepCounter.initializeLogging(useBackgroundIsolate: true);
      await _stepCounter.start(config: StepDetectorConfig.walking());
      await _stepCounter.startLogging(config: StepRecordConfig.aggregated());

      // 「今日の歩数」をリアルタイムに監視する。
      // アプリが終了していた間の歩数も、再起動時に自動的に反映される。
      _stepCounter.watchAggregatedStepCounter().listen((steps) async {
        await _storage.setStepsForDay(DateTime.now(), steps);
        if (mounted) {
          setState(() {
            _steps = steps;
            _statusMessage = '';
          });
        }
      });

      // アプリが終了していた間の歩数が同期された時に通知する。
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
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('今日の歩数', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 8),
              Text('$_steps', style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.orange)),
              const Text('歩', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (_statusMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _statusMessage,
                    style: const TextStyle(fontSize: 14, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 60),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DestinationPickerPage()),
                  );
                },
                icon: const Icon(Icons.explore, color: Colors.green),
                label: const Text('目的地を決める', style: TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  side: const BorderSide(color: Colors.green, width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}