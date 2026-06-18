class Vegetable {
  final String id;
  final String name;
  final int points;

  Vegetable({
    required this.id,
    required this.name,
    required this.points,
  });

  factory Vegetable.fromJson(Map<String, dynamic> json) {
    return Vegetable(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      points: json['points'] ?? 0,
    );
  }
}