class ScheduleCheckpoint {
  final int id;
  final String code;
  final String name;
  final String expectedTime;
  final int dayOffset;
  const ScheduleCheckpoint(
      {required this.id,
      required this.code,
      required this.name,
      required this.expectedTime,
      required this.dayOffset});
  factory ScheduleCheckpoint.fromJson(Map<String, dynamic> json) =>
      ScheduleCheckpoint(
          id: json['id'] as int,
          code: json['code'] as String? ?? '',
          name: json['name'] as String? ?? '',
          expectedTime: json['expectedTime'] as String? ?? '',
          dayOffset: json['dayOffset'] as int? ?? 0);
}

class ClockStatus {
  final int id;
  final int checkpointId;
  final String serverTime;
  final String checkpointCode;
  final String checkpointName;
  final String? anomalyType;
  final bool countable;
  final double? gpsAccuracy;
  final double? distanceMeters;
  final bool hasPhoto;
  const ClockStatus(
      {required this.id,
      required this.checkpointId,
      required this.serverTime,
      required this.checkpointCode,
      required this.checkpointName,
      this.anomalyType,
      required this.countable,
      this.gpsAccuracy,
      this.distanceMeters,
      required this.hasPhoto});
  factory ClockStatus.fromJson(Map<String, dynamic> json) => ClockStatus(
      id: json['id'] as int,
      checkpointId: json['checkpointId'] as int,
      serverTime: json['serverTime'] as String? ?? '',
      checkpointCode: json['checkpointCode'] as String? ?? '',
      checkpointName: json['checkpointName'] as String? ?? '',
      anomalyType: json['anomalyType'] as String?,
      countable: json['countable'] == 1,
      gpsAccuracy: (json['gpsAccuracy'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      hasPhoto: (json['photoUrl'] as String?)?.isNotEmpty == true);
}

class MySchedule {
  final int projectId;
  final String projectName;
  final int fenceRadius;
  final double gpsLat;
  final double gpsLng;
  final String teamName;
  final int shiftId;
  final String shiftName;
  final String shiftType;
  final String startTime;
  final String endTime;
  final bool overtimeAvailable;
  final String attendanceDate;
  final List<ScheduleCheckpoint> checkpoints;
  final List<ClockStatus> records;
  final bool extraShift;
  final List<MySchedule> extraSchedules;
  const MySchedule(
      {required this.projectId,
      required this.projectName,
      required this.fenceRadius,
      required this.gpsLat,
      required this.gpsLng,
      required this.teamName,
      required this.shiftId,
      required this.shiftName,
      required this.shiftType,
      required this.startTime,
      required this.endTime,
      required this.overtimeAvailable,
      required this.attendanceDate,
      required this.checkpoints,
      required this.records,
      required this.extraShift,
      required this.extraSchedules});
  factory MySchedule.fromJson(Map<String, dynamic> json) => MySchedule(
      projectId: json['projectId'] as int,
      projectName: json['projectName'] as String? ?? '',
      fenceRadius: json['fenceRadius'] as int? ?? 100,
      gpsLat: (json['gpsLat'] as num).toDouble(),
      gpsLng: (json['gpsLng'] as num).toDouble(),
      teamName: json['teamName'] as String? ?? '',
      shiftId: json['shiftId'] as int,
      shiftName: json['shiftName'] as String? ?? '',
      shiftType: json['shiftType'] as String? ?? '',
      startTime: json['startTime'] as String? ?? '',
      endTime: json['endTime'] as String? ?? '',
      overtimeAvailable: json['overtimeAvailable'] == true,
      attendanceDate: json['attendanceDate'] as String? ?? '',
      checkpoints: (json['checkpoints'] as List? ?? const [])
          .map((e) => ScheduleCheckpoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      records: (json['records'] as List? ?? const [])
          .map((e) => ClockStatus.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      extraShift: json['extraShift'] == true,
      extraSchedules: (json['extraSchedules'] as List? ?? const [])
          .map((e) => MySchedule.fromJson(Map<String, dynamic>.from(e)))
          .toList());
}
