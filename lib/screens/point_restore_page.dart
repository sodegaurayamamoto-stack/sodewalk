import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';

class PointRestorePage extends StatefulWidget {
 const PointRestorePage({super.key});

 @override
 State<PointRestorePage> createState() => _PointRestorePageState();
}

class _PointRestorePageState extends State<PointRestorePage> {
 final StorageService _storage = StorageService();
 final TextEditingController _codeController = TextEditingController();
 bool _isLoading = false;

 static const String _gasUrl = 'https://script.google.com/macros/s/AKfycbyrGbHHe6_bpEstTqpatzaD-0aAdLVqgecESBTFWopkVkrRJoNEpgDj8AOXwgDPpPOn/exec';

 Future<void> _checkCode() async {
   final code = _codeController.text.trim();
   if (code.isEmpty) return;

   setState(() => _isLoading = true);

   try {
     final uri = Uri.parse('$_gasUrl?action=checkRestoreCode&code=$code');
     final response = await http.get(uri);
     final data = json.decode(response.body);

     if (!mounted) return;

     if (data['result'] == 'success') {
       final points = data['points'] as int;
       await _storage.addPoints(points);
       _showResultDialog('✅ 復元完了', '$points pt が追加されました！', Colors.green);
     } else if (data['result'] == 'used') {
       _showResultDialog('⚠️ 使用済み', 'このコードはすでに使用されています。', Colors.orange);
     } else {
       _showResultDialog('❌ 無効なコード', 'コードが正しくありません。\n管理人にお問い合わせください。', Colors.red);
     }
   } catch (e) {
     if (!mounted) return;
     _showResultDialog('エラー', '通信に失敗しました。\nインターネット接続を確認してください。', Colors.red);
   } finally {
     setState(() => _isLoading = false);
   }
 }

 void _showResultDialog(String title, String message, Color color) {
   showDialog(
     context: context,
     builder: (context) => AlertDialog(
       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
       title: Text(title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
       content: Text(message, style: const TextStyle(fontSize: 16, height: 1.5)),
       actions: [
         ElevatedButton(
           onPressed: () {
             Navigator.pop(context);
             if (title.contains('完了')) Navigator.pop(context);
           },
           style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
           child: const Text('閉じる', style: TextStyle(fontSize: 16)),
         ),
       ],
     ),
   );
 }

 @override
 void dispose() {
   _codeController.dispose();
   super.dispose();
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
             TextButton.icon(
               onPressed: () => Navigator.pop(context),
               icon: const Icon(Icons.arrow_back, color: Colors.blueGrey, size: 28),
               label: const Text('戻る', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
             ),
             const SizedBox(height: 24),
             const Text(
               'ポイント復元',
               style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
             ),
             const SizedBox(height: 8),
             Text(
               '管理人から受け取ったコードを\n入力してください。',
               style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.5),
             ),
             const SizedBox(height: 40),
             TextField(
               controller: _codeController,
               keyboardType: TextInputType.number,
               maxLength: 6,
               textAlign: TextAlign.center,
               style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 8),
               decoration: InputDecoration(
                 hintText: '000000',
                 hintStyle: TextStyle(color: Colors.grey.shade300, fontSize: 32, letterSpacing: 8),
                 counterText: '',
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(16),
                   borderSide: const BorderSide(color: Colors.orange, width: 2),
                 ),
               ),
             ),
             const SizedBox(height: 32),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: _isLoading ? null : _checkCode,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: Colors.orange,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(vertical: 18),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                 ),
                 child: _isLoading
                     ? const CircularProgressIndicator(color: Colors.white)
                     : const Text('確認する', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               ),
             ),
           ],
         ),
       ),
     ),
   );
 }
}
