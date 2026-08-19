class CheckinShift {
  final int id;
  final int projectId;
  final String name;
  final String shiftType;
  final String startTime;
  final String endTime;
  final bool crossDay;
  const CheckinShift({required this.id, required this.projectId, required this.name,
    required this.shiftType, required this.startTime, required this.endTime, required this.crossDay});
  factory CheckinShift.fromJson(Map<String, dynamic> json) => CheckinShift(
    id: json['id'] as int, projectId: json['projectId'] as int,
    name: json['name'] as String? ?? '', shiftType: json['shiftType'] as String? ?? 'day',
    startTime: json['startTime'] as String? ?? '', endTime: json['endTime'] as String? ?? '',
    crossDay: json['crossDay'] == 1,
  );
}
