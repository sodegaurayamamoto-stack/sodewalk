class Vegetable {
  final String id;
  final String name;
  final int points;
  final bool active;
  final String provider;

  Vegetable({
    required this.id,
    required this.name,
    required this.points,
    required this.active,
    required this.provider,
  });

  factory Vegetable.fromJson(Map<String, dynamic> json) {
    return Vegetable(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      points: json['points'] ?? 0,
      active: json['active'] ?? false,
      provider: json['provider'] ?? '',
    );
  }
}
