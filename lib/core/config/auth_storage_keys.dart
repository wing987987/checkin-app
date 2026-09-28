import 'package:flutter/foundation.dart';

import 'env_config.dart';

/// Web 的两个环境共享浏览器 origin，持久化键必须区分应用和环境。
/// 安卓沿用已有键名，避免现有安装包升级后丢失登录态。
class AuthStorageKeys {
  static String get _prefix => kIsWeb
      ? 'checkin.web.${EnvConfig.instance.isProd ? 'prod' : 'test'}.'
      : '';

  static String get token => '${_prefix}token';
  static String get refreshToken => '${_prefix}refreshToken';
}
