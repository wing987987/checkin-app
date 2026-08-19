class AttendanceAnomaly {
  final int recordId;
  final String workerName;
  final String teamName;
  final String shiftName;
  final String checkpointName;
  final String attendanceDate;
  final String clockTime;
  final double distanceMeters;
  final String anomalyMessage;
  final bool resolved;
  final bool corrected;
  final String? latestReason;
  const AttendanceAnomaly({required this.recordId,required this.workerName,required this.teamName,
    required this.shiftName,required this.checkpointName,required this.attendanceDate,required this.clockTime,
    required this.distanceMeters,required this.anomalyMessage,required this.resolved,required this.corrected,this.latestReason});
  factory AttendanceAnomaly.fromJson(Map<String,dynamic> json)=>AttendanceAnomaly(
    recordId:json['recordId'] as int,workerName:json['workerName'] as String? ?? '',teamName:json['teamName'] as String? ?? '',
    shiftName:json['shiftName'] as String? ?? '',checkpointName:json['checkpointName'] as String? ?? '',
    attendanceDate:json['attendanceDate'] as String? ?? '',clockTime:json['clockTime'] as String? ?? '',
    distanceMeters:(json['distanceMeters'] as num?)?.toDouble()??0,anomalyMessage:json['anomalyMessage'] as String? ?? '',
    resolved:json['resolved']==true,corrected:json['corrected']==true,latestReason:json['latestReason'] as String?);
}
