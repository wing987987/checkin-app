import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class LogReminderService {
  static final instance = LogReminderService._();
  LogReminderService._();
  static final navigatorKey = GlobalKey<NavigatorState>();
  final taps = ValueNotifier<int>(0);
  final changes = ValueNotifier<int>(0);
  static const reminderTime = TimeOfDay(hour: 17, minute: 0);
  static DateTime beijingNow([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().add(const Duration(hours: 8));
  static String dateKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final _plugin = FlutterLocalNotificationsPlugin();
  int? _actor;
  List<int> _projects = [];
  bool _ready = false;
  bool _launchPending = false;
  Future<void> _queueTail = Future.value();
  Future<void> _queue(Future<void> Function() action) {
    final next = _queueTail.then((_) => action());
    _queueTail = next.catchError((Object _) {});
    return next;
  }

  bool consumeLaunch() {
    final value = _launchPending;
    _launchPending = false;
    return value;
  }

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void> initialize() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
        const InitializationSettings(
            android: AndroidInitializationSettings('ic_log_notification')),
        onDidReceiveNotificationResponse: (_) {
      taps.value++;
    });
    _ready = true;
    _launchPending = (await _plugin.getNotificationAppLaunchDetails())
            ?.didNotificationLaunchApp ??
        false;
  }

  Future<bool> enabled(int actor) async =>
      (await SharedPreferences.getInstance())
          .getBool('log_reminder_enabled_$actor') ??
      true;
  Future<TimeOfDay> time(int actor) async {
    return reminderTime;
  }

  Future<List<int>> pendingProjects(int actor, {DateTime? now}) async {
    if (_actor != actor) return [];
    final prefs = await SharedPreferences.getInstance();
    final date = dateKey(beijingNow(now));
    if (_actor != actor) return [];
    return _projects
        .where(
            (p) => prefs.getBool('log_submitted_${actor}_${p}_$date') != true)
        .toList();
  }

  Future<bool> shouldShowInApp(int actor, {DateTime? now}) async {
    final current = beijingNow(now);
    if (current.hour < reminderTime.hour || _actor != actor) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('log_reminder_seen_${actor}_${dateKey(current)}') ==
        true) {
      return false;
    }
    return (await pendingProjects(actor, now: now)).isNotEmpty;
  }

  Future<void> dismissInApp(int actor, {DateTime? now}) async {
    final current = beijingNow(now);
    if (current.hour < reminderTime.hour) return;
    await (await SharedPreferences.getInstance())
        .setBool('log_reminder_seen_${actor}_${dateKey(current)}', true);
    changes.value++;
  }

  Future<bool> configure(int actor, bool value, TimeOfDay time) async {
    if (!supported) return false;
    await initialize();
    if (value) {
      final granted = await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (granted != true) return false;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('log_reminder_enabled_$actor', value);
    await prefs.setInt('log_reminder_minutes_$actor', reminderTime.hour * 60);
    await sync(actor, _projects);
    return true;
  }

  Future<void> clear() => _queue(() async {
        _actor = null;
        _projects = [];
        changes.value++;
        if (supported) {
          await initialize();
          await _plugin.cancelAll();
        }
      });

  Future<void> markSubmitted(int actor, int project, String date) async {
    await (await SharedPreferences.getInstance())
        .setBool('log_submitted_${actor}_${project}_$date', true);
    if (_actor == actor) await sync(actor, _projects);
  }

  Future<void> sync(int actor, List<int> projectIds) =>
      _queue(() => _sync(actor, List.of(projectIds)));
  Future<void> _sync(int actor, List<int> projectIds) async {
    _actor = actor;
    _projects = List.of(projectIds);
    changes.value++;
    if (!supported) return;
    await initialize();
    await _plugin.cancelAll();
    if (!await enabled(actor) || projectIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final clock = await time(actor), zone = tz.getLocation('Asia/Shanghai');
    final now = tz.TZDateTime.now(zone);
    var at = tz.TZDateTime(
        zone, now.year, now.month, now.day, clock.hour, clock.minute);
    final date =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final pending = projectIds
        .where(
            (p) => prefs.getBool('log_submitted_${actor}_${p}_$date') != true)
        .length;
    if (!at.isAfter(now) || pending == 0) {
      at = tz.TZDateTime(
          zone, now.year, now.month, now.day + 1, clock.hour, clock.minute);
    }
    await _plugin.zonedSchedule(
        7000,
        '施工日志填写提醒',
        '已到17点，请填写并提交今日负责项目的施工日志',
        at,
        const NotificationDetails(
            android: AndroidNotificationDetails(
                'construction_log_1700_v2', '施工日志提醒',
                channelDescription: '每天17点提醒主管填写当天施工日志',
                importance: Importance.high,
                priority: Priority.high)),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'construction_logs');
  }
}
