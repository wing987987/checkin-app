import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class WatermarkedPhoto {
  final String path;
  final int uncompressedBytes;
  final int compressedBytes;

  const WatermarkedPhoto({
    required this.path,
    required this.uncompressedBytes,
    required this.compressedBytes,
  });

  int get reductionPercent => uncompressedBytes == 0
      ? 0
      : ((1 - compressedBytes / uncompressedBytes) * 100).round();
}

class WatermarkUtils {
  static Future<WatermarkedPhoto> addClockWatermark(
      Uint8List bytes, List<String> lines) async {
    final original = await _decode(bytes);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(original, Offset.zero, Paint());
    final fontSize = (original.width / 32).clamp(22, 42).toDouble();
    final painters = lines.map((line) {
      final p = TextPainter(
          text: TextSpan(
              text: line,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
          textDirection: TextDirection.ltr);
      p.layout(maxWidth: original.width * .62);
      return p;
    }).toList();
    final width =
        painters.fold<double>(0, (v, p) => p.width > v ? p.width : v) + 24;
    final height = painters.fold<double>(16, (v, p) => v + p.height + 4);
    final left = original.width - width - 16, top = 16.0;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(left, top, width, height), const Radius.circular(8)),
        Paint()..color = Colors.black.withValues(alpha: .48));
    var y = top + 8;
    for (final p in painters) {
      p.paint(canvas, Offset(left + 12, y));
      y += p.height + 4;
    }
    final image =
        await recorder.endRecording().toImage(original.width, original.height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final uncompressed = data!.buffer.asUint8List();
    Uint8List compressed = uncompressed;
    // 水印合成后的 PNG 通常很大。逐级降低 JPEG 质量，优先保持 86 的高画质，
    // 仅在文件仍超过 900 KB 时继续压缩，最低质量 74。
    for (final quality in const [86, 82, 78, 74]) {
      compressed = await FlutterImageCompress.compressWithList(
        uncompressed,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      if (compressed.length <= 900 * 1024) break;
    }
    final dir = await getTemporaryDirectory();
    final file = File(
        '${dir.path}${Platform.pathSeparator}clock_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(compressed, flush: true);
    return WatermarkedPhoto(
      path: file.path,
      uncompressedBytes: uncompressed.length,
      compressedBytes: compressed.length,
    );
  }

  static Future<ui.Image> _decode(Uint8List bytes) {
    final c = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, c.complete);
    return c.future;
  }
}
