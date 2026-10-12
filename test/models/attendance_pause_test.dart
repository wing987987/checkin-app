import 'package:flutter_test/flutter_test.dart';
import 'package:checkin_app/models/my_schedule.dart';

void main() {
  MySchedule schedule(String start, String? end) => MySchedule.fromJson({
        'projectId': 1,
        'shiftId': 1,
        'gpsLat': 0,
        'gpsLng': 0,
        'allowOutsideClockWindow': true,
        'pauseStartAt': start,
        'resumeAt': end,
        'clockPaused': true,
      });
  test('scheduled pause and restoration use exact Beijing boundaries', () {
    final value =
        schedule('2026-10-12T00:00:00+08:00', '2026-10-13T00:00:00+08:00');
    expect(
        value.canClockAt(DateTime.parse('2026-10-11T23:59:59+08:00')), isTrue);
    expect(
        value.canClockAt(DateTime.parse('2026-10-12T00:00:00+08:00')), isFalse);
    expect(
        value.canClockAt(DateTime.parse('2026-10-13T00:00:00+08:00')), isTrue);
  });
  test('pause overrides unrestricted test clock windows', () {
    final value = schedule('2026-10-11T14:00:00+08:00', null);
    expect(
        value.canClockAt(DateTime.parse('2026-10-11T14:00:01+08:00')), isFalse);
  });
}
