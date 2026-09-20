import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checkin_app/features/management/job_type_management_page.dart';

void main() {
  testWidgets(
      'saving a job type closes the dialog without a disposed controller',
      (tester) async {
    String? savedName;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
            builder: (context) => TextButton(
                  onPressed: () async {
                    savedName = await showDialog<String>(
                      context: context,
                      builder: (_) =>
                          const JobTypeNameDialog(initialName: '木工'),
                    );
                  },
                  child: const Text('打开'),
                )),
      ),
    ));

    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), ' 油漆 ');
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(savedName, '油漆');
    expect(tester.takeException(), isNull);
  });
}
