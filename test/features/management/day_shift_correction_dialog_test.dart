import 'package:checkin_app/core/models/api_result.dart';
import 'package:checkin_app/features/management/day_shift_correction_dialog.dart';
import 'package:checkin_app/models/attendance_report.dart';
import 'package:checkin_app/models/checkin_shift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DailyAttendance day({bool partial = false}) => DailyAttendance.fromJson({
        'workerId': 2,
        'projectId': 10,
        'teamId': 20,
        'shiftId': 30,
        'workerName': '张师傅',
        'attendanceDate': '2026-10-20',
        'shiftName': '白班',
        'shiftType': 'day',
        'status': 'missing',
        'clocks': partial
            ? [
                {
                  'recordId': 1,
                  'checkpointName': '上午上班',
                  'expectedTime': '08:00:00',
                  'clockTime': '2026-10-20T08:00:00'
                }
              ]
            : [],
      });
  final shift = CheckinShift.fromJson({
    'id': 40,
    'projectId': 10,
    'name': '夜班',
    'shiftType': 'night',
    'startTime': '21:00:00',
    'endTime': '05:30:00',
    'crossDay': 1
  });
  Future<void> open(WidgetTester tester,
      {bool partial = false,
      required Future<ApiResult<dynamic>> Function(Map<String, dynamic>)
          save}) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => DayShiftCorrectionDialog(
                            day: day(partial: partial),
                            shifts: [shift],
                            save: save)),
                    child: const Text('打开'))))));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('夜班 21:00:00–次日 05:30:00').last);
    await tester.pumpAndSettle();
  }

  testWidgets('changes only selected day and supplies required reason',
      (tester) async {
    Map<String, dynamic>? data;
    await open(tester, save: (value) async {
      data = value;
      return ApiResult<dynamic>(code: 200, message: '成功');
    });
    await tester.tap(find.text('确认更正'));
    await tester.pumpAndSettle();
    expect(find.text('请填写更正原因'), findsOneWidget);
    expect(data, isNull);
    await tester.enterText(find.byType(TextField), '主管漏改夜班');
    await tester.tap(find.text('确认更正'));
    await tester.pumpAndSettle();
    expect(data?['attendanceDate'], '2026-10-20');
    expect(data?['previousShiftId'], 30);
    expect(data?['shiftId'], 40);
    expect(data?['reason'], '主管漏改夜班');
    expect(find.text('更正当天班次'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('partial original punches need explicit acknowledgement',
      (tester) async {
    Map<String, dynamic>? data;
    await open(tester, partial: true, save: (value) async {
      data = value;
      return ApiResult<dynamic>(code: 200, message: '成功');
    });
    await tester.enterText(find.byType(TextField), '原白班记录保留，按夜班补卡');
    await tester.tap(find.text('确认更正'));
    await tester.pumpAndSettle();
    expect(find.text('请确认原班次记录的处理方式'), findsOneWidget);
    expect(data, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认更正'));
    await tester.pumpAndSettle();
    expect(data?['acknowledgeOriginal'], true);
    expect(tester.takeException(), isNull);
  });
}
