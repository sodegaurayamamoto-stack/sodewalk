import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location.dart';
import '../services/location_picker_service.dart';

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
  List<WalkLocation> _locations = [];
  double? _currentLat;
  double? _currentLng;
  DestinationResult? _result;
  bool _isLoading = true;
  String? _errorMessage;
  String? _lastLocationId;

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
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickNewDestination,
              icon: const Icon(Icons.refresh, color: Colors.orange),
              label: const Text('別の目的地', style: TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold)),
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