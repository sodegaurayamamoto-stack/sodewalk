import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../models/location.dart';

/// 選ばれた目的地と、現在地からの距離・方位をまとめた結果
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
  /// 平均的な1歩の歩幅（メートル）
  static const double stepLengthMeters = 0.5;

  /// assets/locations.json から場所一覧を読み込む
  static Future<List<WalkLocation>> loadLocations() async {
    final jsonString = await rootBundle.loadString('assets/locations.json');
    final data = json.decode(jsonString);
    return (data['locations'] as List<dynamic>? ?? [])
        .map((e) => WalkLocation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 現在地を取得する。位置情報の権限がない場合は要求し、
  /// 取得できない場合は null を返す。
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

  /// 目標歩数から、片道の目標距離（メートル）を計算する。
  /// 往復で目標歩数になるよう、片道は半分の距離。
  static double targetOneWayDistance(int targetSteps) {
    final totalDistance = targetSteps * stepLengthMeters;
    return totalDistance / 2;
  }

  /// 現在地から各候補地までの距離を計算し、目標の片道距離の
  /// 1.0〜1.3倍かつ±500m以内の候補からランダムに選ぶ。
  /// 候補が0件の場合は目標距離に最も近い場所を返す。
  static DestinationResult? pickDestination({
    required List<WalkLocation> locations,
    required double currentLat,
    required double currentLng,
    required int targetSteps,
  }) {
    if (locations.isEmpty) return null;

    final targetDistance = targetOneWayDistance(targetSteps);
    // 目標距離の1.0〜1.3倍の範囲（少し超えるくらいを狙う）
    final minDistance = targetDistance;
    final maxDistance = targetDistance * 1.3;
    // さらに±500mのレンジに絞る
    final lowerBound = targetDistance - 500;
    final upperBound = targetDistance * 1.3 + 500;

    final allScored = locations.map((loc) {
      final distance = Geolocator.distanceBetween(
        currentLat,
        currentLng,
        loc.lat,
        loc.lng,
      );
      final diff = (distance - targetDistance).abs();
      return _ScoredLocation(location: loc, distance: distance, diff: diff);
    }).toList();

    // 目標レンジ内の候補を絞る
    final pool = allScored.where((s) =>
      s.distance >= lowerBound &&
      s.distance <= upperBound &&
      s.distance >= minDistance &&
      s.distance <= maxDistance
    ).toList();

    _ScoredLocation chosen;
    if (pool.isNotEmpty) {
      // レンジ内からランダムに選ぶ
      pool.shuffle(Random());
      chosen = pool.first;
    } else {
      // 候補なしの場合は目標距離に最も近い場所にフォールバック
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

  /// 方位角（-180〜180度）を「北東」のような8方位の日本語表現に変換する
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