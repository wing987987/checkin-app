class CheckinTeam {
  final int id;
  final int projectId;
  final String name;
  final int status;
  const CheckinTeam({required this.id, required this.projectId, required this.name, required this.status});
  factory CheckinTeam.fromJson(Map<String, dynamic> json) => CheckinTeam(
    id: json['id'] as int, projectId: json['projectId'] as int,
    name: json['name'] as String? ?? '', status: json['status'] as int? ?? 1,
  );
}
