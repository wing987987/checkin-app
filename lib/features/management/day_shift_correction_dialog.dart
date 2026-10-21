import 'package:flutter/material.dart';
import '../../core/widgets/dialog_scroll_view.dart';
import '../../core/models/api_result.dart';
import '../../models/attendance_report.dart';
import '../../models/checkin_shift.dart';
import '../../services/management_service.dart';

class DayShiftCorrectionDialog extends StatefulWidget {
  final DailyAttendance day;
  final List<CheckinShift> shifts;
  final Future<ApiResult<dynamic>> Function(Map<String, dynamic>)? save;
  const DayShiftCorrectionDialog(
      {super.key, required this.day, required this.shifts, this.save});
  @override
  State<DayShiftCorrectionDialog> createState() =>
      _DayShiftCorrectionDialogState();
}

class _DayShiftCorrectionDialogState extends State<DayShiftCorrectionDialog> {
  final _reason = TextEditingController();
  int? _shift;
  bool _acknowledged = false, _saving = false;
  String? _error;
  bool get _hasOriginal => widget.day.clocks
      .any((c) => c.recordId != null && c.expectedTime.isNotEmpty);
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_shift == null) {
      setState(() => _error = '请选择正确班次');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = '请填写更正原因');
      return;
    }
    if (_hasOriginal && !_acknowledged) {
      setState(() => _error = '请确认原班次记录的处理方式');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await (widget.save ?? ManagementService.correctDayShift)({
        'workerId': widget.day.workerId,
        'projectId': widget.day.projectId,
        'attendanceDate': widget.day.date,
        'previousShiftId': widget.day.shiftId,
        'shiftId': _shift,
        'reason': _reason.text.trim(),
        'acknowledgeOriginal': _acknowledged,
      });
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = result.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '更正失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: const Text('更正当天班次'),
        content: SizedBox(
            width: double.maxFinite,
            child: DialogScrollView(
                child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${widget.day.workerName} · ${widget.day.date}'),
                Text('原班次：${widget.day.shiftName}'),
                const SizedBox(height: 12),
                const Text('仅更正这个考勤日期，不改变其他日期和日常排班。更正后按新班次补卡或核定工时、工数；加班仍独立统计。'),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                    initialValue: _shift,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: '正确班次'),
                    items: widget.shifts
                        .where(
                            (s) => s.id != widget.day.shiftId && s.status == 1)
                        .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(
                                '${s.name} ${s.startTime}–${s.crossDay ? '次日 ' : ''}${s.endTime}')))
                        .toList(),
                    onChanged:
                        _saving ? null : (v) => setState(() => _shift = v)),
                if (_shift != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(widget.shifts
                                  .firstWhere((s) => s.id == _shift)
                                  .shiftType ==
                              'day'
                          ? '白班：上班、中午下班、下午上班、下班四个节点'
                          : '夜班：上班、次日下班两个节点；日期按上班日归属')),
                if (_hasOriginal) ...[
                  const SizedBox(height: 16),
                  const Text('原班次已有打卡：'),
                  ...widget.day.clocks
                      .where((c) => c.recordId != null)
                      .map((c) => Text('${c.checkpointName}：${c.clockTime}')),
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _acknowledged,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _acknowledged = v == true),
                      title: const Text('确认原普通打卡仅保留留痕，不再计工；按新班次核实后重新补卡')),
                ],
                const SizedBox(height: 12),
                TextField(
                    controller: _reason,
                    enabled: !_saving,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: '更正原因（必填）')),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? '处理中…' : '确认更正'))
        ],
      ));
}
