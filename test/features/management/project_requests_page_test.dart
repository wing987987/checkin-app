import 'package:checkin_app/core/models/api_result.dart';
import 'package:checkin_app/features/management/project_requests_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final action in ['approve', 'reject']) {
    testWidgets('$action without reason updates pending count and history',
        (tester) async {
      String status = 'pending';
      int calls = 0;
      await tester.pumpWidget(MaterialApp(
          home: ProjectRequestsPage(
        load: () async => ApiResult<List<Map<String, dynamic>>>(
            code: 200,
            message: '成功',
            data: [
              {
                'id': 99,
                'supervisorName': '张主管',
                'username': '13800000000',
                'projectName': 'B项目',
                'createTime': '2026-10-21 15:00:00',
                'status': status,
                'actorName': '老总',
              }
            ]),
        decide: (id, decision) async {
          calls++;
          expect(id, 99);
          expect(decision, action);
          status = decision == 'approve' ? 'approved' : 'rejected';
          return ApiResult<dynamic>(code: 200, message: '成功');
        },
      )));
      await tester.pumpAndSettle();
      expect(find.text('待处理 (1)'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text(action == 'approve' ? '同意' : '拒绝'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('待处理 (0)'), findsOneWidget);
      expect(find.text('暂无待处理申请'), findsOneWidget);
      await tester.tap(find.text('已处理'));
      await tester.pumpAndSettle();
      expect(find.textContaining(action == 'approve' ? '已同意' : '已拒绝'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('decision failure leaves pending request available',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: ProjectRequestsPage(
      load: () async => ApiResult<List<Map<String, dynamic>>>(
          code: 200,
          message: '成功',
          data: [
            {
              'id': 1,
              'status': 'pending',
              'supervisorName': '主管',
              'projectName': '项目'
            }
          ]),
      decide: (_, __) async =>
          ApiResult<dynamic>(code: 400, message: '申请已处理，请刷新列表'),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('同意'));
    await tester.pumpAndSettle();
    expect(find.text('申请已处理，请刷新列表'), findsOneWidget);
    expect(find.text('待处理 (1)'), findsOneWidget);
  });
}
