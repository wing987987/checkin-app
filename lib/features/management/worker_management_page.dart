// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../models/checkin_project.dart';
import '../../models/checkin_shift.dart';
import '../../models/checkin_team.dart';
import '../../models/worker_assignment.dart';
import '../../services/management_service.dart';
import '../../core/widgets/dialog_scroll_view.dart';

class WorkerManagementPage extends StatefulWidget {
  final CheckinProject project;
  const WorkerManagementPage({super.key, required this.project});
  @override
  State<WorkerManagementPage> createState() => _WorkerManagementPageState();
}

class _WorkerManagementPageState extends State<WorkerManagementPage> {
  List<WorkerAssignment> workers = const [];
  List<CheckinTeam> teams = const [];
  List<CheckinShift> shifts = const [];
  List<CheckinProject> projects = const [];
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
        ManagementService.workers(widget.project.id),
        ManagementService.teams(widget.project.id),
        ManagementService.shifts(widget.project.id),
        ManagementService.projects(),
      ]);
      if (!mounted) return;
      setState(() {
        workers = values[0].data as List<WorkerAssignment>? ?? const [];
        teams = values[1].data as List<CheckinTeam>? ?? const [];
        shifts = values[2].data as List<CheckinShift>? ?? const [];
        projects = values[3].data as List<CheckinProject>? ?? const [];
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.project.name} · 用户管理')),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: teams.isEmpty ? null : () => _edit(),
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('新增用户')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: workers.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 180),
                        Center(child: Text('该项目暂无工人'))
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: workers.length,
                        itemBuilder: (_, index) => _workerCard(workers[index])),
              ),
      );

  Widget _workerCard(WorkerAssignment worker) => Card(
          child: ListTile(
        leading: CircleAvatar(
            child: Text(worker.realName.isEmpty
                ? '?'
                : worker.realName.substring(0, 1))),
        title:
            Text(worker.realName.isEmpty ? worker.username : worker.realName),
        subtitle: Text(
            '用户名：${worker.username}\n${worker.teamName.isEmpty ? '未分配班组' : worker.teamName} · ${worker.shiftName.isEmpty ? '未设置班次' : worker.shiftName}${worker.personalShiftOverride ? '（个人班次）' : '（班组班次）'}'),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') _edit(worker);
            if (value == 'transfer') _transfer(worker);
            if (value == 'reset') _reset(worker);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('编辑用户')),
            PopupMenuItem(value: 'transfer', child: Text('项目转移')),
            PopupMenuItem(value: 'reset', child: Text('重置密码')),
          ],
        ),
      ));

  Future<void> _edit([WorkerAssignment? worker]) async {
    final creating = worker == null;
    final username = TextEditingController(text: worker?.username ?? '');
    final password = TextEditingController(text: '123456');
    final name = TextEditingController(text: worker?.realName ?? '');
    final phone = TextEditingController(text: worker?.phone ?? '');
    int teamId = worker?.teamId ?? (teams.isEmpty ? 0 : teams.first.id);
    int personalShiftId = worker?.personalShiftId ?? 0;
    var enabled = worker?.status != 0;
    final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (_, setLocal) => AlertDialog(
                title: Text(creating ? '新增用户' : '编辑用户'),
                content: DialogScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _fieldLabel('姓名'),
                      TextField(
                          controller: name,
                          decoration: const InputDecoration(hintText: '请输入姓名')),
                      const SizedBox(height: 16),
                      _fieldLabel('登录用户名'),
                      TextField(
                          controller: username,
                          readOnly: !creating,
                          enableInteractiveSelection: true,
                          decoration:
                              const InputDecoration(hintText: '请输入登录用户名')),
                      if (!creating) ...[
                        const SizedBox(height: 4),
                        const Text('用户名不可修改，长按可复制',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF92939A))),
                      ],
                      if (creating) ...[
                        const SizedBox(height: 16),
                        _fieldLabel('初始密码'),
                        TextField(
                            controller: password,
                            obscureText: true,
                            decoration:
                                const InputDecoration(hintText: '请输入初始密码')),
                      ],
                      const SizedBox(height: 16),
                      _fieldLabel('手机号（选填）'),
                      TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(hintText: '请输入手机号')),
                      const SizedBox(height: 16),
                      _fieldLabel('班组'),
                      DropdownButtonFormField<int>(
                        value: teamId,
                        decoration: const InputDecoration(),
                        items: [
                          if (!creating)
                            const DropdownMenuItem(
                                value: 0, child: Text('暂不分配班组')),
                          ...teams.map((team) => DropdownMenuItem(
                              value: team.id, child: Text(team.name))),
                        ],
                        onChanged: (value) => setLocal(() {
                          teamId = value ?? 0;
                          if (teamId == 0) personalShiftId = 0;
                        }),
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('个人班次（选填）'),
                      DropdownButtonFormField<int>(
                        value: personalShiftId,
                        decoration: const InputDecoration(),
                        items: [
                          const DropdownMenuItem(
                              value: 0, child: Text('使用班组默认班次')),
                          ...shifts.map((shift) => DropdownMenuItem(
                              value: shift.id, child: Text(shift.name))),
                        ],
                        onChanged: teamId == 0
                            ? null
                            : (value) =>
                                setLocal(() => personalShiftId = value ?? 0),
                      ),
                      if (personalShiftId != 0)
                        const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text('已选择个人班次：该用户将使用此班次，不再使用班组默认班次。',
                                style: TextStyle(color: Colors.orange))),
                      if (!creating)
                        SwitchListTile(
                            contentPadding: const EdgeInsets.only(top: 8),
                            title: const Text('账号启用'),
                            value: enabled,
                            onChanged: (value) =>
                                setLocal(() => enabled = value)),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () async {
                        if (name.text.trim().isEmpty ||
                            creating && username.text.trim().isEmpty ||
                            teamId == 0 && creating) return;
                        final result = creating
                            ? await ManagementService.createWorker(
                                widget.project.id, {
                                'username': username.text.trim(),
                                'password': password.text,
                                'realName': name.text.trim(),
                                'phone': phone.text.trim(),
                                'teamId': teamId,
                                'shiftId': personalShiftId == 0
                                    ? null
                                    : personalShiftId,
                              })
                            : await ManagementService.updateWorker(
                                worker.workerId, {
                                'realName': name.text.trim(),
                                'phone': phone.text.trim(),
                                'status': enabled ? 1 : 0,
                                'teamId': teamId == 0 ? null : teamId,
                                'shiftId': personalShiftId == 0
                                    ? null
                                    : personalShiftId,
                              });
                        if (!ctx.mounted) return;
                        if (result.isSuccess)
                          Navigator.pop(ctx, true);
                        else
                          ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(content: Text(result.message)));
                      },
                      child: const Text('保存')),
                ],
              ),
            ));
    if (saved == true) _load();
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      );

  Future<void> _transfer(WorkerAssignment worker) async {
    final targets =
        projects.where((project) => project.id != widget.project.id).toList();
    if (targets.isEmpty) {
      _message('没有其他可管理项目');
      return;
    }
    var target = targets.first;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (_, setLocal) => AlertDialog(
                title: Text('转移 ${worker.realName}'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  DropdownButtonFormField<int>(
                      value: target.id,
                      decoration: const InputDecoration(hintText: '目标项目'),
                      items: targets
                          .map((project) => DropdownMenuItem(
                              value: project.id, child: Text(project.name)))
                          .toList(),
                      onChanged: (id) => setLocal(() => target =
                          targets.firstWhere((project) => project.id == id))),
                  const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('转移后原班组和个人班次将清空，需要在目标项目重新分配。历史打卡记录永久保留。',
                          style: TextStyle(color: Colors.orange))),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('确认转移'))
                ],
              ),
            ));
    if (confirmed != true) return;
    final result =
        await ManagementService.transferWorker(worker.workerId, target.id);
    if (result.isSuccess) {
      _message('已转移到 ${target.name}');
      _load();
    } else {
      _message(result.message);
    }
  }

  Future<void> _reset(WorkerAssignment worker) async {
    final result = await ManagementService.resetWorkerPassword(worker.workerId);
    _message(result.isSuccess ? '密码已重置为 123456' : result.message);
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
