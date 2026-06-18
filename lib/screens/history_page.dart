import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final StorageService _storage = StorageService();

  late int _displayYear;
  late int _displayMonth;
  Map<String, int> _monthlyStepsData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayYear = now.year;
    _displayMonth = now.month;
    _loadMonthData();
  }

  Future<void> _loadMonthData() async {
    setState(() => _isLoading = true);
    final data = await _storage.getMonthSteps(_displayYear, _displayMonth);
    setState(() {
      _monthlyStepsData = data;
      _isLoading = false;
    });
  }

  void _changeMonth(int direction) {
    setState(() {
      _displayMonth += direction;
      if (_displayMonth > 12) {
        _displayMonth = 1;
        _displayYear++;
      } else if (_displayMonth < 1) {
        _displayMonth = 12;
        _displayYear--;
      }
    });
    _loadMonthData();
  }

  int _getFirstDayOffset(int year, int month) {
    return DateTime(year, month, 1).weekday % 7;
  }

  int _getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final List<String> weekdays = ['日', '月', '火', '水', '木', '金', '土'];
    final int totalDays = _getDaysInMonth(_displayYear, _displayMonth);
    final int startOffset = _getFirstDayOffset(_displayYear, _displayMonth);
    final int totalGridItems = totalDays + startOffset;

    final screenWidth = MediaQuery.of(context).size.width;
    final usableWidth = screenWidth - 32 - 60;
    final cellWidth = usableWidth / 7;
    final dayFontSize = (cellWidth * 0.42).clamp(16.0, 54.0);
    final stepsFontSize = (cellWidth * 0.34).clamp(11.0, 44.0);
    final achievedBadgeFontSize = (cellWidth * 0.20).clamp(10.0, 22.0);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 70,
        leadingWidth: 160,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0),
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, color: Colors.black, size: 36),
                SizedBox(width: 8),
                Text('戻る', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () => _changeMonth(-1),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blueGrey, width: 3.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('＜ 前月', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                  Text(
                    '$_displayYear年 $_displayMonth月',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  OutlinedButton(
                    onPressed: () => _changeMonth(1),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blueGrey, width: 3.0),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('次月 ＞', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: weekdays.map((day) {
                  Color textColor = Colors.grey.shade700;
                  if (day == '土') textColor = Colors.blue.shade700;
                  if (day == '日') textColor = Colors.red.shade700;
                  return Expanded(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 16, thickness: 2.0),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: totalGridItems,
                        itemBuilder: (context, index) {
                          if (index < startOffset) {
                            return const SizedBox.shrink();
                          }

                          int day = index - startOffset + 1;
                          int steps = _monthlyStepsData[day.toString()] ?? 0;
                          bool isAchieved = steps >= 5001;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 3.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: steps >= 8001
                                  ? Colors.green.shade50
                                  : (steps >= 5001 ? Colors.orange.shade50 : Colors.grey.shade50),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: steps >= 8001
                                    ? Colors.green.shade600
                                    : (steps >= 5001 ? Colors.orange.shade600 : Colors.grey.shade300),
                                width: isAchieved ? 2.0 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$day',
                                      style: TextStyle(
                                        fontSize: dayFontSize,
                                        fontWeight: FontWeight.w900,
                                        color: steps >= 8001
                                            ? Colors.green.shade900
                                            : (steps >= 5001 ? Colors.orange.shade900 : Colors.black87),
                                        height: 0.9,
                                      ),
                                    ),
                                    if (isAchieved)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: steps >= 8001 ? Colors.green.shade600 : Colors.orange.shade600,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          steps >= 8001 ? '◎' : '〇',
                                          style: TextStyle(fontSize: achievedBadgeFontSize, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.only(bottom: 2.0),
                                        child: Text(
                                          '$steps',
                                          style: TextStyle(
                                            fontSize: stepsFontSize,
                                            fontWeight: FontWeight.w900,
                                            color: steps >= 8001
                                                ? Colors.green.shade800
                                                : (steps >= 5001 ? Colors.orange.shade800 : Colors.grey.shade800),
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            border: Border.all(color: Colors.orange.shade600, width: 2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('5001〜8000歩：〇（5ポイント獲得）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            border: Border.all(color: Colors.green.shade600, width: 2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('8001歩以上：◎（10ポイント獲得）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}