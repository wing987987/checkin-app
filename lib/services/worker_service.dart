import '../core/models/api_result.dart';
import '../core/network/dio_client.dart';
import '../models/my_schedule.dart';
import 'package:dio/dio.dart';
import '../models/attendance_report.dart';

class WorkerService {
  static Future<ApiResult<MySchedule>> schedule() async {
    final response=await DioClient.instance.get('/api/ck/worker/schedule');
    return ApiResult.fromJson(response.data,(data)=>MySchedule.fromJson(Map<String,dynamic>.from(data)));
  }

  static Future<ApiResult<String>> uploadPhoto(String path) async {
    final form=FormData.fromMap({'file':await MultipartFile.fromFile(path,filename:'clock.png')});
    final response=await DioClient.instance.upload('/api/ck/files/clock-photo',form);
    return ApiResult.fromJson(response.data,(data)=>data as String);
  }

  static Future<ApiResult<Map<String,dynamic>>> clock(Map<String,dynamic> data) async {
    final response=await DioClient.instance.post('/api/ck/worker/clock',data:data);
    return ApiResult.fromJson(response.data,(value)=>Map<String,dynamic>.from(value));
  }
  static Future<ApiResult<WorkerMonthReport>> monthReport(String month)async{
    final response=await DioClient.instance.get('/api/ck/worker/reports/month',queryParameters:{'month':month});
    return ApiResult.fromJson(response.data,(data)=>WorkerMonthReport.fromJson(Map<String,dynamic>.from(data)));
  }
}
