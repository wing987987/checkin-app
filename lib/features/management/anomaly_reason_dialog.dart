import 'package:flutter/material.dart';
import '../../models/attendance_anomaly.dart';
import '../../services/anomaly_reason_service.dart';

Future<void> showAnomalyReasons(BuildContext context, AttendanceAnomaly item) =>
    showDialog<void>(
        context: context, builder: (_) => _ReasonDialog(item: item));

class AnomalyReasonPreview extends StatefulWidget {
  final AttendanceAnomaly item;
  const AnomalyReasonPreview({super.key, required this.item});
  @override
  State<AnomalyReasonPreview> createState() => _AnomalyReasonPreviewState();
}

class _AnomalyReasonPreviewState extends State<AnomalyReasonPreview> {
  late final _history = AnomalyReasonService.history(widget.item);
  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: _history,
      builder: (context, snapshot) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('现场异常原因', style: TextStyle(fontWeight: FontWeight.bold)),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator()
            else if (snapshot.hasError)
              const Text('原因记录加载失败，可返回异常列表重试')
            else if (snapshot.data!.isEmpty)
              const Text('暂无填写记录')
            else
              for (final entry in snapshot.data!) ...[
                Text('${entry['authorName']} · ${entry['createdAt']}',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('${entry['reason']}'),
                const SizedBox(height: 8),
              ],
          ])));
}

class _ReasonDialog extends StatefulWidget {
  final AttendanceAnomaly item;
  const _ReasonDialog({required this.item});
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _history = [];
  bool _loading = true, _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await AnomalyReasonService.history(widget.item);
      if (mounted) {
        setState(() {
          _history = data;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      setState(() => _error = '请填写异常原因');
      return;
    }
    setState(() => _saving = true);
    try {
      await AnomalyReasonService.append(widget.item, _text.text.trim());
      _text.clear();
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '保存失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.item.workerName} · 异常原因'),
        content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      '${widget.item.attendanceDate} · ${widget.item.shiftName}'),
                  const Text('原因按本日班次记录，填写后由主管审批；每次填写均保留。'),
                  const SizedBox(height: 12),
                  if (_loading) const LinearProgressIndicator(),
                  if (!_loading && _history.isEmpty) const Text('暂无原因填写记录'),
                  for (final entry in _history)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${entry['authorName']} · ${entry['authorRole'] == 'worker' ? '班组长' : entry['authorRole'] == 'boss' ? '老总' : '主管'} · ${entry['createdAt']}',
                                  style: Theme.of(context).textTheme.bodySmall),
                              Text('${entry['reason']}'),
                            ])),
                  if (!widget.item.resolved)
                    TextField(
                        controller: _text,
                        enabled: !_saving,
                        maxLines: 4,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                            labelText: '填写异常原因', hintText: '说明现场情况，供主管审批参考')),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                ]))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('关闭')),
          if (!widget.item.resolved)
            FilledButton(
                onPressed: _saving || _loading ? null : _save,
                child: Text(_saving ? '保存中…' : '保存原因')),
        ],
      );
}
