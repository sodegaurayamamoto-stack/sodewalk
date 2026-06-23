import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';

class GauraCollectionPage extends StatefulWidget {
  const GauraCollectionPage({super.key});

  @override
  State<GauraCollectionPage> createState() => _GauraCollectionPageState();
}

class _GauraCollectionPageState extends State<GauraCollectionPage> {
  final StorageService _storage = StorageService();
  Set<String> _collectedIds = {};
  List<Map<String, dynamic>> _locations = [];
  bool _isLoading = true;
  Map<String, String> _gauraImageMap = {}; // id → ファイル名

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final collected = await _storage.getCollectedGaura();
    final jsonString = await rootBundle.loadString('assets/locations.json');
    final data = json.decode(jsonString);
    final locations = (data['locations'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    // assets/gaura/配下の画像を読み込んでidとマッピング
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);
    final gauraFiles = manifestMap.keys
        .where((path) => path.startsWith('assets/gaura/') && path.endsWith('.png'))
        .toList();

    final imageMap = <String, String>{};
    for (final path in gauraFiles) {
      final filename = path.split('/').last; // 例: 0001_ガウラ_サッカー.png
      final id = filename.split('_').first; // 例: 0001
      imageMap[id] = path;
    }

    setState(() {
      _collectedIds = collected;
      _locations = locations;
      _gauraImageMap = imageMap;
      _isLoading = false;
    });
  }

  // ファイル名からキャラ名とアクションを取得
  // 例: 0001_ガウラ_サッカー.png → 「ガウラ（サッカー）」
  String _getGauraName(String id) {
    final path = _gauraImageMap[id];
    if (path == null) return '';
    final filename = path.split('/').last.replaceAll('.png', '');
    final parts = filename.split('_');
    if (parts.length >= 3) {
      return '${parts[1]}（${parts[2]}）';
    } else if (parts.length == 2) {
      return parts[1];
    }
    return '';
  }

  void _showDetail(String id, bool collected) {
    final gauraName = _getGauraName(id);
    final imagePath = _gauraImageMap[id];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (collected && imagePath != null)
              Image.asset(imagePath, width: 120, height: 120)
            else
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text('?', style: TextStyle(fontSize: 60, color: Colors.grey.shade400, fontWeight: FontWeight.bold)),
                ),
              ),
            const SizedBox(height: 16),
            Text('No.$id', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            if (gauraName.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(gauraName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
            const SizedBox(height: 8),
            Text(
              collected ? 'ゲット済み！' : 'まだ出会っていません',
              style: TextStyle(fontSize: 16, color: collected ? Colors.orange : Colors.grey, fontWeight: FontWeight.bold),
            ),
            if (!collected) ...[
              const SizedBox(height: 8),
              Text(
                'お店や施設を回って\nガウラくんを探してみよう！',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center,
              ),
            ],
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
                  const Spacer(),
                  if (!_isLoading)
                    Text('${_collectedIds.length} / ${_locations.length}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('ガウラ図鑑', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('目的地に到着するとゲット！', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: _locations.length,
                      itemBuilder: (context, index) {
                        final location = _locations[index];
                        final id = location['id'] as String;
                        final collected = _collectedIds.contains(id);
                        final imagePath = _gauraImageMap[id];
                        final gauraName = _getGauraName(id);

                        return GestureDetector(
                          onTap: () => _showDetail(id, collected),
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: collected ? Colors.orange.shade50 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: collected ? Colors.orange.shade300 : Colors.grey.shade300,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: collected && imagePath != null
                                        ? Image.asset(imagePath, fit: BoxFit.contain)
                                        : Text('?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'No.$id',
                                style: TextStyle(fontSize: 9, color: collected ? Colors.orange.shade700 : Colors.grey.shade500, fontWeight: FontWeight.bold),
                              ),
                              if (gauraName.isNotEmpty)
                                Text(
                                  gauraName,
                                  style: TextStyle(fontSize: 8, color: collected ? Colors.orange.shade600 : Colors.grey.shade400),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
