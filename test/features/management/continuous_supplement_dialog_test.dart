import 'dart:async';

import 'package:checkin_app/core/models/api_result.dart';
import 'package:checkin_app/features/management/continuous_supplement_dialog.dart';
import 'package:checkin_app/models/attendance_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final day = DailyAttendance.fromJson({
    'workerId': 2,
    'projectId': 3,
    'teamId': 4,
    'shiftId': 5,
    'workerName': '张师傅',
    'attendanceDate': '2026-09-23',
    'clocks': [
      {'checkpointId': 11, 'checkpointName': '上午上班', 'expectedTime': '08:00'},
      {'checkpointId': 12, 'checkpointName': '上午下班', 'expectedTime': '12:00'},
      {
        'checkpointId': 13,
        'checkpointName': '下午上班',
        'expectedTime': '13:00',
        'recordId': 90,
        'status': 'normal'
      },
      {
        'checkpointId': 14,
        'checkpointName': '次日下班',
        'expectedTime': '02:00',
        'expectedDayOffset': 1
      },
    ],
  });

  Future<void> open(
      WidgetTester tester,
      Future<ApiResult<dynamic>> Function(Map<String, dynamic>) save,
      void Function(int?) finished) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
      builder: (context) => TextButton(
          onPressed: () async {
            finished(await showDialog<int>(
                context: context,
                barrierDismissible: false,
                builder: (_) => ContinuousSupplementDialog(
                    day: day, firstClock: day.clocks.first, save: save)));
          },
          child: const Text('开始')),
    ))));
    await tester.tap(find.text('开始'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '忘记打卡');
  }

  testWidgets(
      'continues in same dialog, keeps reason, skips existing clocks and respects overnight time',
      (tester) async {
    final requests = <Map<String, dynamic>>[];
    int? count;
    await open(tester, (data) async {
      requests.add(data);
      return ApiResult(code: 200, message: '');
    }, (value) => count = value);
    await tester.tap(find.text('保存并补下一项'));
    await tester.pumpAndSettle();
    expect(find.text('张师傅 · 上午下班补卡'), findsOneWidget);
    expect(find.text('忘记打卡'), findsOneWidget);
    expect(count, isNull);
    await tester.tap(find.text('保存并补下一项'));
    await tester.pumpAndSettle();
    expect(find.text('2026-09-24 02:00'), findsOneWidget);
    await tester.tap(find.text('保存并完成'));
    await tester.pumpAndSettle();
    expect(count, 3);
    expect(requests.map((r) => r['checkpointId']), [11, 12, 14]);
    expect(
        requests.every((r) =>
            r['reason'] == '忘记打卡' &&
            r['attendanceDate'] == '2026-09-23' &&
            r['workerId'] == 2),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed save stays on node and exit returns already saved count',
      (tester) async {
    var calls = 0;
    int? count;
    await open(
        tester,
        (_) async => ApiResult(code: ++calls == 1 ? 200 : 400, message: '保存失败'),
        (value) => count = value);
    await tester.tap(find.text('保存并补下一项'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('保存并补下一项'));
    await tester.pumpAndSettle();
    expect(find.text('张师傅 · 上午下班补卡'), findsOneWidget);
    expect(find.text('保存失败'), findsOneWidget);
    await tester.tap(find.text('退出补卡'));
    await tester.pumpAndSettle();
    expect(count, 1);
  });

  testWidgets(
      'saving prevents repeated submission and system back preserves saved count',
      (tester) async {
    final pending = Completer<ApiResult<dynamic>>();
    var calls = 0;
    int? count;
    await open(tester, (_) {
      calls++;
      return pending.future;
    }, (value) => count = value);
    await tester.tap(find.text('保存并补下一项'));
    await tester.pump();
    await tester.tap(find.text('保存中…'));
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(calls, 1);
    expect(count, isNull);
    pending.complete(ApiResult(code: 200, message: ''));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(count, 1);
  });
}
