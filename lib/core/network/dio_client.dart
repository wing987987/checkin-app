import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/env_config.dart';

class DioClient {
  DioClient._internal() {
    final env = EnvConfig.instance;
    final baseUrl = kDebugMode ? env.debugBaseUrl : env.baseUrl;
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));
    print('[DioClient] 初始化完成, env=${env.env}, baseUrl=${_dio.options.baseUrl}');

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        print('[Dio] 请求: ${options.method} ${options.path}');
        if (_cachedToken == null) {
          final prefs = await SharedPreferences.getInstance();
          _cachedToken = prefs.getString('token');
        }
        if (_cachedToken != null) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        print('[Dio] 响应: ${response.requestOptions.path} → ${response.statusCode}');
        handler.next(response);
      },
      onError: (error, handler) async {
        print('[Dio] 错误: ${error.requestOptions.path} → ${error.message}, 状态码: ${error.response?.statusCode}');
        if (error.response?.statusCode == 401 &&
            error.requestOptions.path != '/api/ck/auth/refresh' &&
            error.requestOptions.extra['tokenRetried'] != true) {
          if (await _refreshOnce()) {
            final request = error.requestOptions;
            request.headers['Authorization'] = 'Bearer $_cachedToken';
            request.extra['tokenRetried'] = true;
            try {
              handler.resolve(await _dio.fetch(request));
              return;
            } catch (_) {
              // 重试仍失败时清理登录状态。
            }
          }
          await _clearTokens();
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  static DioClient? _instance;
  static DioClient get instance {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  late final Dio _dio;
  String? _cachedToken;
  Future<bool>? _refreshing;

  /// 401 未授权回调（由 AuthProvider 注册）：清理内存登录态，退回登录页
  void Function()? onUnauthorized;
  void Function(String token)? onTokenRefreshed;

  void updateToken(String? token) {
    _cachedToken = token;
  }

  Future<bool> _refreshOnce() {
    final current = _refreshing;
    if (current != null) return current;
    final future = _refreshTokens();
    _refreshing = future;
    future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
    return future;
  }

  Future<bool> _refreshTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refreshToken');
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final refreshDio = Dio(_dio.options);
      final response = await refreshDio.post('/api/ck/auth/refresh', data: {
        'refreshToken': refreshToken,
      });
      final data = response.data is Map ? response.data['data'] : null;
      final token = data is Map ? data['token'] as String? : null;
      final newRefreshToken = data is Map ? data['refreshToken'] as String? : null;
      if (token == null || newRefreshToken == null) return false;
      _cachedToken = token;
      await prefs.setString('token', token);
      await prefs.setString('refreshToken', newRefreshToken);
      onTokenRefreshed?.call(token);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearTokens() async {
    _cachedToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refreshToken');
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) {
    return _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  Future<Response> delete(String path) {
    return _dio.delete(path);
  }

  Future<Response> upload(String path, FormData formData) {
    return _dio.post(path, data: formData);
  }
}
