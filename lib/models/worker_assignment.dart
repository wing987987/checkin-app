class WorkerAssignment {
  final int workerId;
  final String username;
  final String realName;
  final String? phone;
  final int projectId;
  final int teamId;
  final String teamName;
  final int shiftId;
  final String shiftName;

  const WorkerAssignment({required this.workerId, required this.username, required this.realName,
    this.phone, required this.projectId, required this.teamId, required this.teamName,
    required this.shiftId, required this.shiftName});

  factory WorkerAssignment.fromJson(Map<String, dynamic> json) => WorkerAssignment(
    workerId: json['workerId'] as int, username: json['username'] as String? ?? '',
    realName: json['realName'] as String? ?? '', phone: json['phone'] as String?,
    projectId: json['projectId'] as int, teamId: json['teamId'] as int,
    teamName: json['teamName'] as String? ?? '', shiftId: json['shiftId'] as int,
    shiftName: json['shiftName'] as String? ?? '',
  );
}
