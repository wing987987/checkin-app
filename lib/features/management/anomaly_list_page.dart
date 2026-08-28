import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_anomaly.dart';
import '../../models/attendance_report.dart';
import '../../models/checkin_project.dart';
import '../../services/management_service.dart';
import '../../core/models/api_result.dart';
import '../../core/widgets/zoomable_network_image.dart';
import '../../core/widgets/dialog_scroll_view.dart';

class AnomalyListPage extends StatefulWidget {
  final CheckinProject project;
  const AnomalyListPage({super.key, required this.project});
  @override
  State<AnomalyListPage> createState() => _AnomalyListPageState();
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
    final visible =
        showResolved ? items : items.where((e) => !e.resolved).toList();
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
          : visible.isEmpty
              ? const Center(child: Text('没有待处理异常'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                      itemCount: visible.length,
                      itemBuilder: (_, i) => _card(visible[i]))),
    );
  }

  Widget _card(AttendanceAnomaly item) => Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: ListTile(
          leading: Icon(
              item.resolved ? Icons.check_circle : Icons.warning_amber,
              color: item.resolved ? Colors.green : Colors.orange),
          title: Text('${item.workerName} · ${item.checkpointName}'),
          subtitle: Text(
              '${item.attendanceDate}  ${item.teamName}/${item.shiftName}\n${item.anomalyMessage}${item.resolved ? '\n已处理${item.corrected ? '（修正）' : ''}：${item.latestReason ?? ''}' : ''}'),
          isThreeLine: true,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            if (item.photoUrl != null && item.photoUrl!.isNotEmpty)
              IconButton(
                  tooltip: '查看打卡照片',
                  onPressed: () => _showRecordPhoto(item.recordId!,
                      '${item.workerName} · ${item.checkpointName}'),
                  icon: const Icon(Icons.photo_camera_outlined)),
            const Icon(Icons.chevron_right),
          ]),
          onTap: item.missing
              ? () => _reviewMissing(item)
              : item.resolved
                  ? () => _showHistory(item)
                  : () => _resolve(item)));

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
                            '不处理：保持异常状态，不计入工时。\n确认有效：按原时间计入工时。\n修正时间：按修正后的时间计入工时。',
                            style: TextStyle(height: 1.5)),
                      ])),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消')),
                  OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, 'confirm'),
                      child: const Text('确认原记录有效')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, 'correct'),
                      child: const Text('修正时间'))
                ]));
    if (action == null || !mounted) return;
    final reason = TextEditingController();
    DateTime corrected = DateTime.tryParse(item.clockTime) ?? DateTime.now();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setLocal) => AlertDialog(
                    title: Text(action == 'correct' ? '修正打卡时间' : '确认原记录有效'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      if (action == 'correct')
                        ListTile(
                            title: const Text('修正后时间'),
                            subtitle: Text(DateFormat('yyyy-MM-dd HH:mm')
                                .format(corrected)),
                            onTap: () async {
                              final d = await showDatePicker(
                                  context: ctx,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                  initialDate: corrected);
                              if (d == null || !ctx.mounted) return;
                              final t = await showTimePicker(
                                  context: ctx,
                                  initialTime:
                                      TimeOfDay.fromDateTime(corrected));
                              if (t != null) {
                                setLocal(() => corrected = DateTime(
                                    d.year, d.month, d.day, t.hour, t.minute));
                              }
                            }),
                      TextField(
                          controller: reason,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: '处理原因（必填）',
                              hintText: '例如：现场确认工人实际在岗')),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () async {
                            if (reason.text.trim().isEmpty) return;
                            final r = await ManagementService.resolveAnomaly(
                                recordId, {
                              'action': action,
                              'reason': reason.text.trim(),
                              if (action == 'correct')
                                'correctedTime': corrected.toIso8601String()
                            });
                            if (ctx.mounted) {
                              if (r.isSuccess) {
                                Navigator.pop(ctx, true);
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text(r.message)));
                              }
                            }
                          },
                          child: const Text('确认处理'))
                    ])));
    if (ok == true) _load();
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
                    final label = action == 'confirm'
                        ? '确认有效'
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
    final supplement = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.event_busy_outlined,
            color: Colors.orange, size: 42),
        title: Text('${item.workerName} · ${item.checkpointName}缺卡'),
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
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('暂不处理')),
          FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.add_task_outlined),
              label: const Text('为此节点补卡')),
        ],
      ),
    );
    if (supplement == true && mounted) await _supplementMissing(item);
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
              decoration: const InputDecoration(labelText: '补卡原因（必填）'),
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
