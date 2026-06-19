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
        return '飲食店・カフェ';
      case 'shopping':
        return 'ショッピング';
      case 'leisure':
        return 'レジャー・農園';
      case 'rest':
        return '公園・休憩スポット';
      case 'transit':
        return '駅・バス停';
      case 'public':
        return '公共施設';
      case 'finance':
        return '銀行・郵便局';
      case 'medical':
        return '医療・健康';
      case 'shrine':
        return '神社・お寺';
      case 'beauty':
        return '美容・理髪';
      default:
        return 'その他';
    }
  }
}