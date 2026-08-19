import '../core/models/api_result.dart';
import '../core/network/dio_client.dart';
import '../models/user_info.dart';
import '../models/login_result.dart';

/// 打卡 App 认证接口（后端统一前缀 /api/ck，与采购 App 的 /api 隔离）
class AuthService {
  static final _client = DioClient.instance;

  static Future<ApiResult<LoginResult>> login(
      String username, String password) async {
    try {
      final response = await _client.post('/api/ck/auth/login', data: {
        'username': username,
        'password': password,
      });
      return ApiResult.fromJson(
        response.data,
        (d) => LoginResult.fromJson(Map<String, dynamic>.from(d)),
      );
    } catch (e) {
      return ApiResult(code: -1, message: '网络请求失败: $e');
    }
  }

  static Future<ApiResult<UserInfo>> me() async {
    try {
      final response = await _client.get('/api/ck/auth/me');
      return ApiResult.fromJson(response.data, (d) => UserInfo.fromJson(d));
    } catch (e) {
      return ApiResult(code: -1, message: '网络请求失败: $e');
    }
  }
}
