import 'dart:convert';
import 'dart:typed_data';
import 'package:checkin_app/core/network/dio_client.dart';
import 'package:checkin_app/features/management/construction_log_page.dart';
import 'package:checkin_app/features/management/project_management_page.dart';
import 'package:checkin_app/features/management/construction_log_history_page.dart';
import 'package:checkin_app/models/checkin_project.dart';
import 'package:checkin_app/models/user_info.dart';
import 'package:checkin_app/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends AuthProvider {
  final bool boss;
  _Auth({this.boss = false});
  @override
  UserInfo get currentUser => UserInfo(
      id: 1,
      username: 'supervisor',
      realName: '张主管',
      role: boss ? 'boss' : 'supervisor');
  @override
  bool get isSupervisor => !boss;
  @override
  bool get isBoss => boss;
}

class _Api implements HttpClientAdapter {
  final historyQueries = <Map<String, dynamic>>[];
  int summaryCalls = 0, saves = 0;
  int mineCalls = 0;
  Map<String, dynamic>? saved;
  bool submitted = false;
  Map<String, dynamic> get log => {
        'id': 8,
        'today': '2026-10-11',
        'logDate': '2026-10-11',
        'projectName': '测试施工项目',
        'supervisorName': '张主管',
        'supervisorId': 1,
        'submittedTime': '2026-10-11 18:00:00',
        'status': submitted ? 'submitted' : 'draft',
        'version': saves,
        'progress': saved?['progress'] ?? '',
        'plan': saved?['plan'] ?? '',
        'photos': <dynamic>[],
        if (submitted) 'attendance': summary
      };
  Map<String, dynamic> get summary => {
        'date': '2026-10-10',
        'expectedPeople': 8,
        'clockedPeople': 7,
        'pendingPeople': summaryCalls < 2 ? 1 : 0,
        'pendingCount': summaryCalls < 2 ? 1 : 0,
        'resolvedCount': summaryCalls < 2 ? 0 : 1,
        'workHours': 56,
        'overtimeHours': 0,
        'workUnits': 7
      };
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    dynamic data = <dynamic>[];
    if (options.path == '/api/ck/construction-logs') {
      historyQueries.add(Map.of(options.queryParameters));
      data = [
        {
          ...log,
          'status': 'submitted',
          'supervisorId': options.queryParameters['supervisorId'] ?? 1,
          'supervisorName':
              options.queryParameters['supervisorId'] == 2 ? '李主管' : '张主管'
        }
      ];
    } else if (options.path.endsWith('/authors')) {
      data = [
        {'id': 1, 'name': '张主管'},
        {'id': 2, 'name': '李主管'}
      ];
    } else if (options.path.endsWith('/mine')) {
      mineCalls++;
      data = log;
    } else if (options.path.endsWith('/attendance-summary')) {
      summaryCalls++;
      data = summary;
    } else if (options.path.contains('/draft?')) {
      saved = Map<String, dynamic>.from(options.data);
      saves++;
      data = log;
    } else if (options.path.endsWith('/8')) {
      submitted = true;
      data = log;
    }
    return ResponseBody.fromString(
        jsonEncode({'code': 200, 'message': '成功', 'data': data}), 200,
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
  Future<void> show(WidgetTester tester, Widget page,
      {double scale = 1, bool boss = false}) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: _Auth(boss: boss),
        child: MaterialApp(
            builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: page)));
    await tester.pumpAndSettle();
  }

  testWidgets('anomaly return refreshes summary and preserves written progress',
      (tester) async {
    await show(tester, const ConstructionLogPage(project: project));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '二层天花安装完成78%');
    await tester.tap(find.text('处理昨日异常'));
    await tester.pumpAndSettle();
    expect(api.saved?['progress'], '二层天花安装完成78%');
    expect(find.text('2026-10-10 异常考勤'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(api.summaryCalls, 2);
    expect(find.text('二层天花安装完成78%'), findsOneWidget);
    expect(find.textContaining('待处理 0 人 / 0 条'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('submitted log is read only and displays frozen summary',
      (tester) async {
    await show(tester, const ConstructionLogPage(project: project, logId: 8));
    expect(find.text('提交日志'), findsNothing);
    expect(
        tester.widget<TextField>(find.byType(TextField).first).readOnly, true);
    expect(api.summaryCalls, 0);
    expect(find.text('以下为提交时保存的考勤情况'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('workbench tabs fit narrow screens with large text',
      (tester) async {
    await show(tester, const ProjectManagementPage(project: project),
        scale: 1.4);
    expect(find.text('我的今日日志'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('记录'));
    await tester.pumpAndSettle();
    expect(find.text('历史施工日志'), findsOneWidget);
    await tester.tap(find.text('管理'));
    await tester.pumpAndSettle();
    expect(find.text('班组管理'), findsOneWidget);
    expect(find.text('班次设置'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'history supervisor filtering queries server rather than recent local results',
      (tester) async {
    await show(tester, const ConstructionLogHistoryPage(project: project));
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('李主管').last);
    await tester.pumpAndSettle();
    expect(api.historyQueries.last['supervisorId'], 2);
    expect(find.text('2026-10-11'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '李主管'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'boss opens project logs without personal log or writing reminder',
      (tester) async {
    await show(tester, const ProjectManagementPage(project: project),
        boss: true);
    expect(find.text('我的今日日志'), findsNothing);
    expect(api.mineCalls, 0);
    await tester.ensureVisible(find.text('项目施工日志'));
    await tester.tap(find.text('项目施工日志'));
    await tester.pumpAndSettle();
    expect(api.historyQueries.last.containsKey('supervisorId'), false);
    expect(find.text('2026-10-11'), findsOneWidget);
    expect(find.widgetWithText(ListTile, '张主管'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
