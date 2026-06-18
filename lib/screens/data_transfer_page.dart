import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/backup_service.dart';

/// データ引き継ぎ画面。
///
/// 「このデータを渡す」（QRコード表示）と
/// 「他端末のデータを受け取る」（QRコードスキャン）の
/// 2つの機能を1画面にまとめている。
class DataTransferPage extends StatefulWidget {
  const DataTransferPage({super.key});

  @override
  State<DataTransferPage> createState() => _DataTransferPageState();
}

class _DataTransferPageState extends State<DataTransferPage> {
  final BackupService _backup = BackupService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'データ引き継ぎ設定',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildMenuButton(
              context,
              icon: Icons.qr_code_2,
              label: 'このデータを渡す（QR表示）',
              color: Colors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ShowQrPage(backup: _backup)),
              ),
            ),
            const SizedBox(height: 24),
            _buildMenuButton(
              context,
              icon: Icons.qr_code_scanner,
              label: '他端末のデータを受け取る（QR読み取り）',
              color: Colors.blueGrey,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ScanQrPage(backup: _backup)),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                '「データを渡す」では、現在のポイントと歩数履歴をQRコードに変換して表示します。\n\n「データを受け取る」では、別の端末に表示されたQRコードを読み取り、現在のデータを上書きします（上書きされたデータは元に戻せません）。',
                style: TextStyle(fontSize: 15, height: 1.6, color: Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// QRコードを表示する画面（データを「渡す」側）。
class ShowQrPage extends StatefulWidget {
  final BackupService backup;
  const ShowQrPage({super.key, required this.backup});

  @override
  State<ShowQrPage> createState() => _ShowQrPageState();
}

class _ShowQrPageState extends State<ShowQrPage> {
  String? _exportedData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await widget.backup.exportData();
    setState(() {
      _exportedData = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('このデータを渡す', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text(
                    '別の端末でこのQRコードを読み取ってください',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.orange, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: _exportedData ?? '',
                      version: QrVersions.auto,
                      size: 260,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('読み取れない場合はこちらのコードを貼り付けてください', style: TextStyle(fontSize: 14, color: Colors.black54)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SelectableText(
                      _exportedData ?? '',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// QRコードを読み取る画面（データを「受け取る」側）。
class ScanQrPage extends StatefulWidget {
  final BackupService backup;
  const ScanQrPage({super.key, required this.backup});

  @override
  State<ScanQrPage> createState() => _ScanQrPageState();
}

class _ScanQrPageState extends State<ScanQrPage> {
  bool _isProcessing = false;
  final TextEditingController _manualController = TextEditingController();

  Future<void> _handleScanned(String rawValue) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    final confirmed = await _showOverwriteConfirmDialog();
    if (confirmed != true) {
      setState(() => _isProcessing = false);
      return;
    }

    final success = await widget.backup.importData(rawValue);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データを引き継ぎました！', style: TextStyle(fontSize: 16)), backgroundColor: Colors.green),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('読み取ったデータの形式が正しくありません', style: TextStyle(fontSize: 16)), backgroundColor: Colors.redAccent),
      );
      setState(() => _isProcessing = false);
    }
  }

  Future<bool?> _showOverwriteConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('確認', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        content: const Text(
          'この端末の現在のポイント・歩数データは上書きされます。元に戻すことはできません。続けますか？',
          style: TextStyle(fontSize: 16, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: const Text('上書きする', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 32),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('QRコードを読み取る', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isProcessing
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : MobileScanner(
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final value = barcodes.first.rawValue;
                        if (value != null) {
                          _handleScanned(value);
                        }
                      }
                    },
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('読み取れない場合はコードを貼り付け', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_manualController.text.isNotEmpty) {
                        _handleScanned(_manualController.text);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    child: const Text('このコードで読み込む', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
