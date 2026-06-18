import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../services/storage_service.dart';
import '../services/google_sheets_service.dart';

class OrderFormPage extends StatefulWidget {
  final String itemName;
  final int itemPoints;

  const OrderFormPage({super.key, required this.itemName, required this.itemPoints});

  @override
  State<OrderFormPage> createState() => _OrderFormPageState();
}

class _OrderFormPageState extends State<OrderFormPage> {
  final StorageService _storage = StorageService();
  final GoogleSheetsService _sheets = GoogleSheetsService();

  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  String? _selectedDate;
  List<String> _availableSaturdays = [];
  bool _isLoadingDates = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _calculateAvailableSaturdays();
  }

  Future<void> _calculateAvailableSaturdays() async {
    List<String> disabledDates = [];
    try {
      final jsonString = await rootBundle.loadString('assets/vegetables.json');
      final data = json.decode(jsonString);
      if (data['disabled_saturdays'] != null) {
        disabledDates = List<String>.from(data['disabled_saturdays']);
      }
    } catch (_) {}

    List<String> computedSaturdays = [];
    DateTime targetDate = DateTime.now();

    while (computedSaturdays.length < 4) {
      if (targetDate.weekday == DateTime.saturday) {
        final dateString =
            "${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}";

        if (!disabledDates.contains(dateString)) {
          computedSaturdays.add("${targetDate.year}年${targetDate.month}月${targetDate.day}日（土）");
        }
      }
      targetDate = targetDate.add(const Duration(days: 1));
    }

    setState(() {
      _availableSaturdays = computedSaturdays;
      if (_availableSaturdays.isNotEmpty) {
        _selectedDate = _availableSaturdays.first;
      }
      _isLoadingDates = false;
    });
  }

  Future<void> _submitOrder() async {
    if (_nameController.text.isEmpty ||
        _addressController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すべての項目を入力してください', style: TextStyle(fontSize: 18)), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = await _sheets.submitOrder(
      name: _nameController.text,
      address: _addressController.text,
      phone: _phoneController.text,
      itemName: widget.itemName,
      itemPoints: widget.itemPoints,
      preferredDate: _selectedDate!,
    );

    if (!mounted) return;

    if (success) {
      await _storage.subtractPoints(widget.itemPoints);
      if (!mounted) return;
      _showSuccessDialog();
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('送信に失敗しました。通信環境をご確認のうえ、もう一度お試しください。', style: TextStyle(fontSize: 16)), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        content: Container(
          constraints: const BoxConstraints(minWidth: 460, maxWidth: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 72),
              const SizedBox(height: 16),
              const Text('交換の申請が完了しました', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
              const SizedBox(height: 20),
              const Text(
                '担当者が内容を確認し、受け渡し準備を進めます。お受け渡し日に商品をお渡しいたします。',
                style: TextStyle(fontSize: 18, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: const Text('ホームへ戻る', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
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
              child: _isLoadingDates
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInputFieldLabel('👤 お名前'),
                          _buildTextField(_nameController, '例：山田 太郎', TextInputType.text),
                          _buildInputFieldLabel('📍 ご住所'),
                          _buildTextField(_addressController, '例：袖ケ浦市坂戸市場', TextInputType.text),
                          _buildInputFieldLabel('📞 電話番号'),
                          _buildTextField(_phoneController, '例：09012345678', TextInputType.phone),
                          _buildInputFieldLabel('📅 受け渡し希望日'),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300, width: 2),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedDate,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 36),
                                style: const TextStyle(fontSize: 22, color: Colors.black87, fontWeight: FontWeight.bold),
                                onChanged: (newValue) => setState(() => _selectedDate = newValue),
                                items: _availableSaturdays
                                    .map((value) => DropdownMenuItem<String>(value: value, child: Text(value)))
                                    .toList(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 50),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSubmitting ? null : _submitOrder,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 22),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Text('交換を確定する', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 24),
      child: Text(label, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade300, width: 2)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Colors.orange, width: 2.5)),
      ),
    );
  }
}
