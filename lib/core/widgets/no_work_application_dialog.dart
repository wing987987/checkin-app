import 'package:flutter/material.dart';

/// Returns an optional reason on confirmation; null means cancelled.
class NoWorkApplicationDialog extends StatefulWidget {
  final String date, shiftName;
  const NoWorkApplicationDialog(
      {super.key, required this.date, required this.shiftName});
  @override
  State<NoWorkApplicationDialog> createState() =>
      _NoWorkApplicationDialogState();
}

class _NoWorkApplicationDialogState extends State<NoWorkApplicationDialog> {
  String reason = '';
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('确认申请本班次未出工？'),
      content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
            '${widget.date} · ${widget.shiftName}\n主管批准后本班次为未出工、0工。申请后须由主管撤销才可补卡，加班独立统计。'),
        const SizedBox(height: 12),
        TextField(
            maxLength: 500,
            onChanged: (v) => reason = v,
            decoration: const InputDecoration(labelText: '说明（选填）')),
      ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
            onPressed: () => Navigator.pop(context, reason.trim()),
            child: const Text('确认提交'))
      ],
    );
  }
}
