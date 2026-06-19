import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart';

class DestinationResult {
  final WalkLocation location;
  final double distanceMeters;
  final String directionLabel;

  DestinationResult({
    required this.location,
    required this.distanceMeters,
    required this.directionLabel,
  });
}

class LocationPickerService {
  static const double stepLengthMeters = 0.5;

  static Future<List<WalkLocation>> loadLocations() async {
    final jsonString = await rootBundle.loadString('assets/locations.json');
    final data = json.decode(jsonString);
    return (data['locations'] as List<dynamic>? ?? [])
        .map((e) => WalkLocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
    } catch (e) {
      return null;
    }
  }

  static double targetOneWayDistance(int targetSteps) {
    final totalDistance = targetSteps * stepLengthMeters;
    return totalDistance / 2;
  }

  static DestinationResult? pickDestination({
    required List<WalkLocation> locations,
    required double currentLat,
    required double currentLng,
    required int targetSteps,
    String? excludeLocationId, // 直前に選ばれた目的地のIDを除外
  }) {
    if (locations.isEmpty) return null;

    final targetDistance = targetOneWayDistance(targetSteps);
    final minDistance = targetDistance;
    final maxDistance = targetDistance * 1.3;
    final lowerBound = targetDistance - 800;
    final upperBound = targetDistance * 1.3 + 800;

    final allScored = locations
        .where((loc) => loc.id != excludeLocationId) // 直前と同じ場所を除外
        .map((loc) {
      final distance = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        loc.lat,
        loc.lng,
      );
      final diff = (distance - targetDistance).abs();
      return _ScoredLocation(location: loc, distance: distance, diff: diff);
    }).toList();

    if (allScored.isEmpty) return null;

    final pool = allScored.where((s) =>
      s.distance >= lowerBound &&
      s.distance <= upperBound &&
      s.distance >= minDistance &&
      s.distance <= maxDistance
    ).toList();

    _ScoredLocation chosen;
    if (pool.isNotEmpty) {
      pool.shuffle(Random());
      chosen = pool.first;
    } else {
      allScored.sort((a, b) => a.diff.compareTo(b.diff));
      chosen = allScored.first;
    }

    final bearing = Geolocator.bearingBetween(
      currentLat,
      currentLng,
      chosen.location.lat,
      chosen.location.lng,
    );

    return DestinationResult(
      location: chosen.location,
      distanceMeters: chosen.distance,
      directionLabel: _bearingToLabel(bearing),
    );
  }

  static String _bearingToLabel(double bearing) {
    final normalized = (bearing + 360) % 360;
    const labels = ['北', '北東', '東', '南東', '南', '南西', '西', '北西'];
    final index = ((normalized + 22.5) / 45).floor() % 8;
    return labels[index];
  }
}

class _ScoredLocation {
  final WalkLocation location;
  final double distance;
  final double diff;

  _ScoredLocation({
    required this.location,
    required this.distance,
    required this.diff,
  });
}