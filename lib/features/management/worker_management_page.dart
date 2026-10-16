// ignore_for_file: deprecated_member_use, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'assignment_history_page.dart';

import '../../models/checkin_project.dart';
import '../../models/checkin_shift.dart';
import '../../models/checkin_team.dart';
import '../../models/worker_assignment.dart';
import '../../models/checkin_job_type.dart';
import '../../services/management_service.dart';
import '../../core/widgets/dialog_scroll_view.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/app_theme.dart';

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
  List<CheckinJobType> jobTypes = const [];
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
        ManagementService.jobTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        workers = values[0].data as List<WorkerAssignment>? ?? const [];
        teams = values[1].data as List<CheckinTeam>? ?? const [];
        shifts = values[2].data as List<CheckinShift>? ?? const [];
        projects = values[3].data as List<CheckinProject>? ?? const [];
        jobTypes = values[4].data as List<CheckinJobType>? ?? const [];
      });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('${widget.project.name} · 用户管理'), actions: [
          IconButton(
              tooltip: '分配 / 转移记录',
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AssignmentHistoryPage(
                          projectId: widget.project.id)))),
        ]),
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
          child: Column(children: [
        ListTile(
          leading: CircleAvatar(
              child: Text(worker.realName.isEmpty
                  ? '?'
                  : worker.realName.substring(0, 1))),
          title: Text(
              '${worker.realName.isEmpty ? worker.username : worker.realName}${worker.role == 'supervisor' ? '（主管）' : ''}'),
          subtitle: Text(
              '用户名：${worker.username} · 工种：${worker.jobType?.isNotEmpty == true ? worker.jobType : '未设置'}\n${worker.teamName.isEmpty ? '未分配班组' : worker.teamName} · ${worker.shiftName.isEmpty ? '未设置班次' : worker.shiftName}${worker.personalShiftOverride ? '（个人班次）' : '（班组班次）'}'),
          isThreeLine: true,
          trailing: worker.workerId ==
                  context.watch<AuthProvider>().currentUser?.id
              ? const Text('本人 · 只读')
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'history')
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => AssignmentHistoryPage(
                                  projectId: widget.project.id,
                                  workerId: worker.workerId)));
                    if (value == 'promote') _promote(worker);
                    if (value == 'edit') _edit(worker);
                    if (value == 'transfer') _transfer(worker);
                    if (value == 'reset') _reset(worker);
                    if (value == 'field') _fieldWork(worker);
                    if (value == 'fieldHistory') _fieldHistory(worker);
                  },
                  itemBuilder: (_) => [
                    if (context.read<AuthProvider>().isBoss &&
                        worker.role == 'worker')
                      const PopupMenuItem(
                          value: 'promote', child: Text('转为主管')),
                    const PopupMenuItem(
                        value: 'history', child: Text('分配 / 转移记录')),
                    PopupMenuItem(value: 'edit', child: Text('编辑用户')),
                    PopupMenuItem(value: 'transfer', child: Text('项目转移')),
                    PopupMenuItem(value: 'reset', child: Text('重置密码')),
                    PopupMenuItem(value: 'field', child: Text('外勤安排 / 取消')),
                    PopupMenuItem(value: 'fieldHistory', child: Text('外勤操作记录')),
                  ],
                ),
        ),
        SwitchListTile(
          title: const Text('允许打卡'),
          subtitle: Text(worker.pauseStatus == 'pause_scheduled'
              ? '已安排次日起暂停'
              : worker.pauseStatus == 'resume_scheduled'
                  ? '已暂停，安排次日起恢复'
                  : worker.clockPaused
                      ? '已暂停 · 可登录，不能打卡'
                      : '正常打卡'),
          value: !worker.clockPaused && worker.pauseStatus != 'pause_scheduled',
          onChanged:
              worker.workerId == context.watch<AuthProvider>().currentUser?.id
                  ? null
                  : (_) => _changePause(worker),
        ),
        Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 8, children: [
              TextButton.icon(
                  onPressed: worker.workerId ==
                          context.watch<AuthProvider>().currentUser?.id
                      ? null
                      : () => _fieldWork(worker),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('外勤安排')),
              TextButton(
                  onPressed: () => _pauseHistory(worker),
                  child: const Text('暂停 / 恢复记录'))
            ]))
      ]));

  Future<void> _promote(WorkerAssignment worker) async {
    final selected = <int>{widget.project.id};
    var saving = false;
    String? error;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
          builder: (_, update) => AlertDialog(
                title: Text('将${worker.realName}转为主管'),
                content: SizedBox(
                    width: double.maxFinite,
                    child: DialogScrollView(
                        child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('账号：${worker.username}'),
                        const SizedBox(height: 12),
                        const Text(
                            '手机号账号、密码、历史考勤和原考勤安排均保留。转换后可管理所选项目，需退出账号重新登录。'),
                        const SizedBox(height: 16),
                        const Text('负责项目（至少选择一个）'),
                        ...projects.map((project) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(project.name),
                              value: selected.contains(project.id),
                              onChanged: saving
                                  ? null
                                  : (value) => update(() {
                                        value == true
                                            ? selected.add(project.id)
                                            : selected.remove(project.id);
                                      }),
                            )),
                        if (error != null)
                          Text(error!,
                              style: const TextStyle(color: Colors.red)),
                      ],
                    ))),
                actions: [
                  TextButton(
                      onPressed:
                          saving ? null : () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (selected.isEmpty) {
                                update(() => error = '请至少选择一个负责项目');
                                return;
                              }
                              update(() {
                                saving = true;
                                error = null;
                              });
                              try {
                                final result =
                                    await ManagementService.promoteWorker(
                                        worker.workerId, selected.toList());
                                if (!ctx.mounted) return;
                                if (result.isSuccess) {
                                  Navigator.pop(ctx, true);
                                } else {
                                  update(() {
                                    error = result.message;
                                    saving = false;
                                  });
                                }
                              } catch (_) {
                                if (ctx.mounted)
                                  update(() {
                                    error = '转换失败，请检查网络后重试';
                                    saving = false;
                                  });
                              }
                            },
                      child: Text(saving ? '处理中…' : '确认转为主管')),
                ],
              )),
    );
    if (saved == true && mounted) {
      _message('已转为主管，请该用户退出账号后重新登录');
      await _load();
    }
  }

  Future<void> _fieldWork(WorkerAssignment worker) async {
    try {
      final plans = await ManagementService.fieldWorkPlans(
          worker.workerId, widget.project.id);
      if (!mounted) return;
      if (!plans.isSuccess) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(plans.message)));
        return;
      }
      final reason = TextEditingController();
      final today = DateTime.now().toUtc().add(const Duration(hours: 8));
      var nextDay = false, saving = false;
      String? error;
      String date() => today
          .add(Duration(days: nextDay ? 1 : 0))
          .toIso8601String()
          .substring(0, 10);
      bool active() => (plans.data ?? []).any((p) =>
          p['attendanceDate'].toString().substring(0, 10) == date() &&
          p['status'] == 'active');
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => StatefulBuilder(
              builder: (_, update) => AlertDialog(
                    title: const Text('外勤安排'),
                    content: DialogScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(worker.realName,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                          const SizedBox(height: 16),
                          SegmentedButton<bool>(
                              expandedInsets: EdgeInsets.zero,
                              segments: const [
                                ButtonSegment(
                                    value: false, label: Text('当天外勤')),
                                ButtonSegment(value: true, label: Text('次日外勤'))
                              ],
                              selected: {nextDay},
                              onSelectionChanged: saving
                                  ? null
                                  : (v) => update(() {
                                        nextDay = v.first;
                                        error = null;
                                      })),
                          const SizedBox(height: 12),
                          Text(
                              '${date()} · ${active() ? '已安排外勤，可取消' : '未安排外勤'}',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: AppColors.surfaceSubtle,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text(
                                  '外勤只需上班、下班两次定位拍照，不限制围栏或原班次时间。完整有效计1工，不扣午休、无加班；缺卡计0工，次日结算。暂停优先。\n普通记录保留，但该日只按外勤结算；已有外勤打卡后不能取消。',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.6))),
                          const SizedBox(height: 12),
                          TextField(
                              controller: reason,
                              enabled: !saving,
                              maxLength: 500,
                              minLines: 2,
                              maxLines: 4,
                              decoration: InputDecoration(
                                  labelText:
                                      active() ? '取消原因（必填）' : '外勤事由（必填）')),
                          if (error != null)
                            Text(error!,
                                style:
                                    const TextStyle(color: AppColors.danger)),
                        ])),
                    actions: [
                      TextButton(
                          onPressed: saving ? null : () => Navigator.pop(ctx),
                          child: const Text('返回')),
                      FilledButton(
                          onPressed: saving
                              ? null
                              : () async {
                                  if (reason.text.trim().isEmpty) {
                                    update(() => error = '请填写原因');
                                    return;
                                  }
                                  update(() {
                                    saving = true;
                                    error = null;
                                  });
                                  try {
                                    final result =
                                        await ManagementService.changeFieldWork(
                                            worker.workerId,
                                            widget.project.id,
                                            date(),
                                            active() ? 'cancel' : 'arrange',
                                            reason.text.trim());
                                    if (!ctx.mounted) return;
                                    if (result.isSuccess) {
                                      Navigator.pop(ctx);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text('外勤安排已更新')));
                                    } else {
                                      update(() {
                                        saving = false;
                                        error = result.message;
                                      });
                                    }
                                  } catch (_) {
                                    if (ctx.mounted)
                                      update(() {
                                        saving = false;
                                        error = '操作失败，请检查网络后重试';
                                      });
                                  }
                                },
                          child: Text(saving
                              ? '保存中…'
                              : active()
                                  ? '取消外勤安排'
                                  : '确认安排外勤'))
                    ],
                  )));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      reason.dispose();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('外勤安排加载失败')));
    }
  }

  Future<void> _fieldHistory(WorkerAssignment worker) async {
    try {
      final r = await ManagementService.fieldWorkPlans(
          worker.workerId, widget.project.id,
          history: true);
      if (!mounted) return;
      if (!r.isSuccess) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(r.message)));
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text('${worker.realName} · 外勤记录'),
                  content: SizedBox(
                      width: 420,
                      child: DialogScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (r.data?.isEmpty != false) const Text('暂无操作记录'),
                        for (final row in r.data ?? <Map<String, dynamic>>[])
                          ListTile(
                              title: Text(
                                  '${row['attendanceDate']} · ${row['action'] == 'arrange' ? '安排外勤' : '取消外勤'}'),
                              subtitle: Text(
                                  '${row['actorName']} · ${row['createTime']}\n${row['reason']}')),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('关闭'))
                  ]));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作记录加载失败')));
    }
  }

  Future<void> _changePause(WorkerAssignment worker) async {
    final resume =
        worker.clockPaused || worker.pauseStatus == 'pause_scheduled';
    final reason = TextEditingController();
    var effective = 'now';
    var saving = false;
    String? failure;
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => StatefulBuilder(
            builder: (_, update) => AlertDialog(
                  title: Text(resume ? '恢复打卡' : '暂停打卡'),
                  content: DialogScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(worker.realName,
                            style: const TextStyle(
                                fontSize: 14, color: AppColors.textSecondary)),
                        const SizedBox(height: 20),
                        const Text('生效时间',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                            expandedInsets: EdgeInsets.zero,
                            segments: [
                              ButtonSegment(
                                  value: 'now',
                                  label: Text(resume ? '当天恢复' : '立即暂停')),
                              ButtonSegment(
                                  value: 'tomorrow',
                                  label: Text(resume ? '次日起恢复' : '次日起暂停'))
                            ],
                            selected: {effective},
                            onSelectionChanged: saving
                                ? null
                                : (v) => update(() => effective = v.first)),
                        const SizedBox(height: 16),
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: AppColors.surfaceSubtle,
                                borderRadius: BorderRadius.circular(8)),
                            child: Text(
                                resume
                                    ? '暂停期间不追补缺卡。待生效的暂停可通过当天恢复取消。主管补卡仍需填写原因并留痕。'
                                    : '暂停后仍可登录，不能普通或加班打卡。\n历史异常继续处理；当天已有打卡时，剩余缺卡提醒保留。后续暂停日免缺卡。',
                                style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.6,
                                    color: AppColors.textSecondary))),
                        const SizedBox(height: 16),
                        TextField(
                            controller: reason,
                            enabled: !saving,
                            maxLength: 500,
                            minLines: 2,
                            maxLines: 4,
                            decoration:
                                const InputDecoration(labelText: '原因（必填）')),
                        if (failure != null)
                          Text(failure!,
                              style: const TextStyle(color: AppColors.danger)),
                      ])),
                  actions: [
                    TextButton(
                        onPressed:
                            saving ? null : () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (reason.text.trim().isEmpty) {
                                  update(() => failure = '请填写原因');
                                  return;
                                }
                                update(() {
                                  saving = true;
                                  failure = null;
                                });
                                try {
                                  final result = await ManagementService
                                      .changeAttendancePause(
                                          worker.workerId,
                                          widget.project.id,
                                          resume ? 'resume' : 'pause',
                                          effective,
                                          reason.text.trim());
                                  if (!ctx.mounted) return;
                                  if (result.isSuccess) {
                                    Navigator.pop(ctx, true);
                                  } else {
                                    update(() {
                                      saving = false;
                                      failure = result.message;
                                    });
                                  }
                                } catch (_) {
                                  update(() {
                                    saving = false;
                                    failure = '操作失败，请检查网络后重试';
                                  });
                                }
                              },
                        child: Text(saving ? '保存中…' : '确定'))
                  ],
                )));
    // The dialog's closing animation may still reference its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    reason.dispose();
    if (saved == true && mounted) await _load();
  }

  Future<void> _pauseHistory(WorkerAssignment worker) async {
    try {
      final result = await ManagementService.attendancePauseHistory(
          worker.workerId, widget.project.id);
      if (!mounted) return;
      if (!result.isSuccess) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text('${worker.realName} · 操作记录'),
                  content: SizedBox(
                      width: 420,
                      child: DialogScrollView(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                        if (result.data?.isEmpty != false) const Text('暂无记录'),
                        for (final row
                            in result.data ?? <Map<String, dynamic>>[])
                          ListTile(
                              title: Text(
                                  '${row['action'] == 'pause' ? '暂停' : row['action'] == 'cancel_pause' ? '取消暂停安排' : '恢复'} · ${row['actorName'] ?? ''}'),
                              subtitle: Text(
                                  '生效：${row['effectiveAt']}\n原因：${row['reason']}\n操作时间：${row['createTime']}')),
                      ]))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('关闭'))
                  ]));
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('无法加载操作记录')));
    }
  }

  Future<void> _edit([WorkerAssignment? worker]) async {
    final creating = worker == null;
    final username = TextEditingController(text: worker?.username ?? '');
    final password = TextEditingController(text: '123456');
    final name = TextEditingController(text: worker?.realName ?? '');
    String? jobType = jobTypes.any((type) => type.name == worker?.jobType)
        ? worker!.jobType
        : null;
    final phone = TextEditingController(text: worker?.phone ?? '');
    int teamId = worker?.teamId ?? (teams.isEmpty ? 0 : teams.first.id);
    int personalShiftId = worker?.personalShiftId ?? 0;
    var extraShiftOverride = worker?.extraShiftOverride ?? false;
    final extraShiftIds = (worker?.extraShiftIds ?? const <int>[]).toSet();
    var enabled = worker?.status != 0;
    String? nameError;
    String? jobTypeError;
    String? usernameError;
    String? passwordError;
    String? teamError;
    String? saveError;
    var saving = false;
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
                          decoration: InputDecoration(
                              hintText: '请输入姓名', errorText: nameError)),
                      const SizedBox(height: 16),
                      _fieldLabel('工种'),
                      DropdownButtonFormField<String>(
                          value: jobType,
                          decoration: InputDecoration(
                              hintText: '请选择工种', errorText: jobTypeError),
                          items: jobTypes
                              .map((type) => DropdownMenuItem(
                                  value: type.name, child: Text(type.name)))
                              .toList(),
                          onChanged: (value) => setLocal(() {
                                jobType = value;
                                jobTypeError = null;
                                saveError = null;
                              })),
                      const SizedBox(height: 16),
                      _fieldLabel('登录用户名'),
                      TextField(
                          controller: username,
                          enableInteractiveSelection: true,
                          decoration: InputDecoration(
                              hintText: '请输入登录用户名', errorText: usernameError)),
                      if (!creating) ...[
                        const SizedBox(height: 4),
                        const Text('修改后需使用新用户名登录，密码不变',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFF92939A))),
                      ],
                      if (creating) ...[
                        const SizedBox(height: 16),
                        _fieldLabel('初始密码'),
                        TextField(
                            controller: password,
                            obscureText: true,
                            decoration: InputDecoration(
                                hintText: '请输入初始密码', errorText: passwordError)),
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
                        decoration: InputDecoration(errorText: teamError),
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
                          teamError = null;
                          saveError = null;
                        }),
                      ),
                      if (teamId != 0) ...[
                        const SizedBox(height: 6),
                        Text(
                          '班组默认主班次：${_teamShiftName(teamId)}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
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
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('个人设置附加班次'),
                        subtitle: Text(extraShiftOverride
                            ? '覆盖班组设置，可单独选择允许的附加班次'
                            : '使用班组的附加班次设置'),
                        value: extraShiftOverride,
                        onChanged: (value) =>
                            setLocal(() => extraShiftOverride = value),
                      ),
                      if (extraShiftOverride)
                        ...shifts
                            .where((shift) =>
                                shift.id != personalShiftId &&
                                !(personalShiftId == 0 &&
                                    teams.any((team) =>
                                        team.id == teamId &&
                                        team.shiftId == shift.id)))
                            .map((shift) => CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(shift.name),
                                  subtitle: const Text('不打卡不算缺勤'),
                                  value: extraShiftIds.contains(shift.id),
                                  onChanged: (value) => setLocal(() =>
                                      value == true
                                          ? extraShiftIds.add(shift.id)
                                          : extraShiftIds.remove(shift.id)),
                                )),
                      if (!creating)
                        SwitchListTile(
                            contentPadding: const EdgeInsets.only(top: 8),
                            title: const Text('账号启用'),
                            value: enabled,
                            onChanged: (value) =>
                                setLocal(() => enabled = value)),
                    ])),
                actions: [
                  if (saveError != null)
                    SizedBox(
                      width: double.infinity,
                      child: Text(saveError!,
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.error)),
                    ),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              final usernameValue = username.text.trim();
                              setLocal(() {
                                nameError =
                                    name.text.trim().isEmpty ? '请输入姓名' : null;
                                jobTypeError = jobType == null
                                    ? jobTypes.isEmpty
                                        ? '请先在工种管理中添加工种'
                                        : '请选择工种'
                                    : null;
                                usernameError = (usernameValue.length < 3 ||
                                        usernameValue.length > 32)
                                    ? '登录用户名需为 3–32 个字符'
                                    : null;
                                passwordError = creating &&
                                        (password.text.length < 4 ||
                                            password.text.length > 64)
                                    ? '初始密码需为 4–64 个字符'
                                    : null;
                                teamError =
                                    creating && teamId == 0 ? '请选择班组' : null;
                                saveError = [
                                  nameError,
                                  jobTypeError,
                                  usernameError,
                                  passwordError,
                                  teamError
                                ].whereType<String>().join('；');
                                if (saveError!.isEmpty) saveError = null;
                              });
                              if (nameError != null ||
                                  jobTypeError != null ||
                                  usernameError != null ||
                                  passwordError != null ||
                                  teamError != null) return;
                              setLocal(() => saving = true);
                              try {
                                final result = creating
                                    ? await ManagementService.createWorker(
                                        widget.project.id, {
                                        'username': usernameValue,
                                        'password': password.text,
                                        'realName': name.text.trim(),
                                        'jobType': jobType,
                                        'phone': phone.text.trim(),
                                        'teamId': teamId,
                                        'shiftId': personalShiftId == 0
                                            ? null
                                            : personalShiftId,
                                        'extraShiftOverride':
                                            extraShiftOverride,
                                        'extraShiftIds': extraShiftIds.toList(),
                                      })
                                    : await ManagementService.updateWorker(
                                        worker.workerId, {
                                        'username': usernameValue,
                                        'realName': name.text.trim(),
                                        'jobType': jobType,
                                        'phone': phone.text.trim(),
                                        'status': enabled ? 1 : 0,
                                        'teamId': teamId == 0 ? null : teamId,
                                        'shiftId': personalShiftId == 0
                                            ? null
                                            : personalShiftId,
                                        'extraShiftOverride':
                                            extraShiftOverride,
                                        'extraShiftIds': extraShiftIds.toList(),
                                      });
                                if (!ctx.mounted) return;
                                if (result.isSuccess) {
                                  Navigator.pop(ctx, true);
                                } else {
                                  setLocal(() => saveError = result.message);
                                }
                              } catch (error) {
                                if (ctx.mounted) {
                                  setLocal(() => saveError =
                                      '保存失败：${error.toString().replaceFirst('Exception: ', '')}');
                                }
                              } finally {
                                if (ctx.mounted) setLocal(() => saving = false);
                              }
                            },
                      child: Text(saving ? '保存中…' : '保存')),
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

  String _teamShiftName(int teamId) {
    for (final team in teams) {
      if (team.id != teamId) continue;
      for (final shift in shifts) {
        if (shift.id == team.shiftId) return shift.name;
      }
    }
    return '未设置';
  }

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
                      child: Text(
                          '转移即时生效，需在目标项目重新分配班组和班次；工种、历史考勤和转移记录保留。当天已在原项目打卡的，目标项目从下一考勤日打卡。',
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
