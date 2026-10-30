import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class WatermarkedPhoto {
  final Uint8List bytes;
  final String filename;
  final String subtype;
  final int uncompressedBytes;
  final int compressedBytes;

  const WatermarkedPhoto({
    required this.bytes,
    required this.filename,
    required this.subtype,
    required this.uncompressedBytes,
    required this.compressedBytes,
  });

  int get reductionPercent => uncompressedBytes == 0
      ? 0
      : ((1 - compressedBytes / uncompressedBytes) * 100).round();
}

class WatermarkUtils {
  static Future<WatermarkedPhoto> addClockWatermark(
          Uint8List bytes, List<String> lines) =>
      _addClockWatermark(bytes, lines).timeout(const Duration(seconds: 45));

  static Future<WatermarkedPhoto> _addClockWatermark(
      Uint8List bytes, List<String> lines) async {
    final original = await _decode(bytes);
    try {
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
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 3)
                    ])),
            textDirection: TextDirection.ltr);
        p.layout(maxWidth: original.width * .62);
        return p;
      }).toList();
      final width =
          painters.fold<double>(0, (v, p) => p.width > v ? p.width : v) + 24;
      final height = painters.fold<double>(16, (v, p) => v + p.height + 4);
      final left = original.width - width - 16, top = 16.0;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(left, top, width, height),
              const Radius.circular(8)),
          Paint()..color = Colors.black.withValues(alpha: .48));
      var y = top + 8;
      for (final p in painters) {
        p.paint(canvas, Offset(left + 12, y));
        y += p.height + 4;
      }
      final picture = recorder.endRecording();
      final ui.Image image;
      try {
        image = await picture.toImage(original.width, original.height);
      } finally {
        picture.dispose();
        for (final painter in painters) {
          painter.dispose();
        }
      }
      try {
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final uncompressed = data!.buffer.asUint8List();
        Uint8List compressed = uncompressed;
        // 浏览器无法访问本地临时文件；直接使用内存图片上传。
        // Web 压缩插件不可用时保留 PNG，服务端同时接受 JPEG 和 PNG。
        var isJpeg = false;
        try {
          for (final quality in const [86, 82, 78, 74]) {
            final candidate = await FlutterImageCompress.compressWithList(
              uncompressed,
              quality: quality,
              format: CompressFormat.jpeg,
            ).timeout(const Duration(seconds: 10));
            if (candidate.isEmpty) break;
            compressed = candidate;
            isJpeg = true;
            if (compressed.length <= 900 * 1024) break;
          }
        } catch (_) {
          if (!kIsWeb) rethrow;
          compressed = uncompressed;
          isJpeg = false;
        }
        return WatermarkedPhoto(
          bytes: compressed,
          filename: isJpeg ? 'clock.jpg' : 'clock.png',
          subtype: isJpeg ? 'jpeg' : 'png',
          uncompressedBytes: uncompressed.length,
          compressedBytes: compressed.length,
        );
      } finally {
        image.dispose();
      }
    } finally {
      original.dispose();
    }
  }

  static Future<ui.Image> _decode(Uint8List bytes) async {
    // The callback-only decoder never completes on invalid/unsupported images.
    // Decode to a bounded size before allocating watermark canvases on mobile.
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    // This API owns/disposes buffer and obtains intrinsic dimensions on both
    // native and Web. Encoded ImageDescriptor.width/height throw on Web.
    final codec = await ui.instantiateImageCodecWithSize(buffer,
        getTargetSize: (width, height) {
      const maxDimension = 2200;
      final longest = width > height ? width : height;
      final scale = longest > maxDimension ? maxDimension / longest : 1.0;
      return ui.TargetImageSize(
        width: (width * scale).round().clamp(1, maxDimension),
        height: (height * scale).round().clamp(1, maxDimension),
      );
    });
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
