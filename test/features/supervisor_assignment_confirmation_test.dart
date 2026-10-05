import 'package:checkin_app/core/widgets/supervisor_assignment_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'shows previous project and shift, cancellation retains assignment',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (ctx) => TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: ctx,
                          builder: (_) =>
                              const SupervisorAssignmentConfirmation(
                                  name: '张主管',
                                  project: '项目A',
                                  team: '木工班组',
                                  shift: '夜班',
                                  hours: '20:00～次日 05:30',
                                  newTeam: '白班班组'));
                    },
                    child: const Text('设置'))))));
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.textContaining('项目：项目A'), findsOneWidget);
    expect(find.textContaining('班次：夜班'), findsOneWidget);
    expect(find.textContaining('次日 05:30'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(result, false);
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确定更改'));
    await tester.pumpAndSettle();
    expect(result, true);
    expect(tester.takeException(), isNull);
  });
}
