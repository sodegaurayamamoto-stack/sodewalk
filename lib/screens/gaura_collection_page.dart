import 'dart:convert';
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
  int _totalCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final collected = await _storage.getCollectedGaura();
    final jsonString = await rootBundle.loadString('assets/locations.json');
    final data = json.decode(jsonString);
    final total = (data['locations'] as List).length;
    setState(() {
      _collectedIds = collected;
      _totalCount = total;
      _isLoading = false;
    });
  }

  void _showDetail(int num, bool collected) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (collected)
              Image.asset(
                'assets/gaura/gaura_${num.toString().padLeft(3, '0')}.png',
                width: 120,
                height: 120,
              )
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
            Text('No.${num.toString().padLeft(3, '0')}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    Text('${_collectedIds.length} / $_totalCount', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
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
                        childAspectRatio: 0.85,
                      ),
                      itemCount: _totalCount,
                      itemBuilder: (context, index) {
                        final num = index + 1;
                        final locationId = 'l${num.toString().padLeft(3, '0')}';
                        final collected = _collectedIds.contains(locationId);
                        return GestureDetector(
                          onTap: () => _showDetail(num, collected),
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
                                    child: collected
                                        ? Image.asset('assets/gaura/gaura_${num.toString().padLeft(3, '0')}.png', fit: BoxFit.contain)
                                        : Text('?', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.grey.shade400)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'No.${num.toString().padLeft(3, '0')}',
                                style: TextStyle(fontSize: 9, color: collected ? Colors.orange.shade700 : Colors.grey.shade500, fontWeight: FontWeight.bold),
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
