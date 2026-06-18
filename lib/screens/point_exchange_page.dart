import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
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

  @override
  void initState() {
    super.initState();
    _loadVegetableData();
  }

  Future<void> _loadVegetableData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/vegetables.json');
      final data = json.decode(jsonString);
      final items = (data['items'] as List<dynamic>? ?? [])
          .map((item) => Vegetable.fromJson(item as Map<String, dynamic>))
          .toList();
      setState(() {
        _vegetables = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _vegetables = [Vegetable(id: 'daikon', name: '大根', points: 100)];
        _isLoading = false;
      });
    }
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
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _vegetables.length,
                      itemBuilder: (context, index) {
                        final item = _vegetables[index];
                        return _buildVegetableCard(context, item.name, item.points);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVegetableCard(BuildContext context, String name, int requiredPoints) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 2),
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
                  name,
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 12),
              Text('$requiredPoints pt', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final currentPoints = await _storage.getPoints();

                if (currentPoints >= requiredPoints) {
                  if (!mounted) return;
                  _showLocationConfirmDialog(context, name, requiredPoints);
                } else {
                  if (!mounted) return;
                  _showShortageDialog(requiredPoints - currentPoints);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('交換する', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLocationConfirmDialog(BuildContext context, String name, int points) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.8;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('確認', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: dialogWidth,
            child: const Text(
              '交換した商品の受け渡しは袖ケ浦市内に限ります。',
              style: TextStyle(fontSize: 16, height: 1.4, color: Colors.black87),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OrderFormPage(itemName: name, itemPoints: points)),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              child: const Text('進む', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showShortageDialog(int lack) {
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