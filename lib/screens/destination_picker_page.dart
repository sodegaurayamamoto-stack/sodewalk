import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location.dart';
import '../services/location_picker_service.dart';
import '../services/storage_service.dart';

class DestinationPickerPage extends StatelessWidget {
  const DestinationPickerPage({super.key});

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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                '目標の歩数を選んでください',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                '目標歩数を達成できそうな場所を提案します',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildStepsButton(context, 5000),
                    const SizedBox(height: 24),
                    _buildStepsButton(context, 8000),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepsButton(BuildContext context, int steps) {
    final screenWidth = MediaQuery.of(context).size.width;
    final buttonWidth = screenWidth * 0.7;

    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => DestinationResultPage(targetSteps: steps)),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 26),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 4,
        ),
        child: Text('$steps 歩', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class DestinationResultPage extends StatefulWidget {
  final int targetSteps;
  const DestinationResultPage({super.key, required this.targetSteps});

  @override
  State<DestinationResultPage> createState() => _DestinationResultPageState();
}

class _DestinationResultPageState extends State<DestinationResultPage> {
  final StorageService _storage = StorageService();

  List<WalkLocation> _locations = [];
  double? _currentLat;
  double? _currentLng;
  DestinationResult? _result;
  bool _isLoading = true;
  String? _errorMessage;
  String? _lastLocationId;

  // 到着ボーナス関連
  double? _distanceToDestination;
  bool _arrivalBonusAlreadyTaken = false;
  bool _isCheckingArrival = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final locations = await LocationPickerService.loadLocations();
    final position = await LocationPickerService.getCurrentPosition();

    if (position == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = '現在地を取得できませんでした。位置情報の利用を許可してください。';
      });
      return;
    }

    _locations = locations;
    _currentLat = position.latitude;
    _currentLng = position.longitude;

    // 今日すでに到着ボーナスを取得済みか確認
    _arrivalBonusAlreadyTaken = await _storage.hasArrivalBonusToday();

    _pickNewDestination();
  }

  void _pickNewDestination() {
    if (_currentLat == null || _currentLng == null) return;
    final result = LocationPickerService.pickDestination(
      locations: _locations,
      currentLat: _currentLat!,
      currentLng: _currentLng!,
      targetSteps: widget.targetSteps,
      excludeLocationId: _lastLocationId,
    );
    setState(() {
      _result = result;
      _lastLocationId = result?.location.id;
      _distanceToDestination = result?.distanceMeters;
      _isLoading = false;
    });
  }

  Future<void> _openInMaps() async {
    final result = _result;
    if (result == null) return;
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${result.location.lat},${result.location.lng}',
    );
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _checkArrivalAndGiveBonus() async {
    final result = _result;
    if (result == null) return;

    setState(() => _isCheckingArrival = true);

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        result.location.lat,
        result.location.lng,
      );

      setState(() => _distanceToDestination = distance);

      if (distance <= 100) {
        // 100m以内なのでボーナス付与
        final newPoints = await _storage.giveArrivalBonus(result.location.id);
        setState(() {
          _arrivalBonusAlreadyTaken = true;
          _isCheckingArrival = false;
        });
        if (!mounted) return;
        _showArrivalBonusDialog(newPoints, result.location.id);
      } else {
        setState(() => _isCheckingArrival = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('まだ到着していません。あと${(distance - 100).toStringAsFixed(0)}m近づいてください'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() => _isCheckingArrival = false);
    }
  }

  void _showArrivalBonusDialog(int newPoints, String locationId) {
    final num = int.tryParse(locationId.replaceAll('l', '')) ?? 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('到着ボーナス！', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
            const SizedBox(height: 8),
            const Text('+5pt 獲得！', style: TextStyle(fontSize: 20, color: Colors.orange, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text('合計: $newPoints pt', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/gaura/gaura_${num.toString().padLeft(3, '0')}.png',
                    width: 60,
                    height: 60,
                  ),
                  const SizedBox(width: 12),
                  Text('No.${num.toString().padLeft(3, '0')} をゲット！',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('閉じる', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off, color: Colors.grey.shade400, size: 56),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _initialize,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('もう一度試す', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final result = _result;
    if (result == null) {
      return const Center(child: Text('目的地が見つかりませんでした'));
    }

    final distanceKm = (result.distanceMeters / 1000).toStringAsFixed(1);
    final isNearby = (_distanceToDestination ?? double.infinity) <= 100;
    final canGetBonus = isNearby && !_arrivalBonusAlreadyTaken;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.targetSteps}歩を目指せる目的地', style: const TextStyle(fontSize: 22, color: Colors.grey)),
          const SizedBox(height: 24),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _openInMaps,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.orange.shade300, width: 2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.location.categoryLabel, style: TextStyle(fontSize: 16, color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    result.location.name,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.straighten, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 6),
                      Text('約$distanceKm km', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 24),
                      Icon(Icons.explore, color: Colors.grey.shade600, size: 20),
                      const SizedBox(width: 6),
                      Text(result.directionLabel, style: const TextStyle(fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.map, color: Colors.orange.shade700, size: 18),
                      const SizedBox(width: 6),
                      Text('タップして地図でルートを見る', style: TextStyle(fontSize: 14, color: Colors.orange.shade700)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 到着ボーナスボタン
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (_arrivalBonusAlreadyTaken || _isCheckingArrival)
                  ? null
                  : _checkArrivalAndGiveBonus,
              icon: _isCheckingArrival
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Icon(_arrivalBonusAlreadyTaken ? Icons.check_circle : Icons.place),
              label: Text(
                _arrivalBonusAlreadyTaken ? '本日の到着ボーナス取得済み' : 'ここに到着！+5pt',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _arrivalBonusAlreadyTaken ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          if (_arrivalBonusAlreadyTaken)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('到着ボーナスは1日1カ所までです', style: TextStyle(fontSize: 12, color: Colors.grey.shade500), textAlign: TextAlign.center),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickNewDestination,
              icon: const Icon(Icons.refresh, color: Colors.orange),
              label: const Text('次の目的地', style: TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 18),
                side: const BorderSide(color: Colors.orange, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}