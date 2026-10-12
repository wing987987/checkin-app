import 'package:checkin_app/services/log_reminder_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  final service = LogReminderService.instance;
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getNotificationAppLaunchDetails') {
        return {'notificationLaunchedApp': false};
      }
      if (call.method == 'initialize' ||
          call.method == 'requestNotificationsPermission') {
        return true;
      }
      return null;
    });
  });
  tearDown(() async {
    await service.clear();
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
  test('multiple projects produce one daily reminder in Beijing time',
      () async {
    await service.sync(1, [10, 20]);
    final scheduled = calls.where((c) => c.method == 'zonedSchedule').toList();
    expect(scheduled, hasLength(1));
    expect(scheduled.single.arguments['timeZoneName'], 'Asia/Shanghai');
    expect(
        scheduled.single.arguments['scheduledDateTime'], contains('T18:00:00'));
    expect(scheduled.single.arguments['matchDateTimeComponents'], 0);
  });
  test('completion of all projects moves reminder to tomorrow', () async {
    final today = DateTime.now().toUtc().add(const Duration(hours: 8));
    final date =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await service.sync(1, [10, 20]);
    await service.markSubmitted(1, 10, date);
    await service.markSubmitted(1, 20, date);
    final tomorrow = today.add(const Duration(days: 1));
    final prefix =
        '${tomorrow.year}-${tomorrow.month.toString().padLeft(2, '0')}-${tomorrow.day.toString().padLeft(2, '0')}';
    final last = calls.lastWhere((c) => c.method == 'zonedSchedule');
    expect(last.arguments['scheduledDateTime'], startsWith(prefix));
  });
  test('disabling reminder cancels notifications without rescheduling',
      () async {
    await service.sync(1, [10]);
    calls.clear();
    expect(
        await service.configure(
            1, false, const TimeOfDay(hour: 19, minute: 30)),
        true);
    expect(calls.where((c) => c.method == 'cancelAll'), isNotEmpty);
    expect(calls.where((c) => c.method == 'zonedSchedule'), isEmpty);
  });
  test('account switch resets completion and logout cancels reminders',
      () async {
    await service.sync(1, [10]);
    await service.clear();
    calls.clear();
    await service.sync(2, [20]);
    expect(calls.where((c) => c.method == 'zonedSchedule'), hasLength(1));
    calls.clear();
    await service.clear();
    expect(calls.where((c) => c.method == 'cancelAll'), hasLength(1));
  });
}
