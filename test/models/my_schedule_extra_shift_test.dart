import 'package:flutter_test/flutter_test.dart';
import 'package:checkin_app/models/my_schedule.dart';

void main() {
  test('parses a primary schedule with optional extra shifts', () {
    final schedule = MySchedule.fromJson({
      'projectId': 1,
      'projectName': '项目',
      'fenceRadius': 100,
      'gpsLat': 30,
      'gpsLng': 120,
      'teamName': '一组',
      'shiftId': 10,
      'shiftName': '白班',
      'shiftType': 'day',
      'startTime': '09:00:00',
      'endTime': '18:00:00',
      'attendanceDate': '2026-09-22',
      'checkpoints': [],
      'records': [],
      'extraShift': false,
      'extraSchedules': [
        {
          'projectId': 1,
          'projectName': '项目',
          'fenceRadius': 100,
          'gpsLat': 30,
          'gpsLng': 120,
          'teamName': '一组',
          'shiftId': 11,
          'shiftName': '夜班',
          'shiftType': 'night',
          'startTime': '21:00:00',
          'endTime': '05:00:00',
          'attendanceDate': '2026-09-22',
          'checkpoints': [],
          'records': [],
          'extraShift': true,
          'extraSchedules': [],
        }
      ],
    });

    expect(schedule.shiftName, '白班');
    expect(schedule.extraSchedules.single.shiftName, '夜班');
    expect(schedule.extraSchedules.single.extraShift, isTrue);
  });
}
