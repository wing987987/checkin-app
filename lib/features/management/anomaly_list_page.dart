import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_anomaly.dart';
import '../../models/attendance_report.dart';
import '../../models/checkin_project.dart';
import '../../services/management_service.dart';
import '../../core/models/api_result.dart';
import '../../core/widgets/zoomable_network_image.dart';
import '../../core/widgets/dialog_scroll_view.dart';
import '../../core/theme/app_theme.dart';

class AnomalyListPage extends StatefulWidget {
  final CheckinProject project;
  const AnomalyListPage({super.key, required this.project});
  @override
  State<AnomalyListPage> createState() => _AnomalyListPageState();
}

class ManualHoursDialog extends StatefulWidget {
  final AttendanceAnomaly item;
  final Future<ApiResult<dynamic>> Function(Map<String, dynamic>)? save;

  const ManualHoursDialog({super.key, required this.item, this.save});

  @override
  State<ManualHoursDialog> createState() => _ManualHoursDialogState();
}

class _ManualHoursDialogState extends State<ManualHoursDialog> {
  final _hours = TextEditingController();
  final _units = TextEditingController(text: '0.5');
  final _reason = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _hours.dispose();
    _units.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final workHours = double.tryParse(_hours.text.trim());
    final workUnits = double.tryParse(_units.text.trim());
    if (workHours == null || !workHours.isFinite || workHours < 0) {
      setState(() => _error = '请输入有效的确认工时');
      return;
    }
    if (workUnits == null ||
        !workUnits.isFinite ||
        workUnits < 0 ||
        workUnits > 3) {
      setState(() => _error = '确认工数需在 0 到 3 之间');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = '请填写确认原因');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await (widget.save ?? ManagementService.setManualHours)({
        'workerId': widget.item.workerId,
        'projectId': widget.item.projectId,
        'teamId': widget.item.teamId,
        'shiftId': widget.item.shiftId,
        'attendanceDate': widget.item.attendanceDate,
        'workHours': workHours,
        'workUnits': workUnits,
        'reason': _reason.text.trim(),
      });
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.pop(context, true);
      } else {
        setState(() =>
            _error = result.message.isEmpty ? '保存失败，请重试' : result.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('${widget.item.workerName} · 确认考勤'),
        content: SizedBox(
          width: double.maxFinite,
          child: DialogScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: _hours,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: '确认工时', hintText: '例如 4'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _units,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: '确认工数', hintText: '例如 0.5'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '确认原因（必填）'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      );
}

class _AnomalyListPageState extends State<AnomalyListPage> {
  List<AttendanceAnomaly> items = const [];
  bool loading = true;
  bool showResolved = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await ManagementService.anomalies(widget.project.id);
      if (mounted) setState(() => items = r.data ?? const []);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = items.where((e) => !e.resolved).toList();
    final extra =
        pending.where((e) => e.anomalyType == 'extra_shift_pending').toList();
    final missing = pending
        .where((e) => e.missing && e.anomalyType != 'extra_shift_pending')
        .toList();
    final abnormal = pending.where((e) => !e.missing).toList();
    final resolved = showResolved
        ? items.where((e) => e.resolved).toList()
        : <AttendanceAnomaly>[];
    return Scaffold(
      appBar: AppBar(title: const Text('异常考勤'), actions: [
        Row(children: [
          const Text('显示已处理'),
          Switch(
              value: showResolved,
              onChanged: (v) => setState(() => showResolved = v))
        ])
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : pending.isEmpty && resolved.isEmpty
              ? const Center(child: Text('没有待处理异常'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _summary(extra.length, missing.length, abnormal.length),
                      _section(
                          '附加班次待确认', '需要确认工时和工数', extra, AppColors.primary),
                      _section('缺卡', '检查缺失的打卡节点', missing, AppColors.warning),
                      _section('异常打卡', '围栏外或时间不符', abnormal, AppColors.danger),
                      if (showResolved)
                        _section(
                            '已处理记录', '可查看处理历史', resolved, AppColors.success),
                    ],
                  )),
    );
  }

  Widget _summary(int extra, int missing, int abnormal) => Card(
        margin: const EdgeInsets.only(bottom: 18),
        color: AppColors.soft,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('待处理 ${extra + missing + abnormal} 项',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('附加班次 $extra  ·  缺卡 $missing  ·  异常打卡 $abnormal',
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );

  Widget _section(String title, String description,
      List<AttendanceAnomaly> entries, Color color) {
    if (entries.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
        child: Row(children: [
          Container(
              width: 4,
              height: 22,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 6),
          Text('${entries.length}',
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          const Spacer(),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 14, bottom: 8),
        child: Text(description,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ),
      ...entries.map((item) => _card(item, color)),
      const SizedBox(height: 16),
    ]);
  }

  Widget _card(AttendanceAnomaly item, Color color) {
    final isExtra = item.anomalyType == 'extra_shift_pending';
    final action = item.resolved
        ? '查看处理历史'
        : isExtra
            ? '确认工时 / 工数'
            : item.missing
                ? '查看并补卡'
                : '处理异常打卡';
    final detail = isExtra ? '附加班次未达到 1 工，请主管确认实际工时和工数' : item.anomalyMessage;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.missing
            ? () => _reviewMissing(item)
            : item.resolved
                ? () => _showHistory(item)
                : () => _resolve(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(item.workerName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                    item.resolved
                        ? '已处理'
                        : isExtra
                            ? '待确认工数'
                            : item.missing
                                ? '缺卡'
                                : '打卡异常',
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(
                '${item.attendanceDate}  ·  ${item.teamName} / ${item.shiftName}',
                style: const TextStyle(color: AppColors.textSecondary)),
            if (!isExtra) ...[
              const SizedBox(height: 4),
              Text('节点：${item.checkpointName}',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item.resolved ? (item.latestReason ?? '已处理') : detail,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.arrow_forward, size: 16, color: color),
              const SizedBox(width: 4),
              Text(action,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (item.recordId != null &&
                  item.photoUrl != null &&
                  item.photoUrl!.isNotEmpty)
                IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: '查看打卡照片',
                    onPressed: () => _showRecordPhoto(item.recordId!,
                        '${item.workerName} · ${item.checkpointName}'),
                    icon: const Icon(Icons.photo_camera_outlined)),
              const Icon(Icons.chevron_right, color: AppColors.textTertiary),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _resolve(AttendanceAnomaly item) async {
    final recordId = item.recordId;
    if (recordId == null) return;
    final dayResult =
        await ManagementService.anomalyDay(item.referenceRecordId);
    if (!mounted) return;
    final days = dayResult.data;
    if (!dayResult.isSuccess || days == null || days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              dayResult.message.isEmpty ? '当天打卡明细加载失败' : dayResult.message)));
      return;
    }
    final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                icon: const Icon(Icons.warning_amber,
                    color: Colors.orange, size: 42),
                title: const Text('处理异常考勤'),
                content: SizedBox(
                  width: double.maxFinite,
                  child: DialogScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('${item.workerName} · ${item.attendanceDate}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        const Text('当天全部打卡记录',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        ...days.expand((day) => [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 8, bottom: 4),
                                child: Text(
                                    '${day.teamName} / ${day.shiftName}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey)),
                              ),
                              ...day.clocks.map((clock) =>
                                  _dayClockRow(clock, recordId, null)),
                            ]),
                        const Divider(height: 24),
                        const Text(
                            '确认并自动调整：按班次节点的标准日期、时间和项目定位计入工时，原始打卡保留。\n确认保持异常：仍不计工时，并从待处理列表移除；以后可在报表中重新处理。',
                            style: TextStyle(height: 1.5)),
                      ])),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, 'reject'),
                      child: const Text('确认保持异常')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'auto'),
                      child: const Text('确认并自动调整')),
                ]));
    if (action == null || !mounted) return;
    final result = await ManagementService.resolveAnomaly(recordId, {
      'action': action,
    });
    if (!mounted) return;
    if (result.isSuccess) {
      await _load();
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(result.message)));
    }
  }

  Future<void> _showHistory(AttendanceAnomaly item) async {
    final recordId = item.recordId;
    if (recordId == null) return;
    final result = await ManagementService.adjustmentHistory(recordId);
    if (!mounted) return;
    final history = result.data ?? const [];
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('调整历史'),
        content: SizedBox(
          width: double.maxFinite,
          child: history.isEmpty
              ? const Text('暂无调整记录')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: history.length,
                  itemBuilder: (_, index) {
                    final row = history[index];
                    final action = row['action'];
                    final label = action == 'auto'
                        ? '确认并自动调整'
                        : action == 'reject'
                            ? '确认保持异常'
                            : action == 'confirm'
                                ? '确认有效（旧）'
                                : action == 'correct'
                                    ? '修正时间'
                                    : action == 'void'
                                        ? '确认误打（不计工时）'
                                        : '$action';
                    return ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(label),
                      subtitle: Text(
                          '${row['createTime'] ?? ''}\n原因：${row['reason'] ?? ''}'),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))
        ],
      ),
    );
  }

  Future<void> _reviewMissing(AttendanceAnomaly item) async {
    final dayResult =
        await ManagementService.anomalyDay(item.referenceRecordId);
    if (!mounted) return;
    final days = dayResult.data;
    if (!dayResult.isSuccess || days == null || days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              dayResult.message.isEmpty ? '当天打卡明细加载失败' : dayResult.message)));
      return;
    }
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.event_busy_outlined,
            color: Colors.orange, size: 42),
        title: Text(item.anomalyType == 'extra_shift_pending'
            ? '${item.workerName} · 附加班次待确认'
            : '${item.workerName} · ${item.checkpointName}缺卡'),
        content: SizedBox(
          width: double.maxFinite,
          child: DialogScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${item.attendanceDate} 当天全部打卡记录',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...days.expand((day) => [
                    Text('${day.teamName} / ${day.shiftName}',
                        style: const TextStyle(color: Colors.grey)),
                    ...day.clocks.map((clock) =>
                        _dayClockRow(clock, null, item.checkpointId)),
                  ]),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('暂不处理')),
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'manual'),
              child: const Text('确认工时/工数')),
          if (item.checkpointId != null)
            FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, 'supplement'),
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('为此节点补卡')),
        ],
      ),
    );
    if (action == 'supplement' && mounted) await _supplementMissing(item);
    if (action == 'manual' && mounted) await _confirmManual(item);
  }

  Future<void> _confirmManual(AttendanceAnomaly item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ManualHoursDialog(item: item),
    );
    if (saved == true && mounted) await _load();
  }

  Future<void> _supplementMissing(AttendanceAnomaly item) async {
    final checkpointId = item.checkpointId;
    final attendanceDate = DateTime.tryParse(item.attendanceDate);
    final parts = item.expectedTime.split(':');
    if (checkpointId == null || attendanceDate == null || parts.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('缺卡节点信息不完整，无法补卡')));
      return;
    }
    var clockTime = DateTime(
        attendanceDate.year,
        attendanceDate.month,
        attendanceDate.day + item.expectedDayOffset,
        int.tryParse(parts[0]) ?? 0,
        int.tryParse(parts[1]) ?? 0);
    final reason = TextEditingController();
    final reasonFocus = FocusNode();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: Text('${item.workerName} · ${item.checkpointName}补卡'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('补卡时间'),
              subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(clockTime)),
              onTap: () async {
                final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(clockTime));
                if (time != null) {
                  setLocal(() => clockTime = DateTime(clockTime.year,
                      clockTime.month, clockTime.day, time.hour, time.minute));
                }
              },
            ),
            TextField(
              controller: reason,
              focusNode: reasonFocus,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '补卡原因（必填）'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (reason.text.trim().isEmpty) {
                  reasonFocus.requestFocus();
                  return;
                }
                final result = await ManagementService.supplementClock({
                  'workerId': item.workerId,
                  'projectId': item.projectId,
                  'teamId': item.teamId,
                  'shiftId': item.shiftId,
                  'checkpointId': checkpointId,
                  'attendanceDate': item.attendanceDate,
                  'clockTime': clockTime.toIso8601String(),
                  'reason': reason.text.trim(),
                });
                if (!ctx.mounted) return;
                if (result.isSuccess) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(result.message)));
                }
              },
              child: const Text('确认补卡'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    reasonFocus.dispose();
    if (saved == true && mounted) await _load();
  }

  Widget _dayClockRow(AttendanceClockDetail clock, int? targetRecordId,
      int? targetCheckpointId) {
    final target =
        (targetRecordId != null && clock.recordId == targetRecordId) ||
            (targetCheckpointId != null &&
                clock.checkpointId == targetCheckpointId &&
                clock.recordId == null);
    final missing = clock.recordId == null;
    final time = missing
        ? '--:--'
        : DateFormat('HH:mm')
            .format(DateTime.tryParse(clock.clockTime) ?? DateTime(2000));
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: target ? Colors.orange.withValues(alpha: .12) : null,
        borderRadius: BorderRadius.circular(8),
        border: target ? Border.all(color: Colors.orange) : null,
      ),
      child: Row(children: [
        SizedBox(
            width: 50,
            child: Text(time,
                style: const TextStyle(fontWeight: FontWeight.w600))),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(clock.checkpointName),
          Text(
              target
                  ? '当前待处理记录 · ${clock.anomalyMessage}'
                  : missing
                      ? '未打卡'
                      : clock.adjustmentAction.isNotEmpty
                          ? '${_adjustmentLabel(clock.adjustmentAction)}${clock.correctionReason.isEmpty ? '' : ' · 原因：${clock.correctionReason}'}'
                          : clock.countable
                              ? '正常'
                              : clock.anomalyMessage,
              style: TextStyle(
                  fontSize: 12,
                  color: target ? Colors.orange[800] : Colors.grey)),
        ])),
        if (clock.hasPhoto && clock.recordId != null)
          IconButton(
              tooltip: '查看照片',
              onPressed: () => _showRecordPhoto(
                  clock.recordId!, '${clock.checkpointName} · $time'),
              icon: const Icon(Icons.photo_camera_outlined)),
      ]),
    );
  }

  Future<void> _showRecordPhoto(int recordId, String title) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<ApiResult<String>>(
            future: ManagementService.anomalyPhotoViewUrl(recordId),
            builder: (_, snapshot) {
              final url = snapshot.data?.data;
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()));
              }
              if (url == null) {
                return SizedBox(
                    height: 120,
                    child: Center(
                        child: Text(snapshot.data?.message ?? '照片加载失败')));
              }
              return ZoomableNetworkImage(url: url);
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))
        ],
      ),
    );
  }

  String _adjustmentLabel(String action) =>
      const {
        'supplement': '主管补卡',
        'correct': '时间调整',
        'confirm': '确认有效',
        'void': '历史误打',
      }[action] ??
      action;
}
