import '../core/models/api_result.dart';
import '../core/network/dio_client.dart';
import '../models/checkin_project.dart';
import '../models/checkin_shift.dart';
import '../models/checkin_team.dart';
import '../models/worker_assignment.dart';
import '../models/attendance_anomaly.dart';
import '../models/attendance_report.dart';
import '../models/clock_photo.dart';
import '../models/my_schedule.dart';
import '../models/checkin_supervisor.dart';

class ManagementService {
  static final _client = DioClient.instance;

  static Future<ApiResult<List<CheckinSupervisor>>> supervisors() async {
    final response = await _client.get('/api/ck/supervisors');
    return ApiResult.fromJson(
        response.data,
        (data) => (data as List)
            .map(
                (e) => CheckinSupervisor.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<ApiResult<CheckinSupervisor>> createSupervisor(
      Map<String, dynamic> data) async {
    final response = await _client.post('/api/ck/supervisors', data: data);
    return ApiResult.fromJson(
        response.data,
        (value) =>
            CheckinSupervisor.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<CheckinSupervisor>> assignSupervisorProjects(
      int supervisorId, List<int> projectIds) async {
    final response = await _client.put(
        '/api/ck/supervisors/$supervisorId/projects',
        data: {'projectIds': projectIds});
    return ApiResult.fromJson(
        response.data,
        (value) =>
            CheckinSupervisor.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<List<CheckinProject>>> projects() async {
    final response = await _client.get('/api/ck/projects');
    return ApiResult.fromJson(
        response.data,
        (data) => (data as List)
            .map((e) => CheckinProject.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<ApiResult<CheckinProject>> createProject(
      Map<String, dynamic> data) async {
    final response = await _client.post('/api/ck/projects', data: data);
    return ApiResult.fromJson(response.data,
        (value) => CheckinProject.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<CheckinProject>> updateProject(
      int id, Map<String, dynamic> data) async {
    final response = await _client.put('/api/ck/projects/$id', data: data);
    return ApiResult.fromJson(response.data,
        (value) => CheckinProject.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<List<CheckinTeam>>> teams(int projectId) async {
    final response = await _client.get('/api/ck/projects/$projectId/teams');
    return ApiResult.fromJson(
        response.data,
        (data) => (data as List)
            .map((e) => CheckinTeam.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<ApiResult<List<CheckinShift>>> shifts(int projectId) async {
    final response = await _client.get('/api/ck/projects/$projectId/shifts');
    return ApiResult.fromJson(
        response.data,
        (data) => (data as List)
            .map((e) => CheckinShift.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<ApiResult<CheckinTeam>> createTeam(
      int projectId, Map<String, dynamic> data) async {
    final response =
        await _client.post('/api/ck/projects/$projectId/teams', data: data);
    return ApiResult.fromJson(response.data,
        (value) => CheckinTeam.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<dynamic>> deleteTeam(int teamId) async {
    final response = await _client.delete('/api/ck/teams/$teamId');
    return ApiResult.fromJson(response.data, (value) => value);
  }

  static Future<ApiResult<dynamic>> removeTeamMember(
      int teamId, int workerId) async {
    final response =
        await _client.delete('/api/ck/teams/$teamId/members/$workerId');
    return ApiResult.fromJson(response.data, (value) => value);
  }

  static Future<ApiResult<CheckinTeam>> updateTeam(
      int id, Map<String, dynamic> data) async {
    final response = await _client.put('/api/ck/teams/$id', data: data);
    return ApiResult.fromJson(response.data,
        (value) => CheckinTeam.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<CheckinShift>> createShift(
      int projectId, Map<String, dynamic> data) async {
    final response =
        await _client.post('/api/ck/projects/$projectId/shifts', data: data);
    return ApiResult.fromJson(response.data,
        (value) => CheckinShift.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<CheckinShift>> updateShift(
      int id, Map<String, dynamic> data) async {
    final response = await _client.put('/api/ck/shifts/$id', data: data);
    return ApiResult.fromJson(response.data,
        (value) => CheckinShift.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<List<ScheduleCheckpoint>>> checkpoints(
      int shiftId) async {
    final response = await _client.get('/api/ck/shifts/$shiftId/checkpoints');
    return ApiResult.fromJson(
        response.data,
        (data) => (data as List)
            .map((e) =>
                ScheduleCheckpoint.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<ApiResult<List<WorkerAssignment>>> workers(
      int projectId) async {
    final response = await _client.get('/api/ck/projects/$projectId/workers');
    return ApiResult.fromJson(
        response.data,
        (data) => (data as List)
            .map((e) => WorkerAssignment.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<ApiResult<WorkerAssignment>> createWorker(
      int projectId, Map<String, dynamic> data) async {
    final response =
        await _client.post('/api/ck/projects/$projectId/workers', data: data);
    return ApiResult.fromJson(response.data,
        (value) => WorkerAssignment.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<WorkerAssignment>> updateWorker(
      int workerId, Map<String, dynamic> data) async {
    final response = await _client.put('/api/ck/workers/$workerId', data: data);
    return ApiResult.fromJson(response.data,
        (value) => WorkerAssignment.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<dynamic>> resetWorkerPassword(int workerId) async {
    final response =
        await _client.put('/api/ck/workers/$workerId/reset-password');
    return ApiResult.fromJson(response.data, (value) => value);
  }

  static Future<ApiResult<dynamic>> assignWorker(
      int workerId, int projectId, int? teamId, int? shiftId) async {
    final response =
        await _client.put('/api/ck/workers/$workerId/assignment', data: {
      'projectId': projectId,
      'teamId': teamId,
      'shiftId': shiftId,
    });
    return ApiResult.fromJson(response.data, (value) => value);
  }

  static Future<ApiResult<dynamic>> transferWorker(
      int workerId, int projectId) async {
    final response =
        await _client.put('/api/ck/workers/$workerId/transfer/$projectId');
    return ApiResult.fromJson(response.data, (value) => value);
  }

  static Future<ApiResult<List<AttendanceAnomaly>>> anomalies(
      int projectId) async {
    final response = await _client.get('/api/ck/attendance/anomalies',
        queryParameters: {'projectId': projectId});
    return ApiResult.fromJson(
        response.data,
        (data) => (data as List)
            .map(
                (e) => AttendanceAnomaly.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<ApiResult<AttendanceAnomaly>> resolveAnomaly(
      int recordId, Map<String, dynamic> data) async {
    final response = await _client
        .post('/api/ck/attendance/anomalies/$recordId/resolve', data: data);
    return ApiResult.fromJson(
        response.data,
        (value) =>
            AttendanceAnomaly.fromJson(Map<String, dynamic>.from(value)));
  }

  static Future<ApiResult<List<DailyAttendance>>> anomalyDay(
      int recordId) async {
    final response =
        await _client.get('/api/ck/attendance/anomalies/$recordId/day');
    return ApiResult.fromJson(
        response.data,
        (value) => (value as List)
            .map((row) =>
                DailyAttendance.fromJson(Map<String, dynamic>.from(row)))
            .toList());
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> adjustmentHistory(
      int recordId) async {
    final response =
        await _client.get('/api/ck/attendance/records/$recordId/adjustments');
    return ApiResult.fromJson(
        response.data,
        (data) =>
            (data as List).map((e) => Map<String, dynamic>.from(e)).toList());
  }

  static Future<ApiResult<String>> anomalyPhotoViewUrl(int recordId) async {
    final response = await _client
        .get('/api/ck/files/clock-photo/$recordId/supervisor-view-url');
    return ApiResult.fromJson(response.data, (data) => data as String);
  }

  static Future<ApiResult<List<ClockPhoto>>> clockPhotos(
      int projectId, String month) async {
    final response = await _client.get('/api/ck/attendance/photos',
        queryParameters: {'projectId': projectId, 'month': month});
    return ApiResult.fromJson(
        response.data,
        (data) => (data as List)
            .map((e) => ClockPhoto.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  static Future<ApiResult<ProjectMonthReport>> projectMonthReport(
      int projectId, String month) async {
    final response = await _client.get('/api/ck/attendance/reports/month',
        queryParameters: {'projectId': projectId, 'month': month});
    return ApiResult.fromJson(response.data,
        (data) => ProjectMonthReport.fromJson(Map<String, dynamic>.from(data)));
  }

  static Future<ApiResult<dynamic>> setManualHours(
      Map<String, dynamic> data) async {
    final response =
        await _client.post('/api/ck/attendance/days/manual-hours', data: data);
    return ApiResult.fromJson(response.data, (value) => value);
  }

  static Future<ApiResult<Map<String, dynamic>>> supplementClock(
      Map<String, dynamic> data) async {
    final response =
        await _client.post('/api/ck/attendance/supplements', data: data);
    return ApiResult.fromJson(
        response.data, (value) => Map<String, dynamic>.from(value));
  }

  static Future<ApiResult<Map<String, dynamic>>> supplementOvertime(
      Map<String, dynamic> data) async {
    final response = await _client
        .post('/api/ck/attendance/supplements/overtime', data: data);
    return ApiResult.fromJson(
        response.data, (value) => Map<String, dynamic>.from(value));
  }
}
