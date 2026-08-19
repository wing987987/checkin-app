import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/network/dio_client.dart';
import '../models/user_info.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    DioClient.instance.onUnauthorized = _handleUnauthorized;
  }

  UserInfo? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _error;

  UserInfo? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _token != null;

  String? get role => _currentUser?.role;
  bool get isAdmin => _currentUser?.role == 'admin';

  /// 启动时恢复登录态
  Future<void> loadToken() async {
    _isLoading = true;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    if (_token != null) {
      DioClient.instance.updateToken(_token);
      final result = await AuthService.me();
      if (result.isSuccess && result.data != null) {
        _currentUser = result.data;
      } else {
        await _clearToken();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await AuthService.login(username, password);
    if (result.isSuccess && result.data != null) {
      final data = result.data!;
      _token = data['token'] as String?;
      DioClient.instance.updateToken(_token);
      if (data['user'] != null) {
        _currentUser = UserInfo.fromJson(data['user'] as Map<String, dynamic>);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token ?? '');
    } else {
      _error = result.message.isEmpty ? '登录失败' : result.message;
    }
    _isLoading = false;
    notifyListeners();
    return result.isSuccess;
  }

  Future<void> logout() async {
    await _clearToken();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _clearToken() async {
    _token = null;
    DioClient.instance.updateToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  void _handleUnauthorized() {
    _token = null;
    _currentUser = null;
    notifyListeners();
  }
}