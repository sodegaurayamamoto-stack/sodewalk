import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/storage_service.dart';

class GauraGachaPage extends StatefulWidget {
  const GauraGachaPage({super.key});

  @override
  State<GauraGachaPage> createState() => _GauraGachaPageState();
}

class _GauraGachaPageState extends State<GauraGachaPage> {
  final StorageService _storage = StorageService();
  int _coins = 0;
  List<Map<String, dynamic>> _gauraList = [];
  bool _isLoading = true;
  bool _isDrawing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      _storage.getGauraCoins(),
      rootBundle.loadString('assets/gaura.json'),
    ]);

    final coins = results[0] as int;
    final gauraData = json.decode(results[1] as String);
    final gauraList = (gauraData['gaura'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    setState(() {
      _coins = coins;
      _gauraList = gauraList;
      _isLoading = false;
    });
  }

  Future<void> _drawGacha() async {
    if (_coins <= 0 || _isDrawing) return;

    setState(() => _isDrawing = true);

    final allIds = _gauraList.map((e) => e['id'] as String).toList();
    final collected = await _storage.getCollectedGaura();

    if (collected.length >= allIds.length) {
      _showCompletedDialog();
      setState(() => _isDrawing = false);
      return;
    }

    final success = await _storage.useGauraCoin();
    if (!success) {
      setState(() => _isDrawing = false);
      return;
    }

    final drawnId = await _storage.drawGauraGacha(allIds);

    final drawnItem = _gauraList.firstWhere(
      (e) => e['id'] == drawnId,
      orElse: () => {},
    );

    final newCoins = await _storage.getGauraCoins();

    if (mounted) {
      setState(() {
        _coins = newCoins;
        _isDrawing = false;
      });
      _showResultDialog(drawnItem);
    }
  }

  String _getImagePath(Map<String, dynamic> item) {
    final image = item['image'] as String? ?? '';
    if (image.isNotEmpty) return 'assets/gaura/$image';
    final id = item['id'] as String;
    return 'assets/gaura/$id.png';
  }

  void _showResultDialog(Map<String, dynamic> item) {
    final id = item['id'] as String? ?? '';
    final character = item['character'] as String? ?? '';
    final action = item['action'] as String? ?? '';
    final imagePath = _getImagePath(item);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'ガウラくんゲット！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                children: [
                  Image.asset(imagePath, width: 100, height: 100),
                  const SizedBox(height: 8),
                  Text('No.$id', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  if (action.isNotEmpty)
                    Text('$character（$action）', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                ],
              ),
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

  void _showCompletedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              'コンプリート！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'すべてのガウラくんを\nゲットしました！',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.blueGrey, size: 28),
                    label: const Text('戻る', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ),
                ],
              ),
            ),
            const Text('ガウラガチャ', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Image.asset('assets/gaura_normal.png', width: 140, height: 140),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/gaura_coin.png', width: 36, height: 36),
                const SizedBox(width: 8),
                Text(
                  '× $_coins',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.amber),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'コイン1枚で1回引けます',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 32),
            if (!_isLoading)
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.7,
                child: ElevatedButton(
                  onPressed: _coins > 0 && !_isDrawing ? _drawGacha : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade600,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: _isDrawing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'ガチャを引く',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            if (_coins <= 0 && !_isLoading) ...[
              const SizedBox(height: 16),
              Text(
                'コインが足りません\nスポットに立ち寄ってコインを集めよう！',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
