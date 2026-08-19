import 'package:flutter/material.dart';
import '../../models/checkin_project.dart';
import '../../models/checkin_shift.dart';
import '../../models/checkin_team.dart';
import '../../models/worker_assignment.dart';
import '../../services/management_service.dart';
import 'anomaly_list_page.dart';
import 'project_report_page.dart';

class ProjectManagementPage extends StatefulWidget {
  final CheckinProject project;
  const ProjectManagementPage({super.key, required this.project});
  @override
  State<ProjectManagementPage> createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
  List<CheckinTeam> teams = const [];
  List<CheckinShift> shifts = const [];
  List<WorkerAssignment> workers = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        ManagementService.teams(widget.project.id),
        ManagementService.shifts(widget.project.id),
        ManagementService.workers(widget.project.id),
      ]);
      if (!mounted) return;
      setState(() {
        teams = values[0].data as List<CheckinTeam>? ?? const [];
        shifts = values[1].data as List<CheckinShift>? ?? const [];
        workers = values[2].data as List<WorkerAssignment>? ?? const [];
      });
    } catch (_) {
      if (mounted) _message('加载失败，请检查网络');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.project.name)),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.gps_fixed),
                          title: const Text('项目定位'),
                          subtitle: Text(
                              '${widget.project.gpsLat}, ${widget.project.gpsLng}\n打卡范围 ${widget.project.fenceRadius} 米'))),
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.warning_amber,
                              color: Colors.orange),
                          title: const Text('异常考勤处理'),
                          subtitle: const Text('围栏外、迟到、早退、缺卡'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AnomalyListPage(
                                      project: widget.project))))),
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.assessment),
                          title: const Text('月度考勤报表'),
                          subtitle: const Text('按班组、工人汇总'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ProjectReportPage(
                                      project: widget.project))))),
                  _header('班组', teams.length, _addTeam),
                  if (teams.isEmpty) const ListTile(title: Text('暂未设置班组')),
                  ...teams.map((t) => ListTile(
                      leading: const Icon(Icons.groups), title: Text(t.name))),
                  _header('班次', shifts.length, _addShift),
                  if (shifts.isEmpty) const ListTile(title: Text('暂未设置班次')),
                  ...shifts.map((s) => ListTile(
                      leading: const Icon(Icons.schedule),
                      title: Text(s.name),
                      subtitle: Text(
                          '${_typeName(s.shiftType)}  ${s.startTime}–${s.endTime}${s.crossDay ? '（跨日）' : ''}'))),
                  _header(
                      '工人',
                      workers.length,
                      teams.isNotEmpty && shifts.isNotEmpty
                          ? _addWorker
                          : null),
                  if (teams.isEmpty || shifts.isEmpty)
                    const ListTile(title: Text('请先创建班组和班次，再添加工人')),
                  if (workers.isEmpty && teams.isNotEmpty && shifts.isNotEmpty)
                    const ListTile(title: Text('暂未添加工人')),
                  ...workers.map((w) => ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(w.realName.isEmpty ? w.username : w.realName),
                      subtitle: Text('${w.teamName} · ${w.shiftName}'),
                      trailing: const Icon(Icons.swap_horiz),
                      onTap: () => _changeAssignment(w))),
                ]),
              ),
      );

  Widget _header(String title, int count, VoidCallback? onAdd) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 4),
        child: Row(children: [
          Expanded(
              child: Text('$title（$count）',
                  style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
              onPressed: onAdd,
              tooltip: '新增$title',
              icon: const Icon(Icons.add_circle_outline))
        ]),
      );

  Future<void> _addTeam() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('新增班组'),
                content: TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: '班组名称')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () async {
                        if (controller.text.trim().isEmpty) return;
                        final r = await ManagementService.createTeam(
                            widget.project.id, controller.text.trim());
                        if (ctx.mounted) {
                          if (r.isSuccess) {
                            Navigator.pop(ctx, true);
                          } else {
                            _message(r.message);
                          }
                        }
                      },
                      child: const Text('创建'))
                ]));
    if (ok == true) _load();
  }

  Future<void> _addShift() async {
    final name = TextEditingController();
    var type = 'day';
    var start = const TimeOfDay(hour: 6, minute: 30);
    var breakStart = const TimeOfDay(hour: 11, minute: 30);
    var breakEnd = const TimeOfDay(hour: 13, minute: 0);
    var end = const TimeOfDay(hour: 17, minute: 30);
    var before = 5;
    var after = 5;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setLocal) => AlertDialog(
                    title: const Text('新增班次'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: name,
                          decoration: const InputDecoration(labelText: '班次名称')),
                      DropdownButtonFormField<String>(
                          initialValue: type,
                          decoration: const InputDecoration(labelText: '班次类型'),
                          items: const [
                            DropdownMenuItem(value: 'day', child: Text('白班')),
                            DropdownMenuItem(value: 'night', child: Text('夜班')),
                            DropdownMenuItem(
                                value: 'high_temperature', child: Text('高温班')),
                            DropdownMenuItem(
                                value: 'overtime', child: Text('加班'))
                          ],
                          onChanged: (v) => setLocal(() => type = v ?? 'day')),
                      ListTile(
                          title: const Text('开始时间'),
                          trailing: Text(start.format(ctx)),
                          onTap: () async {
                            final v = await showTimePicker(
                                context: ctx, initialTime: start);
                            if (v != null) setLocal(() => start = v);
                          }),
                      if (type == 'day' || type == 'high_temperature')
                        ListTile(
                            title: const Text('中午下班'),
                            trailing: Text(breakStart.format(ctx)),
                            onTap: () async {
                              final v = await showTimePicker(
                                  context: ctx, initialTime: breakStart);
                              if (v != null) setLocal(() => breakStart = v);
                            }),
                      if (type == 'day' || type == 'high_temperature')
                        ListTile(
                            title: const Text('下午上班'),
                            trailing: Text(breakEnd.format(ctx)),
                            onTap: () async {
                              final v = await showTimePicker(
                                  context: ctx, initialTime: breakEnd);
                              if (v != null) setLocal(() => breakEnd = v);
                            }),
                      ListTile(
                          title: const Text('结束时间'),
                          trailing: Text(end.format(ctx)),
                          onTap: () async {
                            final v = await showTimePicker(
                                context: ctx, initialTime: end);
                            if (v != null) setLocal(() => end = v);
                          }),
                      Row(children: [
                        Expanded(
                            child: TextFormField(
                                initialValue: '5',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: '提前容差(分钟)'),
                                onChanged: (v) =>
                                    before = int.tryParse(v) ?? 5)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: TextFormField(
                                initialValue: '5',
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                    labelText: '延后容差(分钟)'),
                                onChanged: (v) => after = int.tryParse(v) ?? 5))
                      ]),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () async {
                            if (name.text.trim().isEmpty) return;
                            final cross = _minutes(end) <= _minutes(start);
                            final r = await ManagementService.createShift(
                                widget.project.id, {
                              'name': name.text.trim(),
                              'shiftType': type,
                              'startTime': _time(start),
                              'endTime': _time(end),
                              'crossDay': cross ? 1 : 0,
                              if (type == 'day' || type == 'high_temperature')
                                'breakStartTime': _time(breakStart),
                              if (type == 'day' || type == 'high_temperature')
                                'breakEndTime': _time(breakEnd),
                              'graceBeforeMinutes': before,
                              'graceAfterMinutes': after,
                              'status': 1
                            });
                            if (ctx.mounted) {
                              if (r.isSuccess) {
                                Navigator.pop(ctx, true);
                              } else {
                                _message(r.message);
                              }
                            }
                          },
                          child: const Text('创建'))
                    ])));
    if (ok == true) _load();
  }

  Future<void> _addWorker() async {
    final username = TextEditingController(),
        password = TextEditingController(text: '123456'),
        realName = TextEditingController(),
        phone = TextEditingController();
    var teamId = teams.first.id, shiftId = shifts.first.id;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setLocal) => AlertDialog(
                    title: const Text('新增工人'),
                    content: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: realName,
                          decoration: const InputDecoration(labelText: '姓名')),
                      TextField(
                          controller: username,
                          decoration:
                              const InputDecoration(labelText: '登录用户名')),
                      TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: '初始密码')),
                      TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(labelText: '手机号（选填）')),
                      DropdownButtonFormField<int>(
                          initialValue: teamId,
                          decoration: const InputDecoration(labelText: '班组'),
                          items: teams
                              .map((t) => DropdownMenuItem(
                                  value: t.id, child: Text(t.name)))
                              .toList(),
                          onChanged: (v) =>
                              setLocal(() => teamId = v ?? teamId)),
                      DropdownButtonFormField<int>(
                          initialValue: shiftId,
                          decoration: const InputDecoration(labelText: '班次'),
                          items: shifts
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) =>
                              setLocal(() => shiftId = v ?? shiftId)),
                    ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () async {
                            if (username.text.trim().isEmpty ||
                                realName.text.trim().isEmpty) {
                              return;
                            }
                            final r = await ManagementService.createWorker(
                                widget.project.id, {
                              'username': username.text.trim(),
                              'password': password.text,
                              'realName': realName.text.trim(),
                              'phone': phone.text.trim(),
                              'teamId': teamId,
                              'shiftId': shiftId
                            });
                            if (ctx.mounted) {
                              if (r.isSuccess) {
                                Navigator.pop(ctx, true);
                              } else {
                                _message(r.message);
                              }
                            }
                          },
                          child: const Text('创建'))
                    ])));
    if (ok == true) _load();
  }

  Future<void> _changeAssignment(WorkerAssignment worker) async {
    var teamId = worker.teamId, shiftId = worker.shiftId;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setLocal) => AlertDialog(
                    title: Text('调整 ${worker.realName}'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      DropdownButtonFormField<int>(
                          initialValue: teamId,
                          decoration: const InputDecoration(labelText: '班组'),
                          items: teams
                              .map((t) => DropdownMenuItem(
                                  value: t.id, child: Text(t.name)))
                              .toList(),
                          onChanged: (v) =>
                              setLocal(() => teamId = v ?? teamId)),
                      DropdownButtonFormField<int>(
                          initialValue: shiftId,
                          decoration: const InputDecoration(labelText: '班次'),
                          items: shifts
                              .map((s) => DropdownMenuItem(
                                  value: s.id, child: Text(s.name)))
                              .toList(),
                          onChanged: (v) =>
                              setLocal(() => shiftId = v ?? shiftId)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () async {
                            final r = await ManagementService.assignWorker(
                                worker.workerId,
                                widget.project.id,
                                teamId,
                                shiftId);
                            if (ctx.mounted) {
                              if (r.isSuccess) {
                                Navigator.pop(ctx, true);
                              } else {
                                _message(r.message);
                              }
                            }
                          },
                          child: const Text('确认调整'))
                    ])));
    if (ok == true) _load();
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;
  String _time(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';
  String _typeName(String type) =>
      const {
        'day': '白班',
        'night': '夜班',
        'high_temperature': '高温班',
        'overtime': '加班'
      }[type] ??
      type;
}
