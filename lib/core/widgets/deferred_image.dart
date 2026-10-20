import 'package:flutter/material.dart';

/// Defer URL signing and downloading until the image intersects every scroll viewport.
class DeferredImage extends StatefulWidget {
  final String identity;
  final double? width;
  final double? height;
  final WidgetBuilder builder;
  const DeferredImage(
      {super.key,
      required this.identity,
      this.width,
      this.height,
      required this.builder});
  @override
  State<DeferredImage> createState() => _DeferredImageState();
}

class _DeferredImageState extends State<DeferredImage>
    with WidgetsBindingObserver {
  final _scrollables = <ScrollableState>[];
  final _positions = <ScrollPosition>[];
  bool _visible = false;
  bool _scheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unsubscribe();
    context.visitAncestorElements((element) {
      if (element is StatefulElement && element.state is ScrollableState) {
        final scrollable = element.state as ScrollableState;
        _scrollables.add(scrollable);
        _positions.add(scrollable.position);
        scrollable.position.addListener(_schedule);
      }
      return true;
    });
    _schedule();
  }

  void _unsubscribe() {
    for (final position in _positions) {
      position.removeListener(_schedule);
    }
    _scrollables.clear();
    _positions.clear();
  }

  @override
  void didUpdateWidget(DeferredImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) _visible = false;
    _schedule();
  }

  @override
  void didChangeMetrics() => _schedule();
  void _schedule() {
    if (_visible || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _visible) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      var visible = Offset.zero & MediaQuery.sizeOf(context);
      for (final scrollable in _scrollables) {
        final viewport = scrollable.context.findRenderObject();
        if (viewport is RenderBox && viewport.hasSize && viewport.attached) {
          visible = visible
              .intersect(viewport.localToGlobal(Offset.zero) & viewport.size);
        }
      }
      if (!visible.isEmpty && rect.overlaps(visible)) {
        setState(() => _visible = true);
      }
    });
  }

  @override
  void dispose() {
    _unsubscribe();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: widget.width,
      height: widget.height,
      child: _visible
          ? widget.builder(context)
          : const Center(child: Icon(Icons.image_outlined)));
}
