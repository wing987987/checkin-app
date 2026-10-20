import 'package:flutter/material.dart';

/// Build only the requested batch, including in non-lazy Wrap/Column layouts.
class ImageBatch extends StatefulWidget {
  final int count;
  final IndexedWidgetBuilder itemBuilder;
  final int batchSize;
  final String identity;
  final int? columns;
  final double childAspectRatio;
  const ImageBatch(
      {super.key,
      required this.count,
      required this.itemBuilder,
      required this.identity,
      this.batchSize = 6,
      this.columns,
      this.childAspectRatio = 1});
  @override
  State<ImageBatch> createState() => _ImageBatchState();
}

class _ImageBatchState extends State<ImageBatch> {
  late int _limit = widget.batchSize;
  @override
  void didUpdateWidget(ImageBatch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) _limit = widget.batchSize;
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count < _limit ? widget.count : _limit;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.columns == null)
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (var i = 0; i < count; i++) widget.itemBuilder(context, i),
        ])
      else
        GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: widget.columns!,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: widget.childAspectRatio),
            itemBuilder: widget.itemBuilder),
      if (count < widget.count)
        TextButton(
            onPressed: () => setState(() => _limit += widget.batchSize),
            child: Text('加载更多图片（剩余 ${widget.count - count} 张）')),
    ]);
  }
}
