import 'package:flutter_test/flutter_test.dart';
import 'package:checkin_app/models/my_schedule.dart';

void main() {
  MySchedule schedule({bool allow = false, bool punched = false}) =>
      MySchedule.fromJson({
        'projectId': 1,
        'shiftId': 2,
        'gpsLat': 0,
        'gpsLng': 0,
        'attendanceDate': '2026-10-06',
        'allowOutsideClockWindow': allow,
        'checkpoints': [
          {'id': 3, 'code': 'afternoon_in', 'expectedTime': '13:00:00'}
        ],
        'records': punched
            ? [
                {'id': 4, 'checkpointId': 99, 'checkpointCode': 'afternoon_in'}
              ]
            : [],
      });
  test(
      'strict policy includes boundaries and rejects outside before photography',
      () {
    final value = schedule();
    expect(value.canClockAt(DateTime(2026, 10, 6, 12, 30)), isTrue);
    expect(value.canClockAt(DateTime(2026, 10, 6, 13, 5)), isTrue);
    expect(value.canClockAt(DateTime(2026, 10, 6, 12, 29, 59)), isFalse);
    expect(value.canClockAt(DateTime(2026, 10, 6, 13, 5, 1)), isFalse);
  });
  test(
      'optional policy permits outside and historical node code prevents duplicate',
      () {
    expect(schedule(allow: true).canClockAt(DateTime(2026, 10, 6, 14)), isTrue);
    expect(
        schedule(punched: true).canClockAt(DateTime(2026, 10, 6, 13)), isFalse);
  });
}
