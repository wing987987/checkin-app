import 'package:checkin_app/models/checkin_supervisor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses supervisor project assignments', () {
    final supervisor = CheckinSupervisor.fromJson({
      'id': 12,
      'username': 'supervisor_12',
      'realName': '项目主管',
      'phone': '13900000000',
      'status': 1,
      'projectIds': [3, 7],
    });

    expect(supervisor.id, 12);
    expect(supervisor.projectIds, [3, 7]);
    expect(supervisor.status, 1);
  });
}
