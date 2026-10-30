import 'dart:async';
import 'dart:typed_data';
import 'package:checkin_app/core/utils/watermark_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unsupported photo returns an error instead of waiting forever',
      () async {
    await expectLater(
      WatermarkUtils.addClockWatermark(Uint8List.fromList([1, 2, 3]), ['日志'])
          .timeout(const Duration(seconds: 2)),
      throwsA(isNot(isA<TimeoutException>())),
    );
  });
}
