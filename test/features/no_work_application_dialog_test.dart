import 'package:checkin_app/core/widgets/no_work_application_dialog.dart';
import 'package:checkin_app/models/attendance_report.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'requires confirmation but reason is optional; cancellation does not submit',
      (tester) async {
    String? result;
    Future<void> open() async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
                  builder: (ctx) => TextButton(
                      onPressed: () async {
                        result = await showDialog<String>(
                            context: ctx,
                            builder: (_) => const NoWorkApplicationDialog(
                                date: '2026-09-01', shiftName: '夜班'));
                      },
                      child: const Text('申请'))))));
      await tester.tap(find.text('申请'));
      await tester.pumpAndSettle();
    }

    await open();
    expect(result, isNull);
    expect(find.textContaining('2026-09-01 · 夜班'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('申请'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认提交'));
    await tester.pumpAndSettle();
    expect(result, '');
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('申请'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  临时不出工  ');
    await tester.tap(find.text('确认提交'));
    await tester.pumpAndSettle();
    expect(result, '临时不出工');
  });
  test('new report flags parse and old responses remain compatible', () {
    final old = DailyAttendance.fromJson({});
    expect(old.canApplyNoWork, isFalse);
    expect(old.noWorkStatus, '');
    final pending = DailyAttendance.fromJson({
      'noWorkRequestId': 9,
      'noWorkStatus': 'pending',
      'canApplyNoWork': false,
      'status': 'no_work_pending',
      'workUnits': 0,
      'overtimeHours': 2.5
    });
    expect(pending.noWorkRequestId, 9);
    expect(pending.noWorkStatus, 'pending');
    expect(pending.workUnits, 0);
    expect(pending.overtimeHours, 2.5);
    expect(DailyAttendance.fromJson({'canApplyNoWork': true}).canApplyNoWork,
        isTrue);
  });
}
