class AttendanceAnomaly {
  final int? recordId;
  final int referenceRecordId;
  final int workerId, projectId, teamId, shiftId;
  final int? checkpointId;
  final String workerName;
  final String teamName;
  final String shiftName;
  final String checkpointName;
  final String attendanceDate;
  final String clockTime;
  final String expectedTime;
  final int expectedDayOffset;
  final double distanceMeters;
  final String anomalyMessage;
  final String anomalyType;
  final bool resolved;
  final bool corrected;
  final bool missing;
  final String? latestReason;
  final String? photoUrl;
  const AttendanceAnomaly(
      {this.recordId,
      required this.referenceRecordId,
      required this.workerId,
      required this.projectId,
      required this.teamId,
      required this.shiftId,
      this.checkpointId,
      required this.workerName,
      required this.teamName,
      required this.shiftName,
      required this.checkpointName,
      required this.attendanceDate,
      required this.clockTime,
      required this.expectedTime,
      required this.expectedDayOffset,
      required this.distanceMeters,
      required this.anomalyMessage,
      required this.anomalyType,
      required this.resolved,
      required this.corrected,
      required this.missing,
      this.latestReason,
      this.photoUrl});
  factory AttendanceAnomaly.fromJson(Map<String, dynamic> json) =>
      AttendanceAnomaly(
          recordId: json['recordId'] as int?,
          referenceRecordId: json['referenceRecordId'] as int? ??
              json['recordId'] as int? ??
              0,
          workerId: json['workerId'] as int? ?? 0,
          projectId: json['projectId'] as int? ?? 0,
          teamId: json['teamId'] as int? ?? 0,
          shiftId: json['shiftId'] as int? ?? 0,
          checkpointId: json['checkpointId'] as int?,
          workerName: json['workerName'] as String? ?? '',
          teamName: json['teamName'] as String? ?? '',
          shiftName: json['shiftName'] as String? ?? '',
          checkpointName: json['checkpointName'] as String? ?? '',
          attendanceDate: json['attendanceDate'] as String? ?? '',
          clockTime: json['clockTime'] as String? ?? '',
          expectedTime: json['expectedTime'] as String? ?? '',
          expectedDayOffset: json['expectedDayOffset'] as int? ?? 0,
          distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
          anomalyMessage: json['anomalyMessage'] as String? ?? '',
          anomalyType: json['anomalyType'] as String? ?? '',
          resolved: json['resolved'] == true,
          corrected: json['corrected'] == true,
          missing: json['missing'] == true || json['anomalyType'] == 'missing',
          latestReason: json['latestReason'] as String?,
          photoUrl: json['photoUrl'] as String?);
}
