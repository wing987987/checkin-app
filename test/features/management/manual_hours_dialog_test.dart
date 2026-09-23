import 'package:checkin_app/core/models/api_result.dart';
import 'package:checkin_app/features/management/anomaly_list_page.dart';
import 'package:checkin_app/models/attendance_anomaly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final item = AttendanceAnomaly(
    referenceRecordId: 1,
    workerId: 2,
    projectId: 3,
    teamId: 4,
    shiftId: 5,
    workerName: '张师傅',
    teamName: '一班',
    shiftName: '标准白班',
    checkpointName: '附加班次待确认',
    attendanceDate: '2026-09-23',
    clockTime: '',
    expectedTime: '',
    expectedDayOffset: 0,
    distanceMeters: 0,
    anomalyMessage: '',
    anomalyType: 'extra_shift_pending',
    resolved: false,
    corrected: false,
    missing: true,
  );
  testWidgets('saving half work closes without using disposed controllers',
      (tester) async {
    Map<String, dynamic>? submitted;
    bool? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await showDialog<bool>(
                      context: context,
                      builder: (_) => ManualHoursDialog(
                        item: item,
                        save: (data) async {
                          submitted = data;
                          return ApiResult<dynamic>(code: 200, message: '成功');
                        },
                      ),
                    );
                  },
                  child: const Text('打开'),
                )),
      ),
    ));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '4');
    await tester.enterText(find.byType(TextField).at(2), '主管核实半天');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, true);
    expect(submitted?['workHours'], 4);
    expect(submitted?['workUnits'], 0.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('supervisor can confirm zero work units', (tester) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => ManualHoursDialog(
                      item: item,
                      save: (data) async {
                        submitted = data;
                        return ApiResult<dynamic>(code: 200, message: '成功');
                      },
                    ),
                  ),
                  child: const Text('打开'),
                )),
      ),
    ));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '0');
    await tester.enterText(find.byType(TextField).at(1), '0');
    await tester.enterText(find.byType(TextField).at(2), '记录有问题');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    expect(submitted?['workUnits'], 0);
    expect(submitted?['workHours'], 0);
    expect(tester.takeException(), isNull);
  });
}
