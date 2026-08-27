import 'package:flutter/material.dart';

/// 长弹窗专用滚动区域：滚动条常驻，明确提示下方还有内容。
class DialogScrollView extends StatefulWidget {
  final Widget child;
  const DialogScrollView({super.key, required this.child});

  @override
  State<DialogScrollView> createState() => _DialogScrollViewState();
}

class _DialogScrollViewState extends State<DialogScrollView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        trackVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          controller: _controller,
          primary: false,
          padding: const EdgeInsets.only(right: 12),
          child: widget.child,
        ),
      );
}
