class CheckinTeam {
  final int id;
  final int projectId;
  final String name;
  final int shiftId;
  final int status;
  final List<int> extraShiftIds;
  const CheckinTeam(
      {required this.id,
      required this.projectId,
      required this.name,
      required this.shiftId,
      required this.status,
      required this.extraShiftIds});
  factory CheckinTeam.fromJson(Map<String, dynamic> json) => CheckinTeam(
        id: json['id'] as int,
        projectId: json['projectId'] as int,
        name: json['name'] as String? ?? '',
        status: json['status'] as int? ?? 1,
        shiftId: json['shiftId'] as int? ?? 0,
        extraShiftIds: (json['extraShiftIds'] as List? ?? const [])
            .map((e) => e as int).toList(),
      );
}
