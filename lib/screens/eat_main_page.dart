import 'package:flutter/material.dart';
import 'point_exchange_page.dart';
import 'recipe_list_page.dart';

class EatMainPage extends StatelessWidget {
  const EatMainPage({super.key});

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
                label: const Text('HOME', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildEatMenuButton(context, 'ポイント交換', Colors.green.shade600, const PointExchangePage()),
                    const SizedBox(height: 32),
                    _buildEatMenuButton(context, 'レシピを見る', Colors.amber.shade600, const RecipeVegetableListPage()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 固定幅460pxだと小さい画面でオーバーフローするため、
  // 画面幅の70%を使う形に変更（home_pageと統一）。
  Widget _buildEatMenuButton(BuildContext context, String label, Color color, Widget? targetPage) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.7;

    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        onPressed: () {
          if (targetPage != null) {
            Navigator.push(context, MaterialPageRoute(builder: (context) => targetPage));
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
        ),
        child: Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      ),
    );
  }
}