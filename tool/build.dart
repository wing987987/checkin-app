import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

const _bucket = 'zhaocheng-app';
const _endpoint = 'oss-cn-beijing.aliyuncs.com';
const _domain = 'zhaochengapp.zhaochen-construction.com';
String get _accessKey => Platform.environment['OSS_ACCESS_KEY_ID']?.trim() ?? '';
String get _accessSecret =>
    Platform.environment['OSS_ACCESS_KEY_SECRET']?.trim() ?? '';

Future<void> main(List<String> args) async {
  if (args.isEmpty) _fail('用法: dart run tool/build.dart <test|prod|bump>');
  switch (args.first) {
    case 'test':
      await _release('test', 'staging');
      break;
    case 'prod':
      await _release('prod', 'prod');
      break;
    case 'bump':
      _bump(args.length > 1 ? args[1] : '--build');
      break;
    default:
      _fail('只支持 test、prod 或 bump');
  }
}

Future<void> _release(String env, String flavor) async {
  if (_accessKey.isEmpty || _accessSecret.isEmpty) {
    _fail('缺少 OSS 发布密钥，请配置 tool/oss-credentials.local.bat');
  }
  final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
  print('正在构建 $env 环境……');
  final result = await Process.start(
      flutter,
      [
        'build',
        'apk',
        '--flavor',
        flavor,
        '--dart-define=ENV=$env',
        '--release'
      ],
      mode: ProcessStartMode.inheritStdio);
  if (await result.exitCode != 0) _fail('构建失败');

  final apkDir = Directory('build/app/outputs/flutter-apk');
  final expected = File('${apkDir.path}/app-$flavor-release.apk');
  final apk = expected.existsSync()
      ? expected
      : (apkDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('-release.apk'))
              .toList()
            ..sort(
                (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync())))
          .first;
  final (name, code) = _readVersion();
  final prefix = 'apps/checkin/$env';
  final apkKey = '$prefix/app.apk';
  final versionKey = '$prefix/version.json';

  print('正在上传 APK 到 $apkKey……');
  await _put(apkKey, apk, 'application/vnd.android.package-archive');
  final versionFile = File('${Directory.systemTemp.path}/checkin-version.json');
  versionFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
    'versionCode': code,
    'versionName': name,
    'downloadUrl': 'https://$_domain/$apkKey',
    'releaseNotes': '版本 $name 更新',
    'forceUpdate': false,
  }));
  print('正在上传版本信息到 $versionKey……');
  await _put(versionKey, versionFile, 'application/json');
  print('\n发布完成：v$name+$code');
  print('APK: https://$_domain/$apkKey');
  print('版本: https://$_domain/$versionKey');
}

Future<void> _put(String objectKey, File file, String contentType) async {
  final bytes = await file.readAsBytes();
  final date = HttpDate.format(DateTime.now().toUtc());
  final resource = '/$_bucket/$objectKey';
  final source = 'PUT\n\n$contentType\n$date\n$resource';
  final signature = base64.encode(Hmac(sha1, utf8.encode(_accessSecret))
      .convert(utf8.encode(source))
      .bytes);
  final response = await Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    sendTimeout: const Duration(minutes: 5),
  )).put('https://$_bucket.$_endpoint/$objectKey',
      data: Stream.fromIterable([bytes]),
      options: Options(headers: {
        HttpHeaders.contentLengthHeader: bytes.length,
        HttpHeaders.contentTypeHeader: contentType,
        HttpHeaders.dateHeader: date,
        'Authorization': 'OSS $_accessKey:$signature',
      }));
  if (response.statusCode != 200) _fail('OSS 上传失败：${response.statusCode}');
}

(String, int) _readVersion() {
  final match =
      RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)$', multiLine: true)
          .firstMatch(File('pubspec.yaml').readAsStringSync());
  if (match == null) _fail('无法读取 pubspec.yaml 版本');
  return (
    '${match.group(1)}.${match.group(2)}.${match.group(3)}',
    int.parse(match.group(4)!)
  );
}

void _bump(String type) {
  final file = File('pubspec.yaml');
  final content = file.readAsStringSync();
  final regex =
      RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)$', multiLine: true);
  final match = regex.firstMatch(content);
  if (match == null) _fail('无法读取 pubspec.yaml 版本');
  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  var build = int.parse(match.group(4)!) + 1;
  if (type == '--patch') patch++;
  if (type == '--minor') {
    minor++;
    patch = 0;
  }
  if (type == '--major') {
    major++;
    minor = 0;
    patch = 0;
  }
  final version = '$major.$minor.$patch+$build';
  file.writeAsStringSync(content.replaceFirst(regex, 'version: $version'));
  print('版本号已更新：$version');
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
