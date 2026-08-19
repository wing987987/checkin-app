import 'package:flutter/foundation.dart';

/// 环境配置（与采购 App 相同的 debug/test/prod 三环境结构）
///
/// 打包时通过 --dart-define 指定环境：
///   测试环境: flutter build apk --dart-define=ENV=test
///   生产环境: flutter build apk --dart-define=ENV=prod
///   默认(不指定): 测试环境
class EnvConfig {
  static final EnvConfig instance = EnvConfig._internal();

  late final String _env;
  late final String _baseUrl;

  EnvConfig._internal() {
    _env = const String.fromEnvironment('ENV', defaultValue: 'test');
    _baseUrl = _resolveBaseUrl();
  }

  String get env => _env;
  String get baseUrl => _baseUrl;
  bool get isProd => _env == 'prod';
  bool get isTest => _env == 'test';

  /// 测试专属 UI（快捷登录等）是否可见：
  /// debug 运行（本地 F5）始终可见；release 包按 ENV 判断，prod 包编译期剔除。
  bool get showTestFeatures => kDebugMode || !isProd;

  String _resolveBaseUrl() {
    switch (_env) {
      case 'prod':
        return 'http://app.zhaochen-construction.com';
      case 'test':
      default:
        return 'http://apptest.zhaochen-construction.com';
    }
  }

  /// Debug 模式下通过 adb reverse 转发，使用 localhost 访问本地后端
  String get debugBaseUrl {
    return 'http://localhost:8082';
  }
}