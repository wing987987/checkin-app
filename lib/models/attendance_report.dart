class DailyAttendance {
  final String date,projectName,teamName,shiftName,status;
  final double workHours,overtimeHours,workUnits;
  final int anomalyCount;
  final bool corrected;
  const DailyAttendance({required this.date,required this.projectName,required this.teamName,required this.shiftName,
    required this.status,required this.workHours,required this.overtimeHours,required this.workUnits,
    required this.anomalyCount,required this.corrected});
  factory DailyAttendance.fromJson(Map<String,dynamic> j)=>DailyAttendance(date:j['attendanceDate']??'',projectName:j['projectName']??'',
    teamName:j['teamName']??'',shiftName:j['shiftName']??'',status:j['status']??'',workHours:(j['workHours']as num?)?.toDouble()??0,
    overtimeHours:(j['overtimeHours']as num?)?.toDouble()??0,workUnits:(j['workUnits']as num?)?.toDouble()??0,
    anomalyCount:j['anomalyCount']as int? ??0,corrected:j['corrected']==true);
}
class WorkerMonthReport{
  final String month,workerName;final double totalWorkHours,totalOvertimeHours,totalWorkUnits;final int anomalyDays,correctedDays;final List<DailyAttendance> days;
  const WorkerMonthReport({required this.month,required this.workerName,required this.totalWorkHours,required this.totalOvertimeHours,
    required this.totalWorkUnits,required this.anomalyDays,required this.correctedDays,required this.days});
  factory WorkerMonthReport.fromJson(Map<String,dynamic>j)=>WorkerMonthReport(month:j['month']??'',workerName:j['workerName']??'',
    totalWorkHours:(j['totalWorkHours']as num?)?.toDouble()??0,totalOvertimeHours:(j['totalOvertimeHours']as num?)?.toDouble()??0,
    totalWorkUnits:(j['totalWorkUnits']as num?)?.toDouble()??0,anomalyDays:j['anomalyDays']as int? ??0,correctedDays:j['correctedDays']as int? ??0,
    days:(j['days']as List? ??const[]).map((e)=>DailyAttendance.fromJson(Map<String,dynamic>.from(e))).toList());
}
class ProjectWorkerReport{
  final String workerName,teamName;final double workHours,overtimeHours,workUnits;final int attendanceDays,anomalyDays,correctedDays;
  const ProjectWorkerReport({required this.workerName,required this.teamName,required this.workHours,required this.overtimeHours,
    required this.workUnits,required this.attendanceDays,required this.anomalyDays,required this.correctedDays});
  factory ProjectWorkerReport.fromJson(Map<String,dynamic>j)=>ProjectWorkerReport(workerName:j['workerName']??'',teamName:j['teamName']??'',
    workHours:(j['workHours']as num?)?.toDouble()??0,overtimeHours:(j['overtimeHours']as num?)?.toDouble()??0,
    workUnits:(j['workUnits']as num?)?.toDouble()??0,attendanceDays:j['attendanceDays']as int? ??0,
    anomalyDays:j['anomalyDays']as int? ??0,correctedDays:j['correctedDays']as int? ??0);
}
class ProjectMonthReport{
  final String month,projectName;final double totalWorkHours,totalOvertimeHours,totalWorkUnits;final List<ProjectWorkerReport> workers;
  const ProjectMonthReport({required this.month,required this.projectName,required this.totalWorkHours,required this.totalOvertimeHours,
    required this.totalWorkUnits,required this.workers});
  factory ProjectMonthReport.fromJson(Map<String,dynamic>j)=>ProjectMonthReport(month:j['month']??'',projectName:j['projectName']??'',
    totalWorkHours:(j['totalWorkHours']as num?)?.toDouble()??0,totalOvertimeHours:(j['totalOvertimeHours']as num?)?.toDouble()??0,
    totalWorkUnits:(j['totalWorkUnits']as num?)?.toDouble()??0,
    workers:(j['workers']as List? ??const[]).map((e)=>ProjectWorkerReport.fromJson(Map<String,dynamic>.from(e))).toList());
}
