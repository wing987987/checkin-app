class ScheduleCheckpoint {
  final int id;
  final String code;
  final String name;
  final String expectedTime;
  final int dayOffset;
  const ScheduleCheckpoint({required this.id, required this.code, required this.name,
    required this.expectedTime, required this.dayOffset});
  factory ScheduleCheckpoint.fromJson(Map<String,dynamic> json)=>ScheduleCheckpoint(
    id:json['id'] as int,code:json['code'] as String? ?? '',name:json['name'] as String? ?? '',
    expectedTime:json['expectedTime'] as String? ?? '',dayOffset:json['dayOffset'] as int? ?? 0);
}

class ClockStatus {
  final int checkpointId;
  final String serverTime;
  final String? anomalyType;
  final bool countable;
  const ClockStatus({required this.checkpointId,required this.serverTime,this.anomalyType,required this.countable});
  factory ClockStatus.fromJson(Map<String,dynamic> json)=>ClockStatus(
    checkpointId:json['checkpointId'] as int,serverTime:json['serverTime'] as String? ?? '',
    anomalyType:json['anomalyType'] as String?,countable:json['countable']==1);
}

class MySchedule {
  final int projectId;
  final String projectName;
  final int fenceRadius;
  final double gpsLat;
  final double gpsLng;
  final String teamName;
  final String shiftName;
  final String shiftType;
  final String attendanceDate;
  final List<ScheduleCheckpoint> checkpoints;
  final List<ClockStatus> records;
  const MySchedule({required this.projectId,required this.projectName,required this.fenceRadius,required this.gpsLat,required this.gpsLng,
    required this.teamName,required this.shiftName,required this.shiftType,required this.attendanceDate,
    required this.checkpoints,required this.records});
  factory MySchedule.fromJson(Map<String,dynamic> json)=>MySchedule(
    projectId:json['projectId'] as int,projectName:json['projectName'] as String? ?? '',
    fenceRadius:json['fenceRadius'] as int? ?? 100,gpsLat:(json['gpsLat'] as num).toDouble(),gpsLng:(json['gpsLng'] as num).toDouble(),teamName:json['teamName'] as String? ?? '',
    shiftName:json['shiftName'] as String? ?? '',shiftType:json['shiftType'] as String? ?? '',
    attendanceDate:json['attendanceDate'] as String? ?? '',
    checkpoints:(json['checkpoints'] as List? ?? const []).map((e)=>ScheduleCheckpoint.fromJson(Map<String,dynamic>.from(e))).toList(),
    records:(json['records'] as List? ?? const []).map((e)=>ClockStatus.fromJson(Map<String,dynamic>.from(e))).toList());
}
