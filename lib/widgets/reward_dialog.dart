import 'package:flutter/material.dart';

/// 前日の歩数達成によりポイントを獲得した際に表示するダイアログ。
class RewardDialog extends StatelessWidget {
  final int steps;
  final int points;

  const RewardDialog({
    super.key,
    required this.steps,
    required this.points,
  });

  /// ダイアログを表示するヘルパー
  static Future<void> show(
    BuildContext context, {
    required int steps,
    required int points,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RewardDialog(steps: steps, points: points),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth * 0.8;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      content: SizedBox(
        width: dialogWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'おめでとうございます！',
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.bold, color: Colors.orange),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 24),
            Text(
              '昨日の歩数: $steps 歩',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(15)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$points pt',
                    style: const TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const Text(
                    '獲得！',
                    style: TextStyle(
                        fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: const Text(
                  '確認しました',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}