import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/auth_storage_keys.dart';
import '../core/network/dio_client.dart';
import '../models/user_info.dart';
import '../services/auth_service.dart';
import '../services/log_reminder_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider() {
    DioClient.instance.onUnauthorized = _handleUnauthorized;
    DioClient.instance.onTokenRefreshed = (token) {
      _token = token;
    };
  }

  UserInfo? _currentUser;
  String? _token;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;

  UserInfo? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  String? get username => _currentUser?.username;
  bool get isLoggedIn => _token != null;

  String? get role => _currentUser?.role;
  bool get isSupervisor => _currentUser?.role == 'supervisor';
  bool get isBoss => _currentUser?.role == 'boss';
  bool get canManageProjects => isSupervisor || isBoss;

  /// 启动时恢复登录态
  Future<void> loadToken() async {
    _isLoading = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString(AuthStorageKeys.token);
      _token = savedToken != null && savedToken.trim().isNotEmpty
          ? savedToken
          : null;
      if (_token != null) {
        DioClient.instance.updateToken(_token);
        final result = await AuthService.me();
        if (result.isSuccess && result.data != null) {
          _currentUser = result.data;
        } else {
          await _clearToken();
        }
      }
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    final result = await AuthService.login(username, password);
    if (result.isSuccess && result.data != null) {
      try {
        await LogReminderService.instance.clear();
      } catch (_) {/* Notification setup must not block login. */}
      final data = result.data!;
      _token = data.token;
      _currentUser = data.user;
      DioClient.instance.updateToken(_token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AuthStorageKeys.token, _token!);
      await prefs.setString(AuthStorageKeys.refreshToken, data.refreshToken);
    } else {
      _error = result.message.isEmpty ? '登录失败' : result.message;
    }
    _isLoading = false;
    notifyListeners();
    return result.isSuccess && _token != null && _currentUser != null;
  }

  Future<void> logout() async {
    try {
      await LogReminderService.instance.clear();
    } catch (_) {/* Always allow logout. */}
    await _clearToken();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> _clearToken() async {
    _token = null;
    DioClient.instance.updateToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AuthStorageKeys.token);
    await prefs.remove(AuthStorageKeys.refreshToken);
  }

  void _handleUnauthorized() {
    LogReminderService.instance.clear().catchError((Object _) {});
    _token = null;
    _currentUser = null;
    notifyListeners();
  }
}
