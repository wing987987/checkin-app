import 'dart:convert';
import 'dart:typed_data';
import 'package:checkin_app/core/network/dio_client.dart';
import 'package:checkin_app/features/management/secondment_page.dart';
import 'package:checkin_app/models/checkin_project.dart';
import 'package:checkin_app/models/worker_assignment.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Api implements HttpClientAdapter {
  RequestOptions? saved;
  bool fail = false;
  @override
  Future<ResponseBody> fetch(RequestOptions request, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    Object? data;
    if (request.method == 'POST') {
      saved = request;
    } else if (request.path.endsWith('/projects')) {
      data = [
        {'id': 20, 'name': 'B项目', 'status': 'active', 'gpsLat': 0, 'gpsLng': 0}
      ];
    } else if (request.path.endsWith('/teams')) {
      data = [
        {'id': 21, 'projectId': 20, 'name': 'B班组', 'shiftId': 22}
      ];
    } else if (request.path.endsWith('/shifts')) {
      data = [
        {'id': 22, 'projectId': 20, 'name': 'B白班', 'shiftType': 'day'}
      ];
    }
    return ResponseBody.fromString(
        jsonEncode({
          'code': fail && request.method == 'POST' ? 400 : 200,
          'message': '已有打卡不能覆盖',
          'data': data
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
      name: 'A项目',
      gpsLat: 0,
      gpsLng: 0,
      fenceRadius: 100,
      status: 'active');
  final worker = WorkerAssignment.fromJson(
      {'workerId': 2, 'projectId': 10, 'realName': '工人'});
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('start sends afternoon without an end date', (tester) async {
    final api = _Api();
    DioClient.instance.dio.httpClientAdapter = api;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SecondmentDialog(project: project, worker: worker))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B项目').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('B班组').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('下午开始'));
    await tester.tap(find.text('下午开始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认开始借调'));
    await tester.pumpAndSettle();
    expect(api.saved?.path, '/api/ck/workers/2/secondments');
    expect(api.saved?.data['half'], 1);
    expect(api.saved?.data['projectId'], 20);
    expect(api.saved?.data['shiftId'], 22);
    expect((api.saved?.data as Map).containsKey('endDate'), isFalse);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'return afternoon shows original project and leaves conflict visible',
      (tester) async {
    final api = _Api()..fail = true;
    DioClient.instance.dio.httpClientAdapter = api;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = DateTime.now().toIso8601String().split('T').first;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SecondmentDialog(project: project, loan: {
      'id': 9,
      'worker_id': 2,
      'start_date': today,
      'start_half': 0,
      'source_project_name': 'A项目',
      'source_team_name': '原班组',
      'source_shift_name': '原白班'
    }))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('下午起返回'));
    await tester.pumpAndSettle();
    expect(find.textContaining('A项目 / 原班组 / 原白班'), findsOneWidget);
    await tester.tap(find.text('确认返回'));
    await tester.pumpAndSettle();
    expect(api.saved?.path, '/api/ck/secondments/9/end');
    expect(api.saved?.data['half'], 1);
    expect(find.text('已有打卡不能覆盖'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
