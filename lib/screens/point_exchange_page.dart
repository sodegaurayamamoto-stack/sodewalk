import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../models/vegetable.dart';
import '../services/storage_service.dart';
import 'order_form_page.dart';

class PointExchangePage extends StatefulWidget {
  const PointExchangePage({super.key});

  @override
  State<PointExchangePage> createState() => _PointExchangePageState();
}

class _PointExchangePageState extends State<PointExchangePage> {
  final StorageService _storage = StorageService();

  List<Vegetable> _vegetables = [];
  bool _isLoading = true;
  bool _isVersionOk = true;

  @override
  void initState() {
    super.initState();
    _loadVegetableData();
  }

  Future<void> _loadVegetableData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/vegetables.json');
      final data = json.decode(jsonString);

      final latestVersion = data['latest_version'] as String? ?? '1.0.0';
      const currentVersion = '1.0.0';
      final isVersionOk = _compareVersion(currentVersion, latestVersion);

      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => Vegetable.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _vegetables = items;
        _isVersionOk = isVersionOk;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _vegetables = [];
        _isLoading = false;
      });
    }
  }

  bool _compareVersion(String current, String latest) {
    final c = current.split('.').map(int.parse).toList();
    final l = latest.split('.').map(int.parse).toList();
    for (int i = 0; i < 3; i++) {
      final cv = i < c.length ? c[i] : 0;
      final lv = i < l.length ? l[i] : 0;
      if (cv > lv) return true;
      if (cv < lv) return false;
    }
    return true;
  }

  void _openGooglePlay() async {
    final url = Uri.parse('https://play.google.com/store/apps/details?id=com.sodewalk.app');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.blueGrey, size: 28),
                label: const Text('戻る', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : !_isVersionOk
                      ? _buildUpdateRequired()
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                itemCount: _vegetables.length,
                                itemBuilder: (context, index) {
                                  final item = _vegetables[index];
                                  return _buildVegetableCard(context, item);
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Text(
                                '※野菜は袖ケ浦市内の農家さんから\n規格外品を提供いただいております',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.5),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateRequired() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.system_update, size: 80, color: Colors.orange.shade300),
            const SizedBox(height: 24),
            const Text(
              'アップデートが必要です',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '最新バージョンのアプリでのみ\nポイント交換ができます。\nGoogle Playからアップデートしてください。',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _openGooglePlay,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Google Playを開く', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVegetableCard(BuildContext context, Vegetable item) {
    final isActive = item.active;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? Colors.grey.shade300 : Colors.grey.shade200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.grey.shade100, blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: isActive ? Colors.black87 : Colors.grey.shade400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${item.points} pt',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isActive ? Colors.orange : Colors.grey.shade400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '提供：${item.provider}',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isActive
                  ? () async {
                      final currentPoints = await _storage.getPoints();
                      if (!mounted) return;
                      if (currentPoints >= item.points) {
                        _showLocationConfirmDialog(context, item.name, item.points);
                      } else {
                        _showShortageDialog(context, item.points - currentPoints);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade200,
                disabledForegroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                isActive ? '交換する' : '現在取り扱いなし',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationConfirmDialog(BuildContext context, String name, int points) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.8;
    bool isChecked = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('確認', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: dialogWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '交換した商品の受け渡しは\n袖ケ浦市内に限ります。',
                      style: TextStyle(fontSize: 16, height: 1.4, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'お名前・ご住所・電話番号に誤りがある場合、商品をお渡しできない可能性がありますので、次の画面で入力内容をご確認ください。',
                      style: TextStyle(fontSize: 14, height: 1.4, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: isChecked,
                          activeColor: Colors.orange,
                          onChanged: (value) {
                            setDialogState(() => isChecked = value ?? false);
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() => isChecked = !isChecked);
                            },
                            child: const Text(
                              '規格外品であることを理解しました',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('キャンセル', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: isChecked
                      ? () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => OrderFormPage(itemName: name, itemPoints: points)),
                          );
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade400,
                  ),
                  child: const Text('進む', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showShortageDialog(BuildContext context, int lack) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.8;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: SizedBox(
          width: dialogWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('ポイントが足りません', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              const SizedBox(height: 16),
              Text('交換するにはあと $lack pt 必要です。\nたくさん歩いてポイントを貯めましょう！', style: const TextStyle(fontSize: 16, height: 1.4), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, foregroundColor: Colors.white),
                child: const Text('閉じる', style: TextStyle(fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
