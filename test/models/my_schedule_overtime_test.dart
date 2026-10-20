import 'package:flutter_test/flutter_test.dart';
import 'package:checkin_app/models/my_schedule.dart';

MySchedule schedule(String type, String code,
        {bool outside = false, bool done = false}) =>
    MySchedule.fromJson({
      'projectId': 1,
      'shiftId': 2,
      'gpsLat': 30,
      'gpsLng': 120,
      'shiftType': type,
      'attendanceDate': '2026-10-20',
      'allowOutsideClockWindow': outside,
      'checkpoints': [
        {
          'id': 5,
          'code': code,
          'name': '下班',
          'expectedTime': type == 'night' ? '05:00:00' : '17:00:00',
          'dayOffset': type == 'night' ? 1 : 0
        }
      ],
      'records': done
          ? [
              {
                'id': 1,
                'checkpointId': 5,
                'checkpointCode': code,
                'countable': 1
              }
            ]
          : [],
    });

void main() {
  test('final day clock-out stays open until midnight, exclusive', () {
    for (final outside in [false, true]) {
      final s = schedule('day', 'afternoon_out', outside: outside);
      expect(s.canClockAt(DateTime(2026, 10, 20, 23, 59, 59)), isTrue);
      expect(s.canClockAt(DateTime(2026, 10, 21)), isFalse);
    }
  });
  test('night clock-out stays open until following noon, exclusive', () {
    final s = schedule('night', 'end');
    expect(s.canClockAt(DateTime(2026, 10, 21, 11, 59, 59)), isTrue);
    expect(s.canClockAt(DateTime(2026, 10, 21, 12)), isFalse);
  });
  test('borrowed morning does not inherit final clock-out extension', () {
    final s = schedule('day', 'morning_out');
    expect(s.canClockAt(DateTime(2026, 10, 20, 17, 30)), isTrue);
    expect(s.canClockAt(DateTime(2026, 10, 20, 17, 31)), isFalse);
  });
  test('completed final clock-out cannot be submitted again', () {
    expect(
        schedule('day', 'end', done: true, outside: true)
            .canClockAt(DateTime(2026, 10, 20, 19)),
        isFalse);
  });
  test('early final clock-out still obeys five-minute window', () {
    final s = schedule('day', 'end');
    expect(s.canClockAt(DateTime(2026, 10, 20, 16, 54)), isFalse);
    expect(s.canClockAt(DateTime(2026, 10, 20, 16, 55)), isTrue);
  });
}
