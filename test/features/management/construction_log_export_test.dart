import 'dart:convert';
import 'dart:typed_data';
import 'package:checkin_app/core/network/dio_client.dart';
import 'package:checkin_app/core/theme/app_theme.dart';
import 'package:checkin_app/features/management/construction_log_export_page.dart';
import 'package:checkin_app/models/checkin_project.dart';
import 'package:checkin_app/models/user_info.dart';
import 'package:checkin_app/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthProvider {
  @override
  UserInfo get currentUser => UserInfo(id: 1, username: 'boss', role: 'boss');
}

class _Api implements HttpClientAdapter {
  Map<String, dynamic>? submitted;
  String status = 'queued';
  int polls = 0;
  int code = 200;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (options.method == 'POST') {
      submitted = Map<String, dynamic>.from(options.data);
    } else {
      polls++;
    }
    return ResponseBody.fromString(
        jsonEncode({
          'code': code,
          'message': '所选范围没有已提交日志',
          'data': code == 200
              ? {
                  'id': 'task-1',
                  'status': status,
                  'startDate': '2026-10-07',
                  'endDate': '2026-10-13',
                  'processedCount': 2,
                  'logCount': 4,
                  'fileName': '施工日志.pdf',
                  'downloadUrl': 'https://example.invalid/test.pdf'
                }
              : null
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
  const project = CheckinProject(
      id: 10,
      name: '测试施工项目',
      gpsLat: 34,
      gpsLng: 113,
      fenceRadius: 100,
      status: 'active');
  late _Api api;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    api = _Api();
    DioClient.instance.dio.httpClientAdapter = api;
  });
  Future<void> show(WidgetTester tester, {int? supervisor}) async {
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: _Auth(),
        child: MaterialApp(
            theme: AppTheme.light,
            home: ConstructionLogExportPage(
                project: project,
                supervisorId: supervisor,
                supervisorName: supervisor == null ? null : '张主管'))));
    await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }

  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  test('defaults use seven Beijing calendar days ending yesterday', () {
    final range =
        ConstructionExportRange.defaults(DateTime.utc(2026, 10, 13, 18));
    expect(range.start, DateTime(2026, 10, 7));
    expect(range.end, DateTime(2026, 10, 13));
    expect(ConstructionExportRange.days(range), 7);
    expect(
        ConstructionExportRange.days(DateTimeRange(
            start: DateTime(2026, 9, 14), end: DateTime(2026, 10, 14))),
        31);
  });
  testWidgets(
      'boss can create filtered task with yesterday default and return later',
      (tester) async {
    await show(tester, supervisor: 2);
    expect(find.text('提交主管：张主管'), findsOneWidget);
    await tester.tap(find.text('生成PDF'));
    await flush(tester);
    final range = ConstructionExportRange.defaults(DateTime.now());
    expect(api.submitted!['startDate'],
        range.start.toIso8601String().substring(0, 10));
    expect(api.submitted!['endDate'],
        range.end.toIso8601String().substring(0, 10));
    expect(api.submitted!['supervisorId'], 2);
    expect(find.text('等待生成，正在排队'), findsOneWidget);
    expect(
        (tester.widget<FilledButton>(find
                .ancestor(
                    of: find.text('生成PDF'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first))
            .onPressed,
        isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('construction_pdf_task_1_10_2'), 'task-1');
    await tester.pumpWidget(const SizedBox());
    api.status = 'completed';
    await show(tester, supervisor: 2);
    await flush(tester);
    expect(find.text('PDF已生成，共 4 份日志'), findsOneWidget);
    expect(find.text('下载PDF'), findsOneWidget);
    expect(api.polls, greaterThan(0));
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'server validation message is visible and create remains available',
      (tester) async {
    api.code = 400;
    await show(tester);
    await tester.tap(find.text('生成PDF'));
    await flush(tester);
    expect(find.text('所选范围没有已提交日志'), findsOneWidget);
    expect(
        (tester.widget<FilledButton>(find
                .ancestor(
                    of: find.text('生成PDF'),
                    matching: find.byWidgetPredicate((w) => w is FilledButton))
                .first))
            .onPressed,
        isNotNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('expired restored task offers regeneration without download',
      (tester) async {
    SharedPreferences.setMockInitialValues(
        {'construction_pdf_task_1_10_all': 'task-1'});
    api.status = 'expired';
    await show(tester);
    await flush(tester);
    expect(find.text('文件已过期，请重新导出'), findsOneWidget);
    expect(find.text('下载PDF'), findsNothing);
    expect(find.text('生成PDF'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
