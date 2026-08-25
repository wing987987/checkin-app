class CheckinShift {
  final int id;
  final int projectId;
  final String name;
  final String shiftType;
  final String startTime;
  final String endTime;
  final String? breakStartTime;
  final String? breakEndTime;
  final bool crossDay;
  final int graceBeforeMinutes;
  final int graceAfterMinutes;
  final int status;
  const CheckinShift(
      {required this.id,
      required this.projectId,
      required this.name,
      required this.shiftType,
      required this.startTime,
      required this.endTime,
      this.breakStartTime,
      this.breakEndTime,
      required this.crossDay,
      required this.graceBeforeMinutes,
      required this.graceAfterMinutes,
      required this.status});
  factory CheckinShift.fromJson(Map<String, dynamic> json) => CheckinShift(
        id: json['id'] as int,
        projectId: json['projectId'] as int,
        name: json['name'] as String? ?? '',
        shiftType: json['shiftType'] as String? ?? 'day',
        startTime: json['startTime'] as String? ?? '',
        endTime: json['endTime'] as String? ?? '',
        crossDay: json['crossDay'] == 1,
        breakStartTime: json['breakStartTime'] as String?,
        breakEndTime: json['breakEndTime'] as String?,
        graceBeforeMinutes: json['graceBeforeMinutes'] as int? ?? 5,
        graceAfterMinutes: json['graceAfterMinutes'] as int? ?? 5,
        status: json['status'] as int? ?? 1,
      );
}
