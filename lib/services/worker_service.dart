import '../core/models/api_result.dart';
import '../core/network/dio_client.dart';
import '../models/my_schedule.dart';
import 'package:dio/dio.dart';
import '../models/attendance_report.dart';

class WorkerService {
  static Future<ApiResult<MySchedule>> schedule() async {
    final response = await DioClient.instance.get('/api/ck/worker/schedule');
    return ApiResult.fromJson(response.data,
        (data) => MySchedule.fromJson(Map<String, dynamic>.from(data)));
  }

  static Future<ApiResult<String>> uploadPhoto(String path) async {
    ApiResult<String>? lastResult;
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        final form = FormData.fromMap({
          'file': await MultipartFile.fromFile(path,
              filename: 'clock.jpg', contentType: DioMediaType('image', 'jpeg'))
        });
        final response =
            await DioClient.instance.upload('/api/ck/files/clock-photo', form);
        lastResult =
            ApiResult.fromJson(response.data, (data) => data as String);
        if (lastResult.isSuccess) return lastResult;
      } catch (error) {
        lastError = error;
      }
      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    return lastResult ??
        ApiResult(code: -1, message: '照片上传失败，已重试3次：${lastError ?? '网络异常'}');
  }

  static Future<ApiResult<Map<String, dynamic>>> clock(
      Map<String, dynamic> data) async {
    final response =
        await DioClient.instance.post('/api/ck/worker/clock', data: data);
    return ApiResult.fromJson(
        response.data, (value) => Map<String, dynamic>.from(value));
  }

  static Future<ApiResult<Map<String, dynamic>>> overtimeClock(
      Map<String, dynamic> data) async {
    final response = await DioClient.instance
        .post('/api/ck/worker/overtime-clock', data: data);
    return ApiResult.fromJson(
        response.data, (value) => Map<String, dynamic>.from(value));
  }

  static Future<ApiResult<String>> clockPhotoViewUrl(int recordId) async {
    final response = await DioClient.instance
        .get('/api/ck/files/clock-photo/$recordId/view-url');
    return ApiResult.fromJson(response.data, (data) => data as String);
  }

  static Future<ApiResult<WorkerMonthReport>> monthReport(String month) async {
    final response = await DioClient.instance
        .get('/api/ck/worker/reports/month', queryParameters: {'month': month});
    return ApiResult.fromJson(response.data,
        (data) => WorkerMonthReport.fromJson(Map<String, dynamic>.from(data)));
  }
}
