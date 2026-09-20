class WorkerAssignment {
  final int workerId;
  final String username;
  final String realName;
  final String? jobType;
  final String? phone;
  final int projectId;
  final int? teamId;
  final String teamName;
  final int? shiftId;
  final String shiftName;
  final int? personalShiftId;
  final bool personalShiftOverride;
  final int status;

  const WorkerAssignment(
      {required this.workerId,
      required this.username,
      required this.realName,
      this.jobType,
      this.phone,
      required this.projectId,
      required this.teamId,
      required this.teamName,
      required this.shiftId,
      required this.shiftName,
      this.personalShiftId,
      required this.personalShiftOverride,
      required this.status});

  factory WorkerAssignment.fromJson(Map<String, dynamic> json) =>
      WorkerAssignment(
        workerId: json['workerId'] as int,
        username: json['username'] as String? ?? '',
        realName: json['realName'] as String? ?? '',
        jobType: json['jobType'] as String?,
        phone: json['phone'] as String?,
        projectId: json['projectId'] as int,
        teamId: json['teamId'] as int?,
        teamName: json['teamName'] as String? ?? '',
        shiftId: json['shiftId'] as int?,
        shiftName: json['shiftName'] as String? ?? '',
        personalShiftId: json['personalShiftId'] as int?,
        personalShiftOverride: json['personalShiftOverride'] == true,
        status: json['status'] as int? ?? 1,
      );
}
