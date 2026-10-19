import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/api_result.dart';
import '../../models/attendance_report.dart';
import '../../services/management_service.dart';

class ContinuousSupplementDialog extends StatefulWidget {
  final DailyAttendance day;
  final AttendanceClockDetail firstClock;
  final Future<ApiResult<dynamic>> Function(Map<String, dynamic>)? save;

  const ContinuousSupplementDialog({
    super.key,
    required this.day,
    required this.firstClock,
    this.save,
  });

  @override
  State<ContinuousSupplementDialog> createState() =>
      _ContinuousSupplementDialogState();
}

class _ContinuousSupplementDialogState
    extends State<ContinuousSupplementDialog> {
  final _reason = TextEditingController();
  late final List<AttendanceClockDetail> _clocks;
  int _index = 0;
  bool _saving = false;
  String? _error;
  DateTime? _clockTime;

  AttendanceClockDetail get _clock => _clocks[_index];
  bool get _hasNext => _index + 1 < _clocks.length;

  @override
  void initState() {
    super.initState();
    final remaining = widget.day.clocks
        .where((clock) =>
            clock.checkpointId != null &&
            clock.checkpointId != widget.firstClock.checkpointId &&
            clock.recordId == null &&
            (clock.status == 'missing' || clock.status == 'paused'))
        .toList()
      ..sort((a, b) {
        final offset = a.expectedDayOffset.compareTo(b.expectedDayOffset);
        return offset != 0 ? offset : a.expectedTime.compareTo(b.expectedTime);
      });
    _clocks = [widget.firstClock, ...remaining];
    _resetTime();
  }

  void _resetTime() {
    final date = DateTime.tryParse(widget.day.date);
    final parts = _clock.expectedTime.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) : null;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    _clockTime = date == null ||
            hour == null ||
            minute == null ||
            hour < 0 ||
            hour > 23 ||
            minute < 0 ||
            minute > 59
        ? null
        : DateTime(date.year, date.month, date.day + _clock.expectedDayOffset,
            hour, minute);
    _error = _clockTime == null ? '标准打卡时间无效，请退出后检查班次设置' : null;
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _clockTime == null) return;
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = '请输入补卡原因');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await (widget.save ?? ManagementService.supplementClock)({
        'workerId': widget.day.workerId,
        'projectId': widget.day.projectId,
        'teamId': widget.day.teamId,
        'shiftId': widget.day.shiftId,
        'checkpointId': _clock.checkpointId,
        'attendanceDate': widget.day.date,
        'clockTime': _clockTime!.toIso8601String(),
        'reason': _reason.text.trim(),
      });
      if (!mounted) return;
      if (!result.isSuccess) {
        setState(() =>
            _error = result.message.isEmpty ? '补卡失败，请重试' : result.message);
      } else if (_hasNext) {
        setState(() {
          _index++;
          _resetTime();
        });
      } else {
        Navigator.pop(context, _index + 1);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '补卡失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime() async {
    final current = _clockTime;
    if (_saving || current == null) return;
    final now = DateTime.now();
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: now,
        initialDate: current.isAfter(now) ? now : current);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (time != null && mounted) {
      setState(() => _clockTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<int>(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && !_saving) Navigator.pop(context, _index);
        },
        child: AlertDialog(
          title: Text('${widget.day.workerName} · ${_clock.checkpointName}补卡'),
          content: SingleChildScrollView(
              child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.day.date} · ${widget.day.shiftName}'),
              Text('第 ${_index + 1} / ${_clocks.length} 个节点 · 已保存 $_index 个'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('补卡时间'),
                subtitle: Text(_clockTime == null
                    ? '时间无效'
                    : DateFormat('yyyy-MM-dd HH:mm').format(_clockTime!)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _saving ? null : _pickTime,
              ),
              TextField(
                  controller: _reason,
                  enabled: !_saving,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '请输入补卡原因（必填）')),
              const SizedBox(height: 8),
              const Text('每次只保存当前节点；退出不会撤销已保存的补卡。'),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          )),
          actions: [
            TextButton(
                onPressed:
                    _saving ? null : () => Navigator.pop(context, _index),
                child: Text(_index == 0 ? '取消' : '退出补卡')),
            FilledButton(
                onPressed: _saving || _clockTime == null ? null : _save,
                child: Text(_saving
                    ? '保存中…'
                    : _hasNext
                        ? '保存并补下一项'
                        : '保存并完成')),
          ],
        ),
      );
}
