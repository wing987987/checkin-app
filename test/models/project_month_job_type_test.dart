import 'package:checkin_app/models/attendance_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monthly workers group by job type without changing project totals', () {
    final report = ProjectMonthReport.fromJson({
      'month': '2026-09',
      'projectName': '测试项目',
      'totalWorkHours': 24,
      'workers': [
        {'workerId': 1, 'workerName': '张', 'jobType': '木工', 'workHours': 8},
        {'workerId': 2, 'workerName': '李', 'jobType': '瓦工', 'workHours': 6},
        {'workerId': 3, 'workerName': '王', 'jobType': '木工', 'workHours': 10},
      ],
    });

    expect(report.totalWorkHours, 24);
    expect(report.workersByJobType.keys, ['木工', '瓦工']);
    expect(report.workersByJobType['木工']!.length, 2);
    expect(report.workersByJobType['木工']!
        .fold<double>(0, (sum, worker) => sum + worker.workHours), 18);
    expect(report.workersByJobType['瓦工']!.single.workHours, 6);
  });

  test('unassigned historical worker remains visible', () {
    final report = ProjectMonthReport.fromJson({
      'workers': [
        {'workerId': 9, 'workerName': '旧工人', 'workHours': 8},
      ],
    });
    expect(report.workersByJobType['未设置工种']!.single.workerName, '旧工人');
  });
}
