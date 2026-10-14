import 'package:checkin_app/core/network/dio_client.dart';
import 'package:checkin_app/core/widgets/log_reminder_host.dart';
import 'package:checkin_app/models/user_info.dart';
import 'package:checkin_app/providers/auth_provider.dart';
import 'package:checkin_app/services/log_reminder_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthProvider {
  final String accountRole;
  _Auth(this.accountRole);
  @override
  UserInfo get currentUser =>
      UserInfo(id: 1, username: 'user', realName: '用户', role: accountRole);
  @override
  bool get isSupervisor => accountRole == 'supervisor';
}

class _Api implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    return ResponseBody.fromString(
        '{"code":200,"message":"成功","data":{"status":"draft","today":"2026-10-14"}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final service = LogReminderService.instance;
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'initialize') return true;
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      return null;
    });
  });
  tearDown(() async {
    await service.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  Future<void> show(
      WidgetTester tester, String role, DateTime Function() clock) async {
    await tester.runAsync(() => service.sync(1, [10]));
    DioClient.instance.dio.httpClientAdapter = _Api();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: _Auth(role),
        child: MaterialApp(
            builder: (_, child) => LogReminderHost(clock: clock, child: child!),
            home: const Scaffold(body: Text('任意业务页面')))));
    await tester.pumpAndSettle();
  }

  testWidgets('foreground supervisor receives reminder at 17:00 on any route',
      (tester) async {
    var now = DateTime.utc(2026, 10, 14, 8, 59);
    await show(tester, 'supervisor', () => now);
    expect(find.text('施工日志填写提醒'), findsNothing);
    now = DateTime.utc(2026, 10, 14, 9);
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();
    expect(find.text('施工日志填写提醒'), findsOneWidget);
    expect(find.text('任意业务页面'), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('施工日志填写提醒'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('boss and workers never receive the in-app writing reminder',
      (tester) async {
    for (final role in ['boss', 'worker']) {
      await show(tester, role, () => DateTime.utc(2026, 10, 14, 10));
      expect(find.text('施工日志填写提醒'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });
}
