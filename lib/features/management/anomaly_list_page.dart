import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_anomaly.dart';
import '../../models/checkin_project.dart';
import '../../services/management_service.dart';

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
          trailing: item.resolved ? null : const Icon(Icons.chevron_right),
          onTap: item.resolved ? null : () => _resolve(item)));

  Future<void> _resolve(AttendanceAnomaly item) async {
    final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
                icon: const Icon(Icons.warning_amber,
                    color: Colors.orange, size: 42),
                title: const Text('处理异常考勤'),
                content: const Text(
                    '处理后该次打卡将计入工时。原始打卡不会修改，处理人、原因和修正时间会永久留痕并显示在报表中。'),
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
                                item.recordId, {
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
}
