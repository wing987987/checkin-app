import '../core/network/dio_client.dart';
import '../models/attendance_anomaly.dart';

class AnomalyReasonService {
  static Future<dynamic> _data(Future<dynamic> request) async {
    final response = await request;
    final body = response.data as Map;
    if (body['code'] != 200) throw Exception(body['message'] ?? '操作失败');
    return body['data'];
  }

  static Future<List<Map<String, dynamic>>> _list(
          Future<dynamic> request) async =>
      ((await _data(request)) as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  static Future<List<Map<String, dynamic>>> myTeams() =>
      _list(DioClient.instance.get('/api/ck/foreman/teams'));
  static Future<List<Map<String, dynamic>>> foremen(int project) =>
      _list(DioClient.instance.get('/api/ck/projects/$project/foremen'));
  static Future<void> setForeman(int team, int? worker) async {
    await _data(DioClient.instance
        .put('/api/ck/teams/$team/foreman', data: {'workerId': worker}));
  }

  static Future<List<AttendanceAnomaly>> anomalies(
          int project, int team) async =>
      (await _list(DioClient.instance.get('/api/ck/foreman/anomalies',
              queryParameters: {'projectId': project, 'teamId': team})))
          .map(AttendanceAnomaly.fromJson)
          .toList();
  static Map<String, dynamic> key(AttendanceAnomaly item) => {
        'projectId': item.projectId,
        'teamId': item.teamId,
        'workerId': item.workerId,
        'shiftId': item.shiftId,
        'attendanceDate': item.attendanceDate,
      };
  static Future<List<Map<String, dynamic>>> history(AttendanceAnomaly item) =>
      _list(DioClient.instance
          .post('/api/ck/attendance/anomaly-reasons/history', data: key(item)));
  static Future<void> append(AttendanceAnomaly item, String reason) async {
    await _data(DioClient.instance.post('/api/ck/attendance/anomaly-reasons',
        data: {...key(item), 'reason': reason}));
  }
}
