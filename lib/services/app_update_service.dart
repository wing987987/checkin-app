import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/config/env_config.dart';

class VersionInfo {
  final int versionCode;
  final String versionName;
  final String downloadUrl;
  final String releaseNotes;
  final bool forceUpdate;

  const VersionInfo({
    required this.versionCode,
    required this.versionName,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.forceUpdate,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) => VersionInfo(
        versionCode: json['versionCode'] as int? ?? 0,
        versionName: json['versionName'] as String? ?? '',
        downloadUrl: json['downloadUrl'] as String? ?? '',
        releaseNotes: json['releaseNotes'] as String? ?? '',
        forceUpdate: json['forceUpdate'] == true,
      );
}

class UpdateCheckResult {
  final bool hasUpdate;
  final VersionInfo? latestVersion;
  final String currentVersion;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.hasUpdate,
    this.latestVersion,
    required this.currentVersion,
    this.errorMessage,
  });
}

class AppUpdateService {
  AppUpdateService._();
  static final instance = AppUpdateService._();

  String get _versionUrl => EnvConfig.instance.isProd
      ? 'https://zhaochengapp.zhaochen-construction.com/apps/checkin/prod/version.json'
      : 'https://zhaochengapp.zhaochen-construction.com/apps/checkin/test/version.json';

  Future<UpdateCheckResult> checkUpdate() async {
    final package = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(package.buildNumber) ?? 0;
    try {
      final response = await Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      )).get(_versionUrl,
          options: Options(headers: {'Cache-Control': 'no-cache'}),
          queryParameters: {'t': DateTime.now().millisecondsSinceEpoch});
      final data = response.data is String
          ? jsonDecode(response.data as String) as Map<String, dynamic>
          : Map<String, dynamic>.from(response.data as Map);
      final latest = VersionInfo.fromJson(data);
      return UpdateCheckResult(
        hasUpdate: latest.versionCode > currentCode,
        latestVersion: latest,
        currentVersion: package.version,
      );
    } catch (_) {
      return UpdateCheckResult(
          hasUpdate: false,
          currentVersion: package.version,
          errorMessage: '暂时无法获取版本信息，请检查网络后重试');
    }
  }

  Future<void> downloadAndInstall(String url,
      {void Function(double progress)? onProgress}) async {
    final temp = await getTemporaryDirectory();
    final file = File('${temp.path}/zhaochen_checkin_update.apk');
    if (await file.exists()) await file.delete();
    await Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 5),
    )).download(url, file.path, onReceiveProgress: (received, total) {
      if (total > 0) onProgress?.call(received / total);
    });
    final result = await OpenFile.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}
