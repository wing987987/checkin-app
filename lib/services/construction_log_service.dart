import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../core/models/api_result.dart';
import '../core/network/dio_client.dart';

class ConstructionLogService {
  static final _client = DioClient.instance;
  static const _path = '/api/ck/construction-logs';
  static ApiResult<Map<String, dynamic>> _map(dynamic data) =>
      ApiResult.fromJson(data, (v) => Map<String, dynamic>.from(v));

  static Future<ApiResult<Map<String, dynamic>>> mine(int projectId) async =>
      _map((await _client
              .get('$_path/mine', queryParameters: {'projectId': projectId}))
          .data);
  static Future<ApiResult<Map<String, dynamic>>> detail(int id) async =>
      _map((await _client.get('$_path/$id')).data);
  static Future<ApiResult<String>> photoUrl(int id) async => ApiResult.fromJson(
      (await _client.get('$_path/photos/$id/view-url')).data,
      (v) => v as String);
  static Future<ApiResult<Map<String, dynamic>>> summary(
          int projectId, String date) async =>
      _map((await _client.get('$_path/attendance-summary',
              queryParameters: {'projectId': projectId, 'date': date}))
          .data);
  static Future<ApiResult<List<Map<String, dynamic>>>> history(int projectId,
      {String? date, int? supervisorId, int offset = 0}) async {
    final r = await _client.get(_path, queryParameters: {
      'projectId': projectId,
      if (offset > 0) 'offset': offset,
      if (date != null) 'date': date,
      if (supervisorId != null) 'supervisorId': supervisorId
    });
    return ApiResult.fromJson(r.data,
        (v) => (v as List).map((e) => Map<String, dynamic>.from(e)).toList());
  }

  static Future<ApiResult<List<Map<String, dynamic>>>> authors(
      int projectId) async {
    final r = await _client
        .get('$_path/authors', queryParameters: {'projectId': projectId});
    return ApiResult.fromJson(r.data,
        (v) => (v as List).map((e) => Map<String, dynamic>.from(e)).toList());
  }

  static Future<ApiResult<Map<String, dynamic>>> save(
      int projectId, Map<String, dynamic> data,
      {bool submit = false}) async {
    final r = submit
        ? await _client.post('$_path/submit?projectId=$projectId', data: data)
        : await _client.put('$_path/draft?projectId=$projectId', data: data);
    return _map(r.data);
  }

  static Future<ApiResult<Map<String, dynamic>>> upload(
      int projectId,
      String date,
      String source,
      Uint8List bytes,
      String filename,
      String subtype) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes,
          filename: filename, contentType: DioMediaType('image', subtype))
    });
    return _map((await _client.upload(
            '$_path/photos?projectId=$projectId&date=$date&source=$source',
            form))
        .data);
  }
}
