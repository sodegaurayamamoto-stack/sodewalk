/// 「目的地を決める」機能で使う、袖ケ浦市内の場所データ。
class WalkLocation {
  final String id;
  final String name;
  final String category;
  final double lat;
  final double lng;

  WalkLocation({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
  });

  factory WalkLocation.fromJson(Map<String, dynamic> json) {
    return WalkLocation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lng: (json['lng'] ?? 0).toDouble(),
    );
  }

  /// カテゴリーIDを日本語の表示名に変換する
  String get categoryLabel {
    switch (category) {
      case 'dining':
        return '飲食店';
      case 'shopping':
        return 'ショッピング';
      case 'leisure':
        return '遊び';
      case 'rest':
        return '休憩スポット';
      case 'public':
        return '公共施設';
      case 'life':
        return '生活';
      default:
        return 'その他';
    }
  }
}