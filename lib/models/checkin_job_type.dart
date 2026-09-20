class CheckinJobType {
  final int id;
  final String name;

  const CheckinJobType({required this.id, required this.name});

  factory CheckinJobType.fromJson(Map<String, dynamic> json) => CheckinJobType(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
      );
}
