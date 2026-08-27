// ignore_for_file: deprecated_member_use, unused_element, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/checkin_project.dart';
import '../../models/checkin_shift.dart';
import '../../models/checkin_team.dart';
import '../../models/worker_assignment.dart';
import '../../models/my_schedule.dart';
import '../../services/management_service.dart';
import '../../core/widgets/dialog_scroll_view.dart';
import 'anomaly_list_page.dart';
import 'project_report_page.dart';
import 'project_location_picker_page.dart';
import 'clock_photo_archive_page.dart';
import 'worker_management_page.dart';

class ProjectManagementPage extends StatefulWidget {
  final CheckinProject project;
  const ProjectManagementPage({super.key, required this.project});
  @override
  State<ProjectManagementPage> createState() => _ProjectManagementPageState();
}

class _ProjectManagementPageState extends State<ProjectManagementPage> {
  late CheckinProject project;
  List<CheckinTeam> teams = const [];
  List<CheckinShift> shifts = const [];
  List<WorkerAssignment> workers = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    project = widget.project;
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        ManagementService.teams(project.id),
        ManagementService.shifts(project.id),
        ManagementService.workers(project.id),
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
        appBar: AppBar(title: Text(project.name), actions: [
          IconButton(
              tooltip: '编辑项目',
              onPressed: _editProject,
              icon: const Icon(Icons.edit_outlined))
        ]),
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
                              '${project.gpsLat}, ${project.gpsLng}\n打卡范围 ${project.fenceRadius} 米 · ${project.status == 'active' ? '使用中' : '已停用'}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: _editProjectLocation)),
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
                                  builder: (_) =>
                                      AnomalyListPage(project: project))))),
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.assessment),
                          title: const Text('考勤报表'),
                          subtitle: const Text('项目日报、月报与工人明细'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ProjectReportPage(project: project))))),
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.photo_library_outlined),
                          title: const Text('打卡照片归档'),
                          subtitle: const Text('按日期查看项目工人的打卡照片'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ClockPhotoArchivePage(
                                      project: project))))),
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.manage_accounts_outlined),
                          title: const Text('用户管理'),
                          subtitle: const Text('新增、编辑、分组、个人班次和项目转移'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => WorkerManagementPage(
                                        project: project)));
                            if (mounted) _load();
                          })),
                  Card(
                      child: ListTile(
                          leading: const Icon(Icons.add_task),
                          title: const Text('主管补卡'),
                          subtitle: const Text('补齐缺失检查点，原因必填并永久留痕'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: workers.isEmpty ? null : _supplementClock)),
                  _header('班组', teams.length, shifts.isEmpty ? null : _addTeam),
                  if (teams.isEmpty) const ListTile(title: Text('暂未设置班组')),
                  ...teams.map((t) => ListTile(
                      leading: Icon(Icons.groups,
                          color: t.status == 1 ? null : Colors.grey),
                      title: Text(t.name),
                      subtitle: Text(
                          '默认班次：${_shiftName(t.shiftId)}${t.status == 1 ? '' : ' · 已停用'}'),
                      onTap: () => _manageTeamMembers(t),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') _editTeam(t);
                          if (value == 'members') _manageTeamMembers(t);
                          if (value == 'delete') _deleteTeam(t);
                          if (value == 'toggle') _toggleTeam(t);
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(
                              value: 'members', child: Text('管理成员')),
                          PopupMenuItem(
                              value: 'toggle',
                              child: Text(t.status == 1 ? '停用' : '启用')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('删除班组')),
                        ],
                      ))),
                  _header('班次', shifts.length, _addShift),
                  if (shifts.isEmpty) const ListTile(title: Text('暂未设置班次')),
                  ...shifts.map((s) => ListTile(
                      leading: Icon(Icons.schedule,
                          color: s.status == 1 ? null : Colors.grey),
                      title: Text(s.name),
                      subtitle: Text(
                          '${_typeName(s.shiftType)}  ${s.startTime}–${s.endTime}${s.crossDay ? '（跨日）' : ''}${s.status == 1 ? '' : ' · 已停用'}'),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) =>
                            value == 'edit' ? _editShift(s) : _toggleShift(s),
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(
                              value: 'toggle',
                              child: Text(s.status == 1 ? '停用' : '启用')),
                        ],
                      ))),
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

  Future<void> _supplementClock() async {
    final eligibleWorkers =
        workers.where((item) => item.shiftId != null).toList();
    if (eligibleWorkers.isEmpty) {
      _message('没有已分配班组和班次的工人');
      return;
    }
    var worker = eligibleWorkers.first;
    var checkpoints =
        (await ManagementService.checkpoints(worker.shiftId!)).data ??
            const <ScheduleCheckpoint>[];
    if (!mounted || checkpoints.isEmpty) {
      _message('该班次没有可补卡检查点');
      return;
    }
    var checkpoint = checkpoints.first;
    var clockTime = DateTime.now();
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: const Text('主管补卡'),
          content: DialogScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<int>(
                initialValue: worker.workerId,
                decoration: const InputDecoration(labelText: '工人'),
                items: eligibleWorkers
                    .map((w) => DropdownMenuItem(
                        value: w.workerId,
                        child:
                            Text(w.realName.isEmpty ? w.username : w.realName)))
                    .toList(),
                onChanged: (id) async {
                  worker = eligibleWorkers.firstWhere((w) => w.workerId == id);
                  final result =
                      await ManagementService.checkpoints(worker.shiftId!);
                  if (ctx.mounted && (result.data?.isNotEmpty ?? false)) {
                    setLocal(() {
                      checkpoints = result.data!;
                      checkpoint = checkpoints.first;
                    });
                  }
                },
              ),
              DropdownButtonFormField<int>(
                key: ValueKey(worker.shiftId),
                initialValue: checkpoint.id,
                decoration: const InputDecoration(labelText: '班次检查点'),
                items: checkpoints
                    .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} ${p.expectedTime}')))
                    .toList(),
                onChanged: (id) => setLocal(() =>
                    checkpoint = checkpoints.firstWhere((p) => p.id == id)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('补卡时间'),
                subtitle:
                    Text(DateFormat('yyyy-MM-dd HH:mm').format(clockTime)),
                onTap: () async {
                  final date = await showDatePicker(
                      context: ctx,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDate: clockTime);
                  if (date == null || !ctx.mounted) return;
                  final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(clockTime));
                  if (time != null) {
                    setLocal(() => clockTime = DateTime(date.year, date.month,
                        date.day, time.hour, time.minute));
                  }
                },
              ),
              TextField(
                  controller: reason,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '补卡原因（必填）')),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
                onPressed: () async {
                  if (reason.text.trim().isEmpty) return;
                  final result = await ManagementService.supplementClock({
                    'workerId': worker.workerId,
                    'projectId': project.id,
                    'teamId': worker.teamId,
                    'shiftId': worker.shiftId,
                    'checkpointId': checkpoint.id,
                    'attendanceDate':
                        DateFormat('yyyy-MM-dd').format(clockTime),
                    'clockTime': clockTime.toIso8601String(),
                    'reason': reason.text.trim()
                  });
                  if (!ctx.mounted) return;
                  if (result.isSuccess) {
                    Navigator.pop(ctx, true);
                  } else {
                    _message(result.message);
                  }
                },
                child: const Text('确认补卡')),
          ],
        ),
      ),
    );
    if (saved == true) _message('补卡成功，已写入调整历史');
  }

  Future<void> _addTeam() async {
    final controller = TextEditingController();
    var shiftId = shifts.first.id;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setLocal) => AlertDialog(
                    title: const Text('新增班组'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: controller,
                          autofocus: true,
                          decoration: const InputDecoration(labelText: '班组名称')),
                      DropdownButtonFormField<int>(
                        value: shiftId,
                        decoration: const InputDecoration(labelText: '默认班次'),
                        items: shifts
                            .map((shift) => DropdownMenuItem(
                                value: shift.id, child: Text(shift.name)))
                            .toList(),
                        onChanged: (value) =>
                            setLocal(() => shiftId = value ?? shiftId),
                      ),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () async {
                            if (controller.text.trim().isEmpty) return;
                            final r = await ManagementService.createTeam(
                                project.id, {
                              'name': controller.text.trim(),
                              'shiftId': shiftId,
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

  Future<void> _addShift() async {
    final name = TextEditingController();
    var type = 'day';
    var start = const TimeOfDay(hour: 6, minute: 30);
    var breakStart = const TimeOfDay(hour: 11, minute: 30);
    var breakEnd = const TimeOfDay(hour: 13, minute: 0);
    var end = const TimeOfDay(hour: 17, minute: 30);
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setLocal) => AlertDialog(
                    title: const Text('新增班次'),
                    content: DialogScrollView(
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
                      if (type == 'day')
                        ListTile(
                            title: const Text('中午下班'),
                            trailing: Text(breakStart.format(ctx)),
                            onTap: () async {
                              final v = await showTimePicker(
                                  context: ctx, initialTime: breakStart);
                              if (v != null) setLocal(() => breakStart = v);
                            }),
                      if (type == 'day')
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
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.timer_outlined),
                        title: Text('固定打卡窗口'),
                        subtitle: Text('上班：提前30分钟至延后5分钟\n下班：标准时间至延后30分钟'),
                      ),
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
                                project.id, {
                              'name': name.text.trim(),
                              'shiftType': type,
                              'startTime': _time(start),
                              'endTime': _time(end),
                              'crossDay': cross ? 1 : 0,
                              if (type == 'day')
                                'breakStartTime': _time(breakStart),
                              if (type == 'day')
                                'breakEndTime': _time(breakEnd),
                              'graceBeforeMinutes': 30,
                              'graceAfterMinutes': 30,
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
                    content: DialogScrollView(
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
                                project.id, {
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
                                worker.workerId, project.id, teamId, shiftId);
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

  Future<void> _editProject() async {
    final name = TextEditingController(text: project.name);
    var radius = project.fenceRadius;
    var active = project.status == 'active';
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: const Text('编辑项目'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: '项目名称')),
            DropdownButtonFormField<int>(
              initialValue: radius,
              decoration: const InputDecoration(labelText: '打卡范围'),
              items: const [100, 200, 300, 500]
                  .map((v) => DropdownMenuItem(value: v, child: Text('$v 米')))
                  .toList(),
              onChanged: (v) => setLocal(() => radius = v ?? radius),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('项目启用'),
              subtitle: const Text('停用后工人不能打卡'),
              value: active,
              onChanged: (v) => setLocal(() => active = v),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final result = await ManagementService.updateProject(
                  project.id,
                  {
                    'name': name.text.trim(),
                    'gpsLat': project.gpsLat,
                    'gpsLng': project.gpsLng,
                    'fenceRadius': radius,
                    'status': active ? 'active' : 'inactive',
                  },
                );
                if (!ctx.mounted) return;
                if (result.isSuccess && result.data != null) {
                  setState(() => project = result.data!);
                  Navigator.pop(ctx, true);
                } else {
                  _message(result.message);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) _message('项目已更新');
  }

  Future<void> _editProjectLocation() async {
    final updated = await Navigator.push<CheckinProject>(
      context,
      MaterialPageRoute(
          builder: (_) => ProjectLocationPickerPage(project: project)),
    );
    if (updated != null && mounted) {
      setState(() => project = updated);
      _message('项目定位和打卡范围已更新');
    }
  }

  Future<void> _editShift(CheckinShift shift) async {
    final name = TextEditingController(text: shift.name);
    var type = shift.shiftType;
    var start = _parseTime(shift.startTime);
    var end = _parseTime(shift.endTime);
    var breakStart = _parseTime(shift.breakStartTime ?? '11:30:00');
    var breakEnd = _parseTime(shift.breakEndTime ?? '13:00:00');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: const Text('编辑班次'),
          content: DialogScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '班次名称')),
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: '班次类型'),
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('白班')),
                  DropdownMenuItem(value: 'night', child: Text('夜班')),
                ],
                onChanged: (v) => setLocal(() => type = v ?? type),
              ),
              _timeTile(ctx, '开始时间', start, (v) => setLocal(() => start = v)),
              if (type == 'day') ...[
                _timeTile(ctx, '中午下班', breakStart,
                    (v) => setLocal(() => breakStart = v)),
                _timeTile(
                    ctx, '下午上班', breakEnd, (v) => setLocal(() => breakEnd = v)),
              ],
              _timeTile(ctx, '结束时间', end, (v) => setLocal(() => end = v)),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.timer_outlined),
                title: Text('固定打卡窗口'),
                subtitle: Text('上班：提前30分钟至延后5分钟\n下班：标准时间至延后30分钟'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                final result = await ManagementService.updateShift(shift.id, {
                  'name': name.text.trim(),
                  'shiftType': type,
                  'startTime': _time(start),
                  'endTime': _time(end),
                  'crossDay': _minutes(end) <= _minutes(start) ? 1 : 0,
                  if (type == 'day') 'breakStartTime': _time(breakStart),
                  if (type == 'day') 'breakEndTime': _time(breakEnd),
                  'graceBeforeMinutes': 30,
                  'graceAfterMinutes': 30,
                  'status': shift.status,
                });
                if (!ctx.mounted) return;
                if (result.isSuccess) {
                  Navigator.pop(ctx, true);
                } else {
                  _message(result.message);
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) _load();
  }

  Widget _timeTile(BuildContext context, String label, TimeOfDay value,
      ValueChanged<TimeOfDay> onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value.format(context)),
      onTap: () async {
        final selected =
            await showTimePicker(context: context, initialTime: value);
        if (selected != null) onChanged(selected);
      },
    );
  }

  Future<void> _toggleShift(CheckinShift shift) async {
    final next = shift.status == 1 ? 0 : 1;
    final confirmed = await _confirm(
      next == 0 ? '停用班次' : '启用班次',
      next == 0 ? '停用后分配到该班次的工人不能打卡，历史记录不会删除。' : '确定重新启用“${shift.name}”吗？',
    );
    if (!confirmed) return;
    final result = await ManagementService.updateShift(shift.id, {
      'name': shift.name,
      'shiftType': shift.shiftType,
      'startTime': shift.startTime,
      'endTime': shift.endTime,
      'crossDay': shift.crossDay ? 1 : 0,
      if (shift.breakStartTime != null) 'breakStartTime': shift.breakStartTime,
      if (shift.breakEndTime != null) 'breakEndTime': shift.breakEndTime,
      'graceBeforeMinutes':
          shift.shiftType == 'day' ? 5 : shift.graceBeforeMinutes,
      'graceAfterMinutes':
          shift.shiftType == 'day' ? 5 : shift.graceAfterMinutes,
      'status': next,
    });
    if (result.isSuccess) {
      _load();
    } else {
      _message(result.message);
    }
  }

  Future<void> _editTeam(CheckinTeam team) async {
    final name = TextEditingController(text: team.name);
    var shiftId = team.shiftId;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (_, setLocal) => AlertDialog(
                title: const Text('编辑班组'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      autofocus: true,
                      decoration: const InputDecoration(labelText: '班组名称')),
                  DropdownButtonFormField<int>(
                    value: shiftId,
                    decoration: const InputDecoration(labelText: '默认班次'),
                    items: shifts
                        .map((shift) => DropdownMenuItem(
                            value: shift.id, child: Text(shift.name)))
                        .toList(),
                    onChanged: (value) =>
                        setLocal(() => shiftId = value ?? shiftId),
                  ),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      final result = await ManagementService.updateTeam(
                          team.id, {
                        'name': name.text.trim(),
                        'shiftId': shiftId,
                        'status': team.status
                      });
                      if (!ctx.mounted) return;
                      if (result.isSuccess) {
                        Navigator.pop(ctx, true);
                      } else {
                        _message(result.message);
                      }
                    },
                    child: const Text('保存'),
                  ),
                ],
              )),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleTeam(CheckinTeam team) async {
    final next = team.status == 1 ? 0 : 1;
    final confirmed = await _confirm(
      next == 0 ? '停用班组' : '启用班组',
      next == 0 ? '停用后不能再分配工人；已有工人的班组需先调整人员。' : '确定重新启用“${team.name}”吗？',
    );
    if (!confirmed) return;
    final result = await ManagementService.updateTeam(
        team.id, {'name': team.name, 'shiftId': team.shiftId, 'status': next});
    if (result.isSuccess) {
      _load();
    } else {
      _message(result.message);
    }
  }

  String _shiftName(int id) =>
      shifts
          .where((shift) => shift.id == id)
          .map((shift) => shift.name)
          .firstOrNull ??
      '未设置';

  Future<void> _manageTeamMembers(CheckinTeam team) async {
    await showDialog<void>(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (_, setLocal) {
              final members =
                  workers.where((worker) => worker.teamId == team.id).toList();
              final available =
                  workers.where((worker) => worker.teamId != team.id).toList();
              return AlertDialog(
                title: Text('${team.name} · 成员管理'),
                content: SizedBox(
                    width: 420,
                    child: ListView(shrinkWrap: true, children: [
                      if (members.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: Text('暂无成员'))),
                      ...members.map((worker) => ListTile(
                            leading: const CircleAvatar(
                                child: Icon(Icons.person_outline)),
                            title: Text(worker.realName.isEmpty
                                ? worker.username
                                : worker.realName),
                            subtitle: Text(worker.personalShiftOverride
                                ? '${worker.shiftName}（个人班次）'
                                : '使用班组默认班次'),
                            trailing: IconButton(
                                tooltip: '移出班组',
                                icon: const Icon(Icons.person_remove_outlined),
                                onPressed: () async {
                                  final result =
                                      await ManagementService.removeTeamMember(
                                          team.id, worker.workerId);
                                  if (result.isSuccess) {
                                    await _load();
                                    setLocal(() {});
                                  } else if (ctx.mounted)
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                        SnackBar(
                                            content: Text(result.message)));
                                }),
                          )),
                      if (available.isNotEmpty) ...[
                        const Divider(),
                        ListTile(
                            leading: const Icon(Icons.person_add_alt_1),
                            title: const Text('添加成员'),
                            onTap: () async {
                              WorkerAssignment selected = available.first;
                              final chosen = await showDialog<WorkerAssignment>(
                                  context: ctx,
                                  builder: (pickCtx) => SimpleDialog(
                                        title: const Text('选择工人'),
                                        children: available
                                            .map((worker) => SimpleDialogOption(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          pickCtx, worker),
                                                  child: Text(
                                                      '${worker.realName.isEmpty ? worker.username : worker.realName}${worker.teamName.isEmpty ? '（未分组）' : '（当前：${worker.teamName}）'}'),
                                                ))
                                            .toList(),
                                      ));
                              if (chosen == null) return;
                              selected = chosen;
                              final result =
                                  await ManagementService.assignWorker(
                                      selected.workerId,
                                      project.id,
                                      team.id,
                                      null);
                              if (result.isSuccess) {
                                await _load();
                                setLocal(() {});
                              }
                            }),
                      ],
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('完成'))
                ],
              );
            }));
  }

  Future<void> _deleteTeam(CheckinTeam team) async {
    final members = workers.where((worker) => worker.teamId == team.id).length;
    if (members > 0) {
      _message('该班组还有 $members 名成员，请先移出成员');
      return;
    }
    final confirmed = await _confirm('删除班组', '确定删除“${team.name}”吗？历史打卡记录不会删除。');
    if (!confirmed) return;
    final result = await ManagementService.deleteTeam(team.id);
    if (result.isSuccess)
      _load();
    else
      _message(result.message);
  }

  Future<void> _editWorker(WorkerAssignment worker) async {
    final name = TextEditingController(text: worker.realName);
    final phone = TextEditingController(text: worker.phone ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑 ${worker.username}'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: '姓名')),
          TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: '手机号（选填）')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              final result =
                  await ManagementService.updateWorker(worker.workerId, {
                'realName': name.text.trim(),
                'phone': phone.text.trim(),
                'status': worker.status,
              });
              if (!ctx.mounted) return;
              if (result.isSuccess) {
                Navigator.pop(ctx, true);
              } else {
                _message(result.message);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _toggleWorker(WorkerAssignment worker) async {
    final next = worker.status == 1 ? 0 : 1;
    final confirmed = await _confirm(
      next == 0 ? '停用工人账号' : '启用工人账号',
      next == 0 ? '停用后该工人将不能登录或打卡，历史记录仍永久保留。' : '确定允许该工人重新登录和打卡吗？',
    );
    if (!confirmed) return;
    final result = await ManagementService.updateWorker(worker.workerId, {
      'realName': worker.realName,
      'phone': worker.phone,
      'status': next,
    });
    if (result.isSuccess) {
      _load();
    } else {
      _message(result.message);
    }
  }

  Future<void> _resetWorkerPassword(WorkerAssignment worker) async {
    final confirmed = await _confirm(
      '重置工人密码',
      '确定将“${worker.realName.isEmpty ? worker.username : worker.realName}”的密码重置为 123456 吗？',
    );
    if (!confirmed) return;
    final result = await ManagementService.resetWorkerPassword(worker.workerId);
    _message(result.isSuccess ? '密码已重置为 123456' : result.message);
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('取消')),
              FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('确认')),
            ],
          ),
        ) ??
        false;
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  int _minutes(TimeOfDay value) => value.hour * 60 + value.minute;
  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

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
