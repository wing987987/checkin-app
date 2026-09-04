import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final double headerHeight;

  const AppBackground(
      {super.key, required this.child, this.headerHeight = 190});

  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(child: ColoredBox(color: AppColors.canvas)),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: headerHeight,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFEAF5FF),
                  Color(0xFFF3F7FF),
                  Color(0x00F8F8FA)
                ],
                stops: [0, .62, 1],
              ),
            ),
            child: const CustomPaint(painter: _BlueprintPainter()),
          ),
        ),
        Positioned.fill(child: child),
      ]);
}

class _BlueprintPainter extends CustomPainter {
  const _BlueprintPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: .045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14;
    canvas.drawCircle(Offset(size.width * .83, size.height * .28), 54, paint);
    paint.strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (.48 + i * .1);
      canvas.drawLine(
          Offset(size.width * .55, y), Offset(size.width, y - 34), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onRetry;

  const AppEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.description,
      this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 46, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(onPressed: onRetry, child: const Text('重新加载')),
            ],
          ]),
        ),
      );
}
