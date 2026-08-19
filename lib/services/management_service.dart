import '../core/models/api_result.dart';
import '../core/network/dio_client.dart';
import '../models/checkin_project.dart';
import '../models/checkin_shift.dart';
import '../models/checkin_team.dart';
import '../models/worker_assignment.dart';
import '../models/attendance_anomaly.dart';
import '../models/attendance_report.dart';

class ManagementService {
  static final _client = DioClient.instance;

  static Future<ApiResult<List<CheckinProject>>> projects() async {
    final response = await _client.get('/api/ck/projects');
    return ApiResult.fromJson(response.data, (data) => (data as List)
        .map((e) => CheckinProject.fromJson(Map<String, dynamic>.from(e))).toList());
  }

  static Future<ApiResult<CheckinProject>> createProject(Map<String, dynamic> data) async {
    final response = await _client.post('/api/ck/projects', data: data);
    return ApiResult.fromJson(response.data,
        (value) => CheckinProject.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<List<CheckinTeam>>> teams(int projectId) async {
    final response = await _client.get('/api/ck/projects/$projectId/teams');
    return ApiResult.fromJson(response.data, (data) => (data as List)
        .map((e) => CheckinTeam.fromJson(Map<String, dynamic>.from(e))).toList());
  }

  static Future<ApiResult<List<CheckinShift>>> shifts(int projectId) async {
    final response = await _client.get('/api/ck/projects/$projectId/shifts');
    return ApiResult.fromJson(response.data, (data) => (data as List)
        .map((e) => CheckinShift.fromJson(Map<String, dynamic>.from(e))).toList());
  }

  static Future<ApiResult<CheckinTeam>> createTeam(int projectId, String name) async {
    final response = await _client.post('/api/ck/projects/$projectId/teams', data: {'name': name, 'status': 1});
    return ApiResult.fromJson(response.data,
        (value) => CheckinTeam.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<CheckinShift>> createShift(int projectId, Map<String, dynamic> data) async {
    final response = await _client.post('/api/ck/projects/$projectId/shifts', data: data);
    return ApiResult.fromJson(response.data,
        (value) => CheckinShift.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<List<WorkerAssignment>>> workers(int projectId) async {
    final response = await _client.get('/api/ck/projects/$projectId/workers');
    return ApiResult.fromJson(response.data, (data) => (data as List)
        .map((e) => WorkerAssignment.fromJson(Map<String, dynamic>.from(e))).toList());
  }

  static Future<ApiResult<WorkerAssignment>> createWorker(int projectId, Map<String, dynamic> data) async {
    final response = await _client.post('/api/ck/projects/$projectId/workers', data: data);
    return ApiResult.fromJson(response.data,
        (value) => WorkerAssignment.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<dynamic>> assignWorker(int workerId, int projectId, int teamId, int shiftId) async {
    final response = await _client.put('/api/ck/workers/$workerId/assignment', data: {
      'projectId': projectId, 'teamId': teamId, 'shiftId': shiftId,
    });
    return ApiResult.fromJson(response.data, (value) => value);
  }

  static Future<ApiResult<List<AttendanceAnomaly>>> anomalies(int projectId) async {
    final response=await _client.get('/api/ck/attendance/anomalies',queryParameters:{'projectId':projectId});
    return ApiResult.fromJson(response.data,(data)=>(data as List)
      .map((e)=>AttendanceAnomaly.fromJson(Map<String,dynamic>.from(e))).toList());
  }

  static Future<ApiResult<AttendanceAnomaly>> resolveAnomaly(int recordId,Map<String,dynamic> data) async {
    final response=await _client.post('/api/ck/attendance/anomalies/$recordId/resolve',data:data);
    return ApiResult.fromJson(response.data,(value)=>AttendanceAnomaly.fromJson(Map<String,dynamic>.from(value)));
  }
  static Future<ApiResult<ProjectMonthReport>> projectMonthReport(int projectId,String month)async{
    final response=await _client.get('/api/ck/attendance/reports/month',queryParameters:{'projectId':projectId,'month':month});
    return ApiResult.fromJson(response.data,(data)=>ProjectMonthReport.fromJson(Map<String,dynamic>.from(data)));
  }
}
