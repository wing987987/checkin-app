class CheckinProject {
  final int id;
  final String name;
  final double gpsLat;
  final double gpsLng;
  final int fenceRadius;
  final String status;

  const CheckinProject({required this.id, required this.name, required this.gpsLat,
    required this.gpsLng, required this.fenceRadius, required this.status});

  factory CheckinProject.fromJson(Map<String, dynamic> json) => CheckinProject(
    id: json['id'] as int,
    name: json['name'] as String? ?? '',
    gpsLat: (json['gpsLat'] as num).toDouble(),
    gpsLng: (json['gpsLng'] as num).toDouble(),
    fenceRadius: json['fenceRadius'] as int? ?? 100,
    status: json['status'] as String? ?? 'active',
  );
}
