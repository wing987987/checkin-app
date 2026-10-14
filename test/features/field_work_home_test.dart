import 'dart:convert';
import 'dart:typed_data';
import 'package:checkin_app/core/network/dio_client.dart';
import 'package:checkin_app/core/theme/app_theme.dart';
import 'package:checkin_app/features/worker/worker_home_page.dart';
import 'package:checkin_app/models/user_info.dart';
import 'package:checkin_app/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthProvider {
  @override
  UserInfo get currentUser =>
      UserInfo(id: 1, username: 'worker', realName: '工人', role: 'worker');
}

class _Api implements HttpClientAdapter {
  final bool paused, started;
  _Api({this.paused = false, this.started = false});
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(
          jsonEncode({
            'code': 200,
            'message': '成功',
            'data': {
              'projectId': 10,
              'projectName': '项目',
              'gpsLat': 31,
              'gpsLng': 121,
              'fenceRadius': 100,
              'teamName': '班组',
              'shiftId': -7,
              'shiftName': '外勤',
              'shiftType': 'field',
              'startTime': '00:00',
              'endTime': '23:59',
              'attendanceDate': '2026-10-13',
              'fieldWork': true,
              'fieldReason': '客户现场施工',
              'allowOutsideClockWindow': true,
              'clockPaused': paused,
              'pauseStatus': paused ? 'paused' : 'active',
              if (paused) 'pauseStartAt': '2020-01-01T00:00:00+08:00',
              'checkpoints': [
                {
                  'id': -101,
                  'code': 'field_start',
                  'name': '外勤上班',
                  'expectedTime': '00:00',
                  'dayOffset': 0
                },
                {
                  'id': -102,
                  'code': 'field_end',
                  'name': '外勤下班',
                  'expectedTime': '23:59',
                  'dayOffset': 0
                }
              ],
              'records': started
                  ? [
                      {
                        'id': 11,
                        'checkpointId': -101,
                        'checkpointCode': 'field_start',
                        'checkpointName': '外勤上班',
                        'serverTime': '2026-10-13T08:00:00',
                        'countable': 1
                      }
                    ]
                  : [],
            }
          }),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json']
          });
  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> show(WidgetTester tester,
      {bool paused = false, bool started = false}) async {
    await tester.binding.setSurfaceSize(const Size(400, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    DioClient.instance.dio.httpClientAdapter =
        _Api(paused: paused, started: started);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: _Auth(),
        child: MaterialApp(
            theme: AppTheme.light,
            home: const WorkerHomePage(showBack: true))));
    await tester.pumpAndSettle();
  }

  testWidgets('field work exposes start/end only and end requires start',
      (tester) async {
    await show(tester);
    expect(find.text('今日外勤'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((w) => w is FilledButton))
            .onPressed,
        isNotNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byWidgetPredicate((w) => w is OutlinedButton))
            .onPressed,
        isNull);
    expect(find.textContaining('加班打卡（'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('after field start only end is available', (tester) async {
    await show(tester, started: true);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((w) => w is FilledButton))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byWidgetPredicate((w) => w is OutlinedButton))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('pause disables both field buttons', (tester) async {
    await show(tester, paused: true, started: true);
    expect(
        tester
            .widget<FilledButton>(
                find.byWidgetPredicate((w) => w is FilledButton))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byWidgetPredicate((w) => w is OutlinedButton))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
