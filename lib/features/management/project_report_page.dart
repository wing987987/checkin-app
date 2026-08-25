import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/attendance_report.dart';
import '../../models/checkin_project.dart';
import '../../services/management_service.dart';

class ProjectReportPage extends StatefulWidget {
  final CheckinProject project;
  const ProjectReportPage({super.key, required this.project});
  @override
  State<ProjectReportPage> createState() => _ProjectReportPageState();
}

class _ProjectReportPageState extends State<ProjectReportPage> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  ProjectMonthReport? report;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final r = await ManagementService.projectMonthReport(
          widget.project.id, DateFormat('yyyy-MM').format(month));
      if (mounted) setState(() => report = r.data);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _move(int v) {
    month = DateTime(month.year, month.month + v);
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text('${widget.project.name}考勤报表')),
      body: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          IconButton(
              onPressed: () => _move(-1), icon: const Icon(Icons.chevron_left)),
          Text(DateFormat('yyyy年MM月').format(month),
              style: Theme.of(context).textTheme.titleLarge),
          IconButton(
              onPressed: () => _move(1), icon: const Icon(Icons.chevron_right))
        ]),
        Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : _body())
      ]));
  Widget _body() {
    final r = report;
    if (r == null) return const Center(child: Text('报表加载失败'));
    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _metric('总工数', r.totalWorkUnits),
                    _metric('正常工时', r.totalWorkHours),
                    _metric('加班小时', r.totalOvertimeHours)
                  ]))),
      if (r.days
          .any((d) => d.status == 'missing' || d.status == 'anomaly')) ...[
        Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
            child: Text('待人工判断工时',
                style: Theme.of(context).textTheme.titleMedium)),
        ...r.days
            .where((d) => d.status == 'missing' || d.status == 'anomaly')
            .map((d) => Card(
                child: ListTile(
                    leading:
                        const Icon(Icons.warning_amber, color: Colors.orange),
                    title: Text('${d.workerName} · ${d.date}'),
                    subtitle:
                        Text('${d.teamName} · ${d.shiftName}\n打卡不完整，当前不计工时和工数'),
                    isThreeLine: true,
                    trailing: const Icon(Icons.edit),
                    onTap: () => _manualHours(d)))),
      ],
      if (r.workers.isEmpty)
        const Padding(
            padding: EdgeInsets.all(40), child: Center(child: Text('本月暂无考勤'))),
      ...r.workers.map((w) => Card(
          child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(w.workerName),
              subtitle: Text(
                  '${w.teamName} · 出勤 ${w.attendanceDays} 天\n工数 ${w.workUnits}  工时 ${w.workHours}h  加班 ${w.overtimeHours}h'),
              isThreeLine: true,
              trailing: w.correctedDays > 0
                  ? Chip(label: Text('修正 ${w.correctedDays}'))
                  : w.anomalyDays > 0
                      ? Chip(label: Text('异常 ${w.anomalyDays}'))
                      : null)))
    ]);
  }

  Widget _metric(String n, double v) => Column(children: [
        Text(v.toStringAsFixed(2),
            style: Theme.of(context).textTheme.titleLarge),
        Text(n)
      ]);

  Future<void> _manualHours(DailyAttendance day) async {
    final hours = TextEditingController();
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text('${day.workerName} · ${day.date}'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('该日打卡不完整，请根据现场实际情况人工填写正常工时。加班时长不会计入此处。'),
                  TextField(
                      controller: hours,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: '正常工时（0–24小时）')),
                  TextField(
                      controller: reason,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: '判断原因（必填）'))
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () async {
                        final value = double.tryParse(hours.text);
                        if (value == null ||
                            value < 0 ||
                            value > 24 ||
                            reason.text.trim().isEmpty) {
                          return;
                        }
                        final result = await ManagementService.setManualHours({
                          'workerId': day.workerId,
                          'projectId': day.projectId,
                          'teamId': day.teamId,
                          'shiftId': day.shiftId,
                          'attendanceDate': day.date,
                          'workHours': value,
                          'reason': reason.text.trim()
                        });
                        if (!ctx.mounted) return;
                        if (result.isSuccess) {
                          Navigator.pop(ctx, true);
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(result.message)));
                        }
                      },
                      child: const Text('确认并留痕'))
                ]));
    if (saved == true) _load();
  }
}
