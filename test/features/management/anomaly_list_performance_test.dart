import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:checkin_app/core/network/dio_client.dart';
import 'package:checkin_app/core/theme/app_theme.dart';
import 'package:checkin_app/features/management/anomaly_list_page.dart';
import 'package:checkin_app/models/attendance_anomaly.dart';
import 'package:checkin_app/models/checkin_project.dart';
import 'package:checkin_app/models/user_info.dart';
import 'package:checkin_app/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Auth extends AuthProvider {
  @override
  UserInfo get currentUser =>
      UserInfo(id: 9999, username: 'boss', realName: '老总', role: 'boss');
}

class _Api implements HttpClientAdapter {
  int calls = 0;
  List<Map<String, dynamic>> pending = [];
  bool failSave = false;
  RequestOptions? savedRequest;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls++;
    if (options.method == 'POST') savedRequest = options;
    if (options.method == 'POST' && !failSave) {
      pending.removeWhere((item) =>
          item['shiftId'] == options.data['shiftId'] &&
          item['workerId'] == options.data['workerId'] &&
          item['attendanceDate'] == options.data['attendanceDate']);
    }
    return ResponseBody.fromString(
        jsonEncode({
          'code': failSave && options.method == 'POST' ? 400 : 200,
          'message': '测试结果',
          'data': options.method == 'GET' ? pending : null
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json']
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final fail in [false, true]) {
    testWidgets(
        'continuous day processing isolates worker/date and stops on failure=$fail',
        (tester) async {
      final api = _Api()..failSave = fail;
      Map<String, dynamic> row(int worker, String date, int shift) => {
            'workerId': worker,
            'projectId': 10,
            'shiftId': shift,
            'workerName': '工人$worker',
            'attendanceDate': date,
            'shiftName': '班次$shift',
            'missing': true,
            'anomalyType': 'missing_all',
          };
      api.pending = [
        row(2, '2026-10-11', 20),
        row(2, '2026-10-11', 21),
        row(3, '2026-10-11', 22),
        row(2, '2026-10-12', 23)
      ];
      DioClient.instance.dio.httpClientAdapter = api;
      const project = CheckinProject(
          id: 10,
          name: '项目',
          gpsLat: 0,
          gpsLng: 0,
          fenceRadius: 100,
          status: 'active');
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: _Auth(),
          child: MaterialApp(
              home: AnomalyListPage(
                  project: project,
                  initialItems:
                      api.pending.map(AttendanceAnomaly.fromJson).toList()))));
      await tester.tap(find.text('处理整班缺卡').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('确认保留整班缺卡'));
      await tester.pumpAndSettle();
      if (fail) {
        expect(find.byType(AlertDialog), findsNothing);
        expect(api.pending.length, 4);
      } else {
        expect(find.text('确认保留整班缺卡？'), findsOneWidget);
        expect(
            find.descendant(
                of: find.byType(AlertDialog),
                matching: find.textContaining('/ 班次21')),
            findsOneWidget);
        await tester.tap(find.text('暂不处理'));
        await tester.pumpAndSettle();
        expect(api.pending.length, 3);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.tap(find.text('处理整班缺卡').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('确认保留整班缺卡'));
        await tester.pumpAndSettle();
        expect(api.pending.length, 2);
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('工人2 · 2026-10-11 的异常已处理完成'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('whole missing shift offers retain or individual processing',
      (tester) async {
    final api = _Api();
    DioClient.instance.dio.httpClientAdapter = api;
    const project = CheckinProject(
        id: 10,
        name: '项目',
        gpsLat: 0,
        gpsLng: 0,
        fenceRadius: 100,
        status: 'active');
    final item = AttendanceAnomaly.fromJson({
      'workerId': 2,
      'projectId': 10,
      'shiftId': 20,
      'workerName': '工人',
      'attendanceDate': '2026-10-11',
      'missing': true,
      'anomalyType': 'missing_all'
    });
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: _Auth(),
        child: MaterialApp(
            home: AnomalyListPage(project: project, initialItems: [item]))));
    await tester.tap(find.text('处理整班缺卡'));
    await tester.pumpAndSettle();
    expect(find.text('确认保留整班缺卡？'), findsOneWidget);
    expect(find.text('逐个处理'), findsOneWidget);
    expect(api.calls, 0);
    await tester.tap(find.text('暂不处理'));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    await tester.tap(find.text('处理整班缺卡'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认保留整班缺卡'));
    await tester.pumpAndSettle();
    expect(
        api.savedRequest?.path, '/api/ck/attendance/missing/acknowledge-shift');
    expect(api.savedRequest?.data, {
      'workerId': 2,
      'projectId': 10,
      'shiftId': 20,
      'attendanceDate': '2026-10-11'
    });
    expect(find.text('没有待处理异常'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '300 missing anomalies use initial results and only build visible cards',
      (tester) async {
    final api = _Api();
    DioClient.instance.dio.httpClientAdapter = api;
    const project = CheckinProject(
        id: 10,
        name: '项目',
        gpsLat: 0,
        gpsLng: 0,
        fenceRadius: 100,
        status: 'active');
    final items = List.generate(
        300,
        (i) => AttendanceAnomaly.fromJson({
              'workerId': i + 1,
              'projectId': 10,
              'workerName': '工人${i + 1}',
              'attendanceDate': '2026-10-11',
              'missing': true,
              'anomalyType': 'missing_all',
              'checkpointName': '整班缺卡',
              'anomalyMessage': '整班缺卡',
            }));
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: _Auth(),
        child: MaterialApp(
            theme: AppTheme.light,
            home: AnomalyListPage(project: project, initialItems: items))));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(find.text('待处理 300 项'), findsOneWidget);
    expect(find.byType(Card).evaluate().length, lessThan(20));
    expect(find.textContaining('工人300'), findsNothing);
    await tester.drag(find.byType(ListView).first, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(api.calls, 0);
    expect(tester.takeException(), isNull);
  });
}
