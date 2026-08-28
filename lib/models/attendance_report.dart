class AttendanceClockDetail {
  final int? recordId, checkpointId;
  final int expectedDayOffset;
  final String checkpointName, expectedTime, clockTime, originalTime;
  final String status, anomalyMessage, adjustmentAction, correctionReason;
  final bool countable, corrected, hasPhoto;

  const AttendanceClockDetail({
    this.recordId,
    this.checkpointId,
    required this.expectedDayOffset,
    required this.checkpointName,
    required this.expectedTime,
    required this.clockTime,
    required this.originalTime,
    required this.status,
    required this.anomalyMessage,
    required this.adjustmentAction,
    required this.correctionReason,
    required this.countable,
    required this.corrected,
    required this.hasPhoto,
  });

  factory AttendanceClockDetail.fromJson(Map<String, dynamic> j) =>
      AttendanceClockDetail(
        recordId: j['recordId'] as int?,
        checkpointId: j['checkpointId'] as int?,
        expectedDayOffset: j['expectedDayOffset'] as int? ?? 0,
        checkpointName: j['checkpointName'] as String? ?? '',
        expectedTime: j['expectedTime'] as String? ?? '',
        clockTime: j['clockTime'] as String? ?? '',
        originalTime: j['originalTime'] as String? ?? '',
        status: j['status'] as String? ?? 'missing',
        anomalyMessage: j['anomalyMessage'] as String? ?? '',
        adjustmentAction: j['adjustmentAction'] as String? ?? '',
        correctionReason: j['correctionReason'] as String? ?? '',
        countable: j['countable'] == true,
        corrected: j['corrected'] == true,
        hasPhoto: j['hasPhoto'] == true,
      );
}

class DailyAttendance {
  final int workerId, projectId, teamId, shiftId;
  final String workerName;
  final String date, projectName, teamName, shiftName, status;
  final double workHours, overtimeHours, workUnits;
  final int anomalyCount;
  final bool corrected;
  final String statusMessage;
  final List<AttendanceClockDetail> clocks;
  const DailyAttendance(
      {required this.workerId,
      required this.projectId,
      required this.teamId,
      required this.shiftId,
      required this.workerName,
      required this.date,
      required this.projectName,
      required this.teamName,
      required this.shiftName,
      required this.status,
      required this.workHours,
      required this.overtimeHours,
      required this.workUnits,
      required this.anomalyCount,
      required this.corrected,
      required this.statusMessage,
      required this.clocks});
  factory DailyAttendance.fromJson(Map<String, dynamic> j) => DailyAttendance(
      workerId: j['workerId'] as int? ?? 0,
      projectId: j['projectId'] as int? ?? 0,
      teamId: j['teamId'] as int? ?? 0,
      shiftId: j['shiftId'] as int? ?? 0,
      workerName: j['workerName'] ?? '',
      date: j['attendanceDate'] ?? '',
      projectName: j['projectName'] ?? '',
      teamName: j['teamName'] ?? '',
      shiftName: j['shiftName'] ?? '',
      status: j['status'] ?? '',
      workHours: (j['workHours'] as num?)?.toDouble() ?? 0,
      overtimeHours: (j['overtimeHours'] as num?)?.toDouble() ?? 0,
      workUnits: (j['workUnits'] as num?)?.toDouble() ?? 0,
      anomalyCount: j['anomalyCount'] as int? ?? 0,
      corrected: j['corrected'] == true,
      statusMessage: j['statusMessage'] as String? ?? '',
      clocks: (j['clocks'] as List? ?? const [])
          .map((e) =>
              AttendanceClockDetail.fromJson(Map<String, dynamic>.from(e)))
          .toList());
}

class WorkerMonthReport {
  final String month, workerName;
  final double totalWorkHours, totalOvertimeHours, totalWorkUnits;
  final int anomalyDays, correctedDays;
  final List<DailyAttendance> days;
  const WorkerMonthReport(
      {required this.month,
      required this.workerName,
      required this.totalWorkHours,
      required this.totalOvertimeHours,
      required this.totalWorkUnits,
      required this.anomalyDays,
      required this.correctedDays,
      required this.days});
  factory WorkerMonthReport.fromJson(Map<String, dynamic> j) =>
      WorkerMonthReport(
          month: j['month'] ?? '',
          workerName: j['workerName'] ?? '',
          totalWorkHours: (j['totalWorkHours'] as num?)?.toDouble() ?? 0,
          totalOvertimeHours:
              (j['totalOvertimeHours'] as num?)?.toDouble() ?? 0,
          totalWorkUnits: (j['totalWorkUnits'] as num?)?.toDouble() ?? 0,
          anomalyDays: j['anomalyDays'] as int? ?? 0,
          correctedDays: j['correctedDays'] as int? ?? 0,
          days: (j['days'] as List? ?? const [])
              .map(
                  (e) => DailyAttendance.fromJson(Map<String, dynamic>.from(e)))
              .toList());
}

class ProjectWorkerReport {
  final String workerName, teamName;
  final double workHours, overtimeHours, workUnits;
  final int attendanceDays, anomalyDays, correctedDays;
  const ProjectWorkerReport(
      {required this.workerName,
      required this.teamName,
      required this.workHours,
      required this.overtimeHours,
      required this.workUnits,
      required this.attendanceDays,
      required this.anomalyDays,
      required this.correctedDays});
  factory ProjectWorkerReport.fromJson(Map<String, dynamic> j) =>
      ProjectWorkerReport(
          workerName: j['workerName'] ?? '',
          teamName: j['teamName'] ?? '',
          workHours: (j['workHours'] as num?)?.toDouble() ?? 0,
          overtimeHours: (j['overtimeHours'] as num?)?.toDouble() ?? 0,
          workUnits: (j['workUnits'] as num?)?.toDouble() ?? 0,
          attendanceDays: j['attendanceDays'] as int? ?? 0,
          anomalyDays: j['anomalyDays'] as int? ?? 0,
          correctedDays: j['correctedDays'] as int? ?? 0);
}

class ProjectMonthReport {
  final String month, projectName;
  final double totalWorkHours, totalOvertimeHours, totalWorkUnits;
  final List<ProjectWorkerReport> workers;
  final List<DailyAttendance> days;
  const ProjectMonthReport(
      {required this.month,
      required this.projectName,
      required this.totalWorkHours,
      required this.totalOvertimeHours,
      required this.totalWorkUnits,
      required this.workers,
      required this.days});
  factory ProjectMonthReport.fromJson(Map<String, dynamic> j) =>
      ProjectMonthReport(
          month: j['month'] ?? '',
          projectName: j['projectName'] ?? '',
          totalWorkHours: (j['totalWorkHours'] as num?)?.toDouble() ?? 0,
          totalOvertimeHours:
              (j['totalOvertimeHours'] as num?)?.toDouble() ?? 0,
          totalWorkUnits: (j['totalWorkUnits'] as num?)?.toDouble() ?? 0,
          workers: (j['workers']
                      as List? ??
                  const [])
              .map((e) =>
                  ProjectWorkerReport.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          days: (j['days'] as List? ?? const [])
              .map(
                  (e) => DailyAttendance.fromJson(Map<String, dynamic>.from(e)))
              .toList());
}
