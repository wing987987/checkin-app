import 'package:flutter/material.dart';
import 'dart:math' as math;

/// 支持双指缩放和拖动查看的网络图片。
class ZoomableNetworkImage extends StatelessWidget {
  final String url;
  final double height;

  const ZoomableNetworkImage({
    super.key,
    required this.url,
    this.height = 360,
  });

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final imageWidth = math.min(viewport.width * 0.78, 560.0);
    final imageHeight = math.min(height, viewport.height * 0.55);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: imageHeight,
        width: imageWidth,
        color: Colors.transparent,
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.network(
              url,
              width: imageWidth,
              height: imageHeight,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, __, ___) => const Center(child: Text('照片加载失败')),
            ),
          ),
        ),
      ),
    );
  }
}
