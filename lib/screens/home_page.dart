import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../widgets/reward_dialog.dart';
import 'data_transfer_page.dart';
import 'pedometer_page.dart';
import 'eat_main_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final StorageService _storage = StorageService();

  int _points = StorageService.defaultPoints;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // 前日の歩数に応じた報酬処理（未付与なら付与してダイアログ表示）
    final reward = await _storage.processYesterdayReward();
    if (reward != null && mounted) {
      setState(() => _points = reward.totalPoints);
      await RewardDialog.show(
        context,
        steps: reward.steps,
        points: reward.earnedPoints,
      );
    }

    final points = await _storage.getPoints();
    setState(() => _points = points);
  }

  void _openDataTransfer() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DataTransferPage()),
    ).then((_) => _loadInitialData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 8.0),
            child: OutlinedButton.icon(
              onPressed: _openDataTransfer,
              icon: const Icon(Icons.qr_code_2, color: Colors.blueGrey, size: 28),
              label: const Text(
                'データ引き継ぎ設定',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.blueGrey, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _buildTopPointsDisplay(_points),
                    const SizedBox(height: 60),
                    Column(
                      children: [
                        _buildVerticalButton(context, '歩く', Colors.orange, const PedometerPage()),
                        const SizedBox(height: 24),
                        _buildVerticalButton(context, '食べる', Colors.green, const EatMainPage()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0, left: 24.0, right: 24.0),
              child: Text(
                '※当アプリは一市民による有志の開発プロジェクト（非公式）です。袖ケ浦市のマスコットキャラクター「ガウラ」の使用許諾を得て開発しています。',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPointsDisplay(int points) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.orange, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '現在のあなたのポイント',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Text(
            '$points',
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.orange, height: 1.0),
          ),
          const SizedBox(height: 4),
          const Text(
            'pt',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  // ボタンの幅を画面幅の70%に変更。
  // 横に長すぎる印象を解消するため、double.infinityをやめて
  // MediaQueryで画面幅を取得し、その70%を最大幅として使う。
  Widget _buildVerticalButton(BuildContext context, String label, Color color, Widget targetPage) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.7;

    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (context) => targetPage));
          _loadInitialData();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 4,
        ),
        child: Text(label, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      ),
    );
  }
}