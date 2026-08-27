class ClockPhoto {
  final int recordId;
  final int workerId;
  final String workerName;
  final String teamName;
  final String shiftName;
  final String checkpointName;
  final String attendanceDate;
  final String clockTime;
  final String anomalyMessage;

  const ClockPhoto({
    required this.recordId,
    required this.workerId,
    required this.workerName,
    required this.teamName,
    required this.shiftName,
    required this.checkpointName,
    required this.attendanceDate,
    required this.clockTime,
    required this.anomalyMessage,
  });

  factory ClockPhoto.fromJson(Map<String, dynamic> json) => ClockPhoto(
        recordId: json['recordId'] as int,
        workerId: json['workerId'] as int? ?? 0,
        workerName: json['workerName'] as String? ?? '',
        teamName: json['teamName'] as String? ?? '',
        shiftName: json['shiftName'] as String? ?? '',
        checkpointName: json['checkpointName'] as String? ?? '',
        attendanceDate: json['attendanceDate'] as String? ?? '',
        clockTime: json['clockTime'] as String? ?? '',
        anomalyMessage: json['anomalyMessage'] as String? ?? '',
      );
}
