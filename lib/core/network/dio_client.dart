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
        if (error.response?.statusCode == 401) {
          _cachedToken = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('token');
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

  /// 401 未授权回调（由 AuthProvider 注册）：清理内存登录态，退回登录页
  void Function()? onUnauthorized;

  void updateToken(String? token) {
    _cachedToken = token;
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
