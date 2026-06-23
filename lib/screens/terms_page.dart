import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  Future<void> _agree(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('terms_agreed', true);
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text(
                'そでウォーク\n利用規約',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'ご利用前に以下の利用規約をお読みください。',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      _TermsSection(
                        title: '第1条（アプリの目的）',
                        content:
                            '本アプリは、袖ケ浦市内のウォーキングを促進することを目的とした非公式・有志開発のアプリです。袖ケ浦市および関連機関とは独立した個人開発物です。',
                      ),
                      _TermsSection(
                        title: '第2条（ポイントについて）',
                        content:
                            '歩数に応じて付与されるポイントは、サービスの都合により予告なく変更・消滅する場合があります。ポイントに金銭的価値はなく、換金はできません。',
                      ),
                      _TermsSection(
                        title: '第3条（個人情報の取り扱い）',
                        content:
                            '野菜交換時に入力いただく氏名・住所・電話番号は、商品の受け渡し目的のみに使用します。第三者への提供や他の目的への利用は行いません。',
                      ),
                      _TermsSection(
                        title: '第4条（免責事項）',
                        content:
                            '本アプリの利用により生じたいかなる損害についても、開発者は責任を負いません。また、歩行中の事故・怪我等についても自己責任でご利用ください。',
                      ),
                      _TermsSection(
                        title: '第5条（サービスの変更・終了）',
                        content:
                            'サービスの内容は予告なく変更・終了する場合があります。あらかじめご了承ください。',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _agree(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    '同意してはじめる',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
