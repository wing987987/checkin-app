// ignore_for_file: deprecated_member_use, unused_element, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/checkin_project.dart';
import '../../models/checkin_shift.dart';
import '../../models/checkin_team.dart';
import '../../models/worker_assignment.dart';
import '../../models/checkin_job_type.dart';
import '../../models/my_schedule.dart';
import '../../services/management_service.dart';
import '../../core/widgets/dialog_scroll_view.dart';
import 'anomaly_list_page.dart';
import 'no_work_requests_page.dart';
import 'supervisor_attendance_page.dart';
import 'project_report_page.dart';
import 'project_location_picker_page.dart';
import 'clock_photo_archive_page.dart';
import 'worker_management_page.dart';
import 'construction_log_page.dart';
import 'construction_log_history_page.dart';
import '../../services/construction_log_service.dart';
import '../../services/log_reminder_service.dart';
import '../../models/attendance_anomaly.dart';
import '../../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_background.dart';

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
  List<CheckinJobType> jobTypes = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    project = widget.project;
    _load();
    _loadWorkbench();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final values = await Future.wait([
        ManagementService.teams(project.id),
        ManagementService.shifts(project.id),
        ManagementService.workers(project.id),
        ManagementService.jobTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        teams = values[0].data as List<CheckinTeam>? ?? const [];
        shifts = values[1].data as List<CheckinShift>? ?? const [];
        workers = values[2].data as List<WorkerAssignment>? ?? const [];
        jobTypes = values[3].data as List<CheckinJobType>? ?? const [];
      });
    } catch (_) {
      if (mounted) _message('加载失败，请检查网络');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int _tab = 0;
  Map<String, dynamic>? _todayLog;
  int? _anomalyCount, _requestCount;
  List<AttendanceAnomaly>? _loadedAnomalies;
  DateTime? _anomaliesLoadedAt;
  String? _workbenchError;

  Future<void> _loadWorkbench() async {
    try {
      final values = await Future.wait([
        ManagementService.anomalies(project.id),
        ManagementService.noWorkRequests(project.id),
        if (context.read<AuthProvider>().isSupervisor)
          ConstructionLogService.mine(project.id),
      ]);
      if (!mounted) return;
      if (values.any((v) => !v.isSuccess)) throw Exception('加载失败');
      setState(() {
        _todayLog =
            values.length > 2 ? values[2].data as Map<String, dynamic>? : null;
        _anomalyCount = (values[0].data as List)
            .where((v) => !(v as AttendanceAnomaly).resolved)
            .length;
        _loadedAnomalies = List<AttendanceAnomaly>.from(values[0].data as List);
        _anomaliesLoadedAt = DateTime.now();
        _requestCount = (values[1].data as List)
            .where((v) => v['status'] == 'pending')
            .length;
        _workbenchError = null;
      });
    } catch (_) {
      if (mounted) setState(() => _workbenchError = '待办加载失败，点击刷新');
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) {
      await _load();
      await _loadWorkbench();
    }
  }

  Widget _tile(IconData icon, String title, VoidCallback? action,
      {int? count}) {
    final color = switch (icon) {
      Icons.warning_amber => const Color(0xFFB6630C),
      Icons.event_busy_outlined => AppColors.purple,
      Icons.add_task => const Color(0xFF168348),
      Icons.manage_accounts_outlined => const Color(0xFF087F8C),
      Icons.photo_library_outlined => const Color(0xFFB06320),
      Icons.assessment_outlined => const Color(0xFF5465B8),
      _ => AppColors.primary,
    };
    final disabled = action == null;
    return Card(
      margin: EdgeInsets.zero,
      color: disabled
          ? AppColors.surfaceSubtle
          : Color.alphaBlend(color.withValues(alpha: .045), Colors.white),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: .15))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
          onTap: action,
          child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Badge(
                        isLabelVisible: count != null && count > 0,
                        label: Text('${count ?? 0}'),
                        child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                                color: color.withValues(
                                    alpha: disabled ? .04 : .09),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(icon,
                                size: 26,
                                color: disabled
                                    ? AppColors.textTertiary
                                    : color))),
                    const SizedBox(height: 10),
                    Text(title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: disabled
                                ? AppColors.textTertiary
                                : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ]))),
    );
  }

  Widget _grid(List<Widget> entries) => LayoutBuilder(
      builder: (context, bounds) => GridView.count(
            crossAxisCount: bounds.maxWidth > 680 ? 4 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio:
                (bounds.maxWidth / (bounds.maxWidth > 680 ? 4 : 2)) /
                    (96 + MediaQuery.textScalerOf(context).scale(16) * 2),
            children: entries,
          ));

  @override
  Widget build(BuildContext context) {
    final canWrite = context.watch<AuthProvider>().isSupervisor;
    return Scaffold(
      appBar: AppBar(title: Text(project.name), actions: [
        IconButton(
            tooltip: '刷新',
            onPressed: () async {
              await _load();
              await _loadWorkbench();
            },
            icon: const Icon(Icons.refresh)),
      ]),
      bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.soft,
            surfaceTintColor: Colors.transparent,
            iconTheme: WidgetStateProperty.resolveWith((states) =>
                IconThemeData(
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.textSecondary)),
            labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                TextStyle(
                    fontSize: 12,
                    color: states.contains(WidgetState.selected)
                        ? AppColors.primary
                        : AppColors.textSecondary,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ),
          child: NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (v) => setState(() => _tab = v),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: '工作台'),
                NavigationDestination(
                    icon: Icon(Icons.folder_outlined),
                    selectedIcon: Icon(Icons.folder),
                    label: '记录'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: '管理'),
              ])),
      body: AppBackground(
          headerHeight: 280,
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    await _load();
                    await _loadWorkbench();
                  },
                  child: ListView(
                      padding: const EdgeInsets.all(16),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (_tab == 0) ...[
                          if (_workbenchError != null)
                            TextButton(
                                onPressed: _loadWorkbench,
                                child: Text(_workbenchError!)),
                          if (canWrite)
                            Card(
                                child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            const Icon(Icons.edit_note,
                                                size: 30),
                                            const SizedBox(width: 8),
                                            Expanded(
                                                child: Text('我的今日日志',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium)),
                                            Text(_todayLog == null
                                                ? '加载中'
                                                : {
                                                      'empty': '未填写',
                                                      'draft': '草稿',
                                                      'submitted': '已提交'
                                                    }[_todayLog!['status']] ??
                                                    '未填写'),
                                          ]),
                                          const SizedBox(height: 8),
                                          Text(_todayLog?['today'] as String? ??
                                              '每天记录施工进度和明日计划'),
                                          if (_todayLog?['status'] ==
                                              'submitted')
                                            Text(
                                                '提交时间：${_todayLog!['submittedTime']}'),
                                          const SizedBox(height: 12),
                                          SizedBox(
                                              width: double.infinity,
                                              child: FilledButton(
                                                onPressed: _todayLog == null ||
                                                        project.status !=
                                                            'active'
                                                    ? null
                                                    : () => _open(
                                                        ConstructionLogPage(
                                                            project: project)),
                                                child: Text(_todayLog?[
                                                            'status'] ==
                                                        'submitted'
                                                    ? '查看日志'
                                                    : _todayLog?['status'] ==
                                                            'draft'
                                                        ? '继续填写'
                                                        : '填写日志'),
                                              )),
                                        ]))),
                          const SizedBox(height: 12),
                          Text('待办事项',
                              style: Theme.of(context).textTheme.titleMedium),
                          _grid([
                            _tile(
                                Icons.warning_amber,
                                '异常考勤',
                                () => _open(AnomalyListPage(
                                    project: project,
                                    initialItems: _anomaliesLoadedAt != null &&
                                            DateTime.now().difference(
                                                    _anomaliesLoadedAt!) <
                                                const Duration(seconds: 30)
                                        ? _loadedAnomalies
                                        : null)),
                                count: _anomalyCount),
                            _tile(
                                Icons.event_busy_outlined,
                                '未出工审批',
                                () => _open(
                                    NoWorkRequestsPage(projectId: project.id)),
                                count: _requestCount),
                          ]),
                          const SizedBox(height: 12),
                          Text('常用功能',
                              style: Theme.of(context).textTheme.titleMedium),
                          _grid([
                            if (!canWrite)
                              _tile(
                                  Icons.description_outlined,
                                  '项目施工日志',
                                  () => _open(ConstructionLogHistoryPage(
                                      project: project))),
                            _tile(
                                Icons.assessment_outlined,
                                '考勤报表',
                                () =>
                                    _open(ProjectReportPage(project: project))),
                            _tile(Icons.add_task, '主管补卡',
                                workers.isEmpty ? null : _supplementClock),
                            _tile(
                                Icons.manage_accounts_outlined,
                                '用户管理',
                                () => _open(
                                    WorkerManagementPage(project: project))),
                            _tile(
                                Icons.photo_library_outlined,
                                '打卡照片',
                                () => _open(
                                    ClockPhotoArchivePage(project: project))),
                          ]),
                        ],
                        if (_tab == 1) ...[
                          Text('项目记录',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          _grid([
                            _tile(
                                Icons.description_outlined,
                                '历史施工日志',
                                () => _open(ConstructionLogHistoryPage(
                                    project: project))),
                            _tile(
                                Icons.assessment_outlined,
                                '考勤报表',
                                () =>
                                    _open(ProjectReportPage(project: project))),
                            _tile(
                                Icons.photo_library_outlined,
                                '打卡照片归档',
                                () => _open(
                                    ClockPhotoArchivePage(project: project))),
                          ]),
                        ],
                        if (_tab == 2) ...[
                          Text('项目管理',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 12),
                          _grid([
                            _tile(
                                Icons.manage_accounts_outlined,
                                '用户管理',
                                () => _open(
                                    WorkerManagementPage(project: project))),
                            _tile(Icons.groups_outlined, '班组管理',
                                () => _manageSettings(true)),
                            _tile(Icons.schedule, '班次设置',
                                () => _manageSettings(false)),
                            _tile(
                                Icons.badge_outlined,
                                '主管考勤分配',
                                () => _open(SupervisorAttendancePage(
                                    projectId: project.id))),
                            _tile(
                                Icons.gps_fixed, '项目定位', _editProjectLocation),
                            _tile(Icons.edit_outlined, '项目设置', _editProject),
                            if (canWrite)
                              _tile(Icons.notifications_outlined, '日志填写提醒',
                                  _reminderSettings),
                          ]),
                        ],
                      ]),
                )),
    );
  }

  Future<void> _reminderSettings() async {
    final user = context.read<AuthProvider>().currentUser!;
    final reminders = LogReminderService.instance;
    if (!reminders.supported) {
      _message('本地提醒支持安卓手机，请在手机端设置');
      return;
    }
    var enabled = await reminders.enabled(user.id);
    const time = LogReminderService.reminderTime;
    if (!mounted) return;
    await showDialog<void>(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, update) => AlertDialog(
                  title: const Text('日志填写提醒'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    SwitchListTile(
                        title: const Text('开启系统通知'),
                        value: enabled,
                        onChanged: (v) => update(() => enabled = v)),
                    ListTile(
                        title: const Text('提醒时间（北京时间）'),
                        trailing: Text(time.format(c))),
                    const Text(
                        '每天17:00提醒所有主管；App内提醒同时保留。多个项目合并提醒，已全部提交则不再催填。系统省电设置可能延迟系统通知。'),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () async {
                          try {
                            final ok = await reminders.configure(
                                user.id, enabled, time);
                            if (c.mounted) Navigator.pop(c);
                            _message(ok ? '提醒设置已保存' : '请在手机设置中允许通知');
                          } catch (_) {
                            _message('提醒设置失败，请重试');
                          }
                        },
                        child: const Text('保存'))
                  ],
                )));
  }

  Future<void> _manageSettings(bool teamsOnly) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StatefulBuilder(
                builder: (c, refresh) => Scaffold(
                      appBar: AppBar(title: Text(teamsOnly ? '班组管理' : '班次设置')),
                      body: ListView(
                          padding: const EdgeInsets.all(16),
                          children: _configurationItems(
                              teamsOnly, () => refresh(() {}))),
                    ))));
    if (mounted) await _load();
  }

  List<Widget> _configurationItems(bool teamsOnly, VoidCallback refresh) {
    return [
      if (teamsOnly) ...[
        _header(
            '班组',
            teams.length,
            shifts.isEmpty
                ? null
                : () async {
                    await _addTeam();
                    refresh();
                  }),
        if (teams.isEmpty) const ListTile(title: Text('暂未设置班组')),
        ...teams.map((t) => ListTile(
            leading:
                Icon(Icons.groups, color: t.status == 1 ? null : Colors.grey),
            title: Text(t.name),
            subtitle: Text(
                '默认班次：${_shiftName(t.shiftId)}${t.status == 1 ? '' : ' · 已停用'}'),
            onTap: () async {
              await _manageTeamMembers(t);
              refresh();
            },
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') await _editTeam(t);
                if (value == 'members') await _manageTeamMembers(t);
                if (value == 'delete') await _deleteTeam(t);
                if (value == 'toggle') await _toggleTeam(t);
                refresh();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                const PopupMenuItem(value: 'members', child: Text('管理成员')),
                PopupMenuItem(
                    value: 'toggle', child: Text(t.status == 1 ? '停用' : '启用')),
                const PopupMenuItem(value: 'delete', child: Text('删除班组')),
              ],
            ))),
      ],
      if (!teamsOnly) ...[
        _header('班次', shifts.length, () async {
          await _addShift();
          refresh();
        }),
        if (shifts.isEmpty) const ListTile(title: Text('暂未设置班次')),
        ...shifts.map((s) => ListTile(
            leading:
                Icon(Icons.schedule, color: s.status == 1 ? null : Colors.grey),
            title: Text(s.name),
            subtitle: Text(
                '${_typeName(s.shiftType)}  ${s.startTime}–${s.shiftType == 'night' ? '次日 ' : ''}${s.endTime}${s.status == 1 ? '' : ' · 已停用'}'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'edit') {
                  await _editShift(s);
                } else {
                  await _toggleShift(s);
                }
                refresh();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('编辑')),
                PopupMenuItem(
                    value: 'toggle', child: Text(s.status == 1 ? '停用' : '启用')),
              ],
            ))),
      ],
    ];
  }

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
                decoration: const InputDecoration(hintText: '工人'),
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
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey(worker.shiftId),
                initialValue: checkpoint.id,
                decoration: const InputDecoration(hintText: '班次检查点'),
                items: checkpoints
                    .map((p) => DropdownMenuItem(
                        value: p.id,
                        child: Text('${p.name} ${p.expectedTime}')))
                    .toList(),
                onChanged: (id) => setLocal(() =>
                    checkpoint = checkpoints.firstWhere((p) => p.id == id)),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              TextField(
                  controller: reason,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: '补卡原因（必填）')),
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
    final extraShiftIds = <int>{};
    String? formError;
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (_, setLocal) => AlertDialog(
                    title: const Text('新增班组'),
                    content: DialogScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          _fieldLabel('班组名称'),
                          TextField(
                              controller: controller,
                              autofocus: true,
                              decoration:
                                  const InputDecoration(hintText: '请输入班组名称')),
                          const SizedBox(height: 16),
                          _fieldLabel('默认班次'),
                          DropdownButtonFormField<int>(
                            value: shiftId,
                            decoration: const InputDecoration(),
                            items: shifts
                                .map((shift) => DropdownMenuItem(
                                    value: shift.id, child: Text(shift.name)))
                                .toList(),
                            onChanged: (value) => setLocal(() {
                              shiftId = value ?? shiftId;
                              extraShiftIds.remove(shiftId);
                            }),
                          ),
                          const SizedBox(height: 16),
                          _fieldLabel('可选附加班次'),
                          ...shifts.where((shift) => shift.id != shiftId).map(
                                (shift) => CheckboxListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(shift.name),
                                  subtitle: const Text('不打卡不算缺勤，打卡后独立计算'),
                                  value: extraShiftIds.contains(shift.id),
                                  onChanged: (value) => setLocal(() =>
                                      value == true
                                          ? extraShiftIds.add(shift.id)
                                          : extraShiftIds.remove(shift.id)),
                                ),
                              ),
                          if (formError != null) ...[
                            const SizedBox(height: 12),
                            Text(formError!,
                                style: TextStyle(
                                    color: Theme.of(ctx).colorScheme.error)),
                          ],
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () async {
                            if (controller.text.trim().isEmpty) return;
                            final r =
                                await ManagementService.createTeam(project.id, {
                              'name': controller.text.trim(),
                              'shiftId': shiftId,
                              'extraShiftIds': extraShiftIds.toList(),
                              'status': 1
                            });
                            if (ctx.mounted) {
                              if (r.isSuccess) {
                                Navigator.pop(ctx, true);
                              } else {
                                setLocal(() => formError = r.message);
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
    var allowOutside = false;
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
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('允许规定时段外打卡'),
                              subtitle: const Text('开启后，时段外打卡将记为异常，需主管处理'),
                              value: allowOutside,
                              onChanged: (v) =>
                                  setLocal(() => allowOutside = v)),
                          _fieldLabel('班次名称'),
                          TextField(
                              controller: name,
                              decoration:
                                  const InputDecoration(hintText: '请输入班次名称')),
                          const SizedBox(height: 16),
                          _fieldLabel('班次类型'),
                          DropdownButtonFormField<String>(
                              initialValue: type,
                              decoration: const InputDecoration(),
                              items: const [
                                DropdownMenuItem(
                                    value: 'day', child: Text('白班')),
                                DropdownMenuItem(
                                    value: 'night', child: Text('夜班')),
                              ],
                              onChanged: (v) => setLocal(() {
                                    type = v ?? 'day';
                                    if (type == 'night') {
                                      start =
                                          const TimeOfDay(hour: 21, minute: 0);
                                      end =
                                          const TimeOfDay(hour: 5, minute: 30);
                                    } else {
                                      start =
                                          const TimeOfDay(hour: 6, minute: 30);
                                      end =
                                          const TimeOfDay(hour: 17, minute: 30);
                                    }
                                  })),
                          const SizedBox(height: 16),
                          _timeTile(ctx, '上班时间', start,
                              (v) => setLocal(() => start = v)),
                          if (type == 'day')
                            _timeTile(ctx, '中午下班', breakStart,
                                (v) => setLocal(() => breakStart = v)),
                          if (type == 'day')
                            _timeTile(ctx, '下午上班', breakEnd,
                                (v) => setLocal(() => breakEnd = v)),
                          _timeTile(ctx, type == 'night' ? '下班时间（次日）' : '下班时间',
                              end, (v) => setLocal(() => end = v)),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F3F5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.timer_outlined, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        '打卡与加班规则\n上班：提前30分钟至延后5分钟\n中午下班：提前5分钟至延后30分钟\n最后下班：提前5分钟起，白班当天24点前、夜班次日12点前\n超出标准下班每满30分钟计0.5小时加班')),
                              ],
                            ),
                          ),
                        ])),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () async {
                            if (name.text.trim().isEmpty) return;
                            final timeError = _shiftTimeError(
                                type, start, end, breakStart, breakEnd);
                            if (timeError != null) {
                              _message(timeError);
                              return;
                            }
                            final r = await ManagementService.createShift(
                                project.id, {
                              'name': name.text.trim(),
                              'shiftType': type,
                              'startTime': _time(start),
                              'endTime': _time(end),
                              'crossDay': type == 'night' ? 1 : 0,
                              if (type == 'day')
                                'breakStartTime': _time(breakStart),
                              if (type == 'day')
                                'breakEndTime': _time(breakEnd),
                              'allowOutsideClockWindow': allowOutside ? 1 : 0,
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
    String? jobType;
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
                          decoration: const InputDecoration(hintText: '姓名')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          value: jobType,
                          decoration: const InputDecoration(hintText: '工种（必选）'),
                          items: jobTypes
                              .map((type) => DropdownMenuItem(
                                  value: type.name, child: Text(type.name)))
                              .toList(),
                          onChanged: (value) =>
                              setLocal(() => jobType = value)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: username,
                          decoration: const InputDecoration(hintText: '登录用户名')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(hintText: '初始密码')),
                      const SizedBox(height: 12),
                      TextField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(hintText: '手机号（选填）')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                          initialValue: teamId,
                          decoration: const InputDecoration(hintText: '班组'),
                          items: teams
                              .map((t) => DropdownMenuItem(
                                  value: t.id, child: Text(t.name)))
                              .toList(),
                          onChanged: (v) =>
                              setLocal(() => teamId = v ?? teamId)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                          initialValue: shiftId,
                          decoration: const InputDecoration(hintText: '班次'),
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
                                realName.text.trim().isEmpty ||
                                jobType == null) {
                              return;
                            }
                            final r = await ManagementService.createWorker(
                                project.id, {
                              'username': username.text.trim(),
                              'password': password.text,
                              'realName': realName.text.trim(),
                              'jobType': jobType,
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
                          decoration: const InputDecoration(hintText: '班组'),
                          items: teams
                              .map((t) => DropdownMenuItem(
                                  value: t.id, child: Text(t.name)))
                              .toList(),
                          onChanged: (v) =>
                              setLocal(() => teamId = v ?? teamId)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                          initialValue: shiftId,
                          decoration: const InputDecoration(hintText: '班次'),
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
          content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('项目名称'),
                TextField(
                    controller: name,
                    decoration: const InputDecoration(hintText: '请输入项目名称')),
                const SizedBox(height: 16),
                _fieldLabel('打卡范围'),
                DropdownButtonFormField<int>(
                  initialValue: radius,
                  decoration: const InputDecoration(),
                  items: const [100, 200, 300, 500]
                      .map((v) =>
                          DropdownMenuItem(value: v, child: Text('$v 米')))
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
    var allowOutside = shift.allowOutsideClockWindow;
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
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('允许规定时段外打卡'),
                      subtitle: const Text('开启后，时段外打卡将记为异常，需主管处理'),
                      value: allowOutside,
                      onChanged: (v) => setLocal(() => allowOutside = v)),
                  _fieldLabel('班次名称'),
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(hintText: '请输入班次名称')),
                  const SizedBox(height: 16),
                  _fieldLabel('班次类型'),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(),
                    items: const [
                      DropdownMenuItem(value: 'day', child: Text('白班')),
                      DropdownMenuItem(value: 'night', child: Text('夜班')),
                    ],
                    onChanged: (v) => setLocal(() {
                      final nextType = v ?? type;
                      if (nextType != type) {
                        type = nextType;
                        if (type == 'night') {
                          start = const TimeOfDay(hour: 21, minute: 0);
                          end = const TimeOfDay(hour: 5, minute: 30);
                        } else {
                          start = const TimeOfDay(hour: 6, minute: 30);
                          end = const TimeOfDay(hour: 17, minute: 30);
                        }
                      }
                    }),
                  ),
                  const SizedBox(height: 16),
                  _timeTile(
                      ctx, '上班时间', start, (v) => setLocal(() => start = v)),
                  if (type == 'day') ...[
                    _timeTile(ctx, '中午下班', breakStart,
                        (v) => setLocal(() => breakStart = v)),
                    _timeTile(ctx, '下午上班', breakEnd,
                        (v) => setLocal(() => breakEnd = v)),
                  ],
                  _timeTile(ctx, type == 'night' ? '下班时间（次日）' : '下班时间', end,
                      (v) => setLocal(() => end = v)),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F3F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.timer_outlined, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                '打卡与加班规则\n上班：提前30分钟至延后5分钟\n中午下班：提前5分钟至延后30分钟\n最后下班：提前5分钟起，白班当天24点前、夜班次日12点前\n超出标准下班每满30分钟计0.5小时加班')),
                      ],
                    ),
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
                final timeError =
                    _shiftTimeError(type, start, end, breakStart, breakEnd);
                if (timeError != null) {
                  _message(timeError);
                  return;
                }
                final result = await ManagementService.updateShift(shift.id, {
                  'name': name.text.trim(),
                  'shiftType': type,
                  'startTime': _time(start),
                  'endTime': _time(end),
                  'crossDay': type == 'night' ? 1 : 0,
                  if (type == 'day') 'breakStartTime': _time(breakStart),
                  if (type == 'day') 'breakEndTime': _time(breakEnd),
                  'allowOutsideClockWindow': allowOutside ? 1 : 0,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () async {
          final selected =
              await showTimePicker(context: context, initialTime: value);
          if (selected != null) onChanged(selected);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE7E7EA)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Expanded(child: Text(label)),
            Text(_time(value).substring(0, 5),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.schedule_outlined,
                size: 20, color: Color(0xFF92939A)),
          ]),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      );

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
      'allowOutsideClockWindow': shift.allowOutsideClockWindow ? 1 : 0,
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
    final extraShiftIds = team.extraShiftIds.toSet();
    String? formError;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (_, setLocal) => AlertDialog(
                title: const Text('编辑班组'),
                content: DialogScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      _fieldLabel('班组名称'),
                      TextField(
                          controller: name,
                          autofocus: true,
                          decoration:
                              const InputDecoration(hintText: '请输入班组名称')),
                      const SizedBox(height: 16),
                      _fieldLabel('默认班次'),
                      DropdownButtonFormField<int>(
                        value: shiftId,
                        decoration: const InputDecoration(),
                        items: shifts
                            .map((shift) => DropdownMenuItem(
                                value: shift.id, child: Text(shift.name)))
                            .toList(),
                        onChanged: (value) => setLocal(() {
                          shiftId = value ?? shiftId;
                          extraShiftIds.remove(shiftId);
                        }),
                      ),
                      const SizedBox(height: 16),
                      _fieldLabel('可选附加班次'),
                      ...shifts.where((shift) => shift.id != shiftId).map(
                            (shift) => CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(shift.name),
                              subtitle: const Text('未打卡不产生缺勤'),
                              value: extraShiftIds.contains(shift.id),
                              onChanged: (value) => setLocal(() => value == true
                                  ? extraShiftIds.add(shift.id)
                                  : extraShiftIds.remove(shift.id)),
                            ),
                          ),
                      if (formError != null) ...[
                        const SizedBox(height: 12),
                        Text(formError!,
                            style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error)),
                      ],
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty) return;
                      final result =
                          await ManagementService.updateTeam(team.id, {
                        'name': name.text.trim(),
                        'shiftId': shiftId,
                        'extraShiftIds': extraShiftIds.toList(),
                        'status': team.status
                      });
                      if (!ctx.mounted) return;
                      if (result.isSuccess) {
                        Navigator.pop(ctx, true);
                      } else {
                        setLocal(() => formError = result.message);
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
                                ? '${worker.jobType?.isNotEmpty == true ? worker.jobType : '未设置工种'} · ${worker.shiftName}（个人班次）'
                                : '${worker.jobType?.isNotEmpty == true ? worker.jobType : '未设置工种'} · 使用班组默认班次'),
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
    String? jobType = jobTypes.any((type) => type.name == worker.jobType)
        ? worker.jobType
        : null;
    final phone = TextEditingController(text: worker.phone ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (_, setLocal) => AlertDialog(
                title: Text('编辑 ${worker.username}'),
                content: DialogScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(hintText: '姓名')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                      value: jobType,
                      decoration: const InputDecoration(hintText: '工种（必选）'),
                      items: jobTypes
                          .map((type) => DropdownMenuItem(
                              value: type.name, child: Text(type.name)))
                          .toList(),
                      onChanged: (value) => setLocal(() => jobType = value)),
                  const SizedBox(height: 12),
                  TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: '手机号（选填）')),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('取消')),
                  FilledButton(
                    onPressed: () async {
                      if (name.text.trim().isEmpty || jobType == null) return;
                      final result = await ManagementService.updateWorker(
                          worker.workerId, {
                        'realName': name.text.trim(),
                        'jobType': jobType,
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
              )),
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
      'jobType': worker.jobType,
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

  String? _shiftTimeError(String type, TimeOfDay start, TimeOfDay end,
      TimeOfDay breakStart, TimeOfDay breakEnd) {
    final startMinutes = _minutes(start);
    final endMinutes = _minutes(end);
    if (type == 'night') {
      return endMinutes < startMinutes ? null : '夜班下班时间必须早于上班时间，下班时间按次日计算';
    }
    if (startMinutes >= endMinutes) {
      return '白班上班时间必须早于下班时间';
    }
    final breakStartMinutes = _minutes(breakStart);
    final breakEndMinutes = _minutes(breakEnd);
    if (!(startMinutes < breakStartMinutes &&
        breakStartMinutes < breakEndMinutes &&
        breakEndMinutes < endMinutes)) {
      return '白班时间顺序应为：上班、中午下班、下午上班、下班';
    }
    return null;
  }

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
