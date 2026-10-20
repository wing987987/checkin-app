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
  final String? finalClockOutDeadline;
  final bool secondment;
  final String secondmentLabel;
  final bool fieldWork, tomorrowFieldWork;
  final String? fieldReason;
  final bool clockPaused;
  final String pauseStatus;
  final String? pauseStartAt, resumeAt;
  bool isPausedAt(DateTime now) {
    final start = DateTime.tryParse(pauseStartAt ?? '');
    final end = DateTime.tryParse(resumeAt ?? '');
    return start == null
        ? clockPaused
        : !now.isBefore(start) && (end == null || now.isBefore(end));
  }

  final int projectId;
  final String projectName;
  final int fenceRadius;
  final double gpsLat;
  final double gpsLng;
  final String teamName;
  final int shiftId;
  final bool allowOutsideClockWindow;
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
      {this.finalClockOutDeadline,
      this.secondment = false,
      this.secondmentLabel = '',
      this.allowOutsideClockWindow = false,
      this.fieldWork = false,
      this.tomorrowFieldWork = false,
      this.fieldReason,
      this.clockPaused = false,
      this.pauseStatus = 'active',
      this.pauseStartAt,
      this.resumeAt,
      required this.projectId,
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
  DateTime expectedAt(ScheduleCheckpoint point) {
    final date = DateTime.parse(attendanceDate);
    final parts = point.expectedTime.split(':').map(int.parse).toList();
    return DateTime(date.year, date.month, date.day + point.dayOffset, parts[0],
        parts[1], parts.length > 2 ? parts[2] : 0);
  }

  bool isClockIn(ScheduleCheckpoint point) => const [
        'start',
        'morning_in',
        'break_end',
        'afternoon_in'
      ].contains(point.code);

  DateTime windowStart(ScheduleCheckpoint point) =>
      expectedAt(point).subtract(Duration(minutes: isClockIn(point) ? 30 : 5));
  bool isFinalClockOut(ScheduleCheckpoint point) =>
      !fieldWork && (point.code == 'end' || point.code == 'afternoon_out');

  DateTime get overtimeDeadline {
    final supplied = DateTime.tryParse(finalClockOutDeadline ?? '');
    if (supplied != null) return supplied;
    final date = DateTime.parse(attendanceDate);
    return DateTime(
        date.year, date.month, date.day + 1, shiftType == 'night' ? 12 : 0);
  }

  DateTime windowEnd(ScheduleCheckpoint point) => isFinalClockOut(point)
      ? overtimeDeadline
      : expectedAt(point).add(Duration(minutes: isClockIn(point) ? 5 : 30));

  bool canClockAt(DateTime now) =>
      !isPausedAt(now) &&
      checkpoints.any((point) =>
          !records.any((r) =>
              r.checkpointId == point.id || r.checkpointCode == point.code) &&
          (isFinalClockOut(point)
              ? now.isBefore(windowEnd(point)) &&
                  (allowOutsideClockWindow || !now.isBefore(windowStart(point)))
              : allowOutsideClockWindow ||
                  (!now.isBefore(windowStart(point)) &&
                      !now.isAfter(windowEnd(point)))));

  factory MySchedule.fromJson(Map<String, dynamic> json) => MySchedule(
      finalClockOutDeadline: json['finalClockOutDeadline'] as String?,
      secondment: json['secondment'] == true,
      secondmentLabel: json['secondmentLabel'] as String? ?? '',
      fieldWork: json['fieldWork'] == true,
      tomorrowFieldWork: json['tomorrowFieldWork'] == true,
      fieldReason: json['fieldReason'] as String?,
      clockPaused: json['clockPaused'] == true,
      pauseStatus: json['pauseStatus'] as String? ?? 'active',
      pauseStartAt: json['pauseStartAt'] as String?,
      resumeAt: json['resumeAt'] as String?,
      projectId: json['projectId'] as int,
      projectName: json['projectName'] as String? ?? '',
      fenceRadius: json['fenceRadius'] as int? ?? 100,
      gpsLat: (json['gpsLat'] as num).toDouble(),
      gpsLng: (json['gpsLng'] as num).toDouble(),
      teamName: json['teamName'] as String? ?? '',
      shiftId: json['shiftId'] as int,
      allowOutsideClockWindow: json['allowOutsideClockWindow'] == true ||
          json['allowOutsideClockWindow'] == 1,
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
