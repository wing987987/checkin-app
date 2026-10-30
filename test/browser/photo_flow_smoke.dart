// A release-Web smoke test: exercises the real browser picker and watermarker
// without depending on the Flutter test runner's browser bootstrap.
import 'dart:async';
import 'dart:js_interop';
import 'dart:ui' as ui;

import 'package:checkin_app/core/utils/log_photo_picker_web.dart';
import 'package:checkin_app/core/utils/watermark_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawColor(const ui.Color(0xff4287a5), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(3200, 1600);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final bytes = data!.buffer.asUint8List();
    picture.dispose();
    image.dispose();

    for (final mode in ['immediate', 'cancel-first', 'no-change']) {
      final files =
          await pickLogPhotos(ImageSource.camera, activateInput: (input) {
        void deliver() {
          final transfer = web.DataTransfer();
          transfer.items.add(web.File([bytes.toJS].toJS, 'camera.png',
              web.FilePropertyBag(type: 'image/png')));
          input.files = transfer.files;
          if (mode != 'no-change') input.dispatchEvent(web.Event('change'));
        }

        if (mode == 'cancel-first') {
          input.dispatchEvent(web.Event('cancel'));
          Timer(const Duration(milliseconds: 400), deliver);
        } else {
          deliver();
        }
      });
      if (files.length != 1) {
        throw StateError('$mode: photo lost');
      }
      final result = await WatermarkUtils.addClockWatermark(
          await files.single.readAsBytes(), ['施工日志', '主管：测试', '2026-10-27']);
      if (result.bytes.isEmpty) {
        throw StateError('$mode: empty watermarked image');
      }
      final codec = await ui.instantiateImageCodec(result.bytes);
      final frame = await codec.getNextFrame();
      if (frame.image.width > 2200 || frame.image.height > 2200) {
        throw StateError('$mode: size limit failed');
      }
      final rgba = await frame.image.toByteData();
      // The watermark paints a dark panel at the top right; verify actual pixels.
      final offset = (20 * frame.image.width + frame.image.width - 30) * 4;
      if (rgba == null || rgba.getUint8(offset) >= 60) {
        throw StateError('$mode: watermark panel missing');
      }
      frame.image.dispose();
      codec.dispose();
    }
    web.document.body!.setAttribute('data-photo-test', 'PASS: 3 photo flows');
  } catch (error, stack) {
    web.document.body!.setAttribute('data-photo-test', 'FAIL: $error\n$stack');
  }
}
