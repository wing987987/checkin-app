import 'dart:async';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_background.dart';
import '../../core/widgets/test_account_switcher.dart';
import '../../core/widgets/user_account_menu.dart';
import '../../models/checkin_project.dart';
import '../../services/management_service.dart';
import 'project_location_picker_page.dart';
import 'project_management_page.dart';
import 'supervisor_management_page.dart';
import 'project_requests_page.dart';
import '../../core/models/api_result.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../worker/worker_home_page.dart';
import '../worker/worker_report_page.dart';
import '../../services/log_reminder_service.dart';
import '../../services/construction_log_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'construction_log_page.dart';

class SupervisorHomePage extends StatefulWidget {
  const SupervisorHomePage({super.key});
  @override
  State<SupervisorHomePage> createState() => _SupervisorHomePageState();
}

class _SupervisorHomePageState extends State<SupervisorHomePage>
    with WidgetsBindingObserver {
  List<CheckinProject> _projects = const [];
  bool _loading = true;
  String? _error;
  bool _fetching = false;
  List<Map<String, dynamic>> _catalog = [];
  int _pendingRequests = 0;
  bool _countError = false;
  Timer? _requestTimer;
  final Set<int> _applying = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    LogReminderService.instance.taps.addListener(_notificationTapped);
    _load();
    _requestTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => _refreshRequestCount());
  }

  @override
  void dispose() {
    _requestTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    LogReminderService.instance.taps.removeListener(_notificationTapped);
    super.dispose();
  }

  void _notificationTapped() {
    if (mounted) _openReminderTarget();
  }

  Future<void> _openReminderTarget() async {
    if (!mounted || !context.read<AuthProvider>().isSupervisor) return;
    final auth = context.read<AuthProvider>();
    final actor = auth.currentUser!.id;
    await LogReminderService.instance.dismissInApp(actor);
    if (!mounted || !auth.isSupervisor || auth.currentUser?.id != actor) return;
    final active = _projects.where((p) => p.status == 'active').toList();
    final pendingIds = await LogReminderService.instance.pendingProjects(actor);
    if (!mounted || !auth.isSupervisor || auth.currentUser?.id != actor) return;
    final pending = active.where((p) => pendingIds.contains(p.id)).toList();
    if (pending.length == 1) {
      await _openReminderLog(pending.single);
      return;
    }
    if (active.isEmpty) {
      await _load();
      return;
    }
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('今日负责项目的施工日志均已提交')));
      return;
    }
    final selected = await showModalBottomSheet<CheckinProject>(
        context: context,
        builder: (c) => SafeArea(
                child: ListView(shrinkWrap: true, children: [
              const ListTile(title: Text('选择项目填写施工日志')),
              ...pending.map((p) => ListTile(
                  title: Text(p.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(c, p))),
            ])));
    if (selected != null && mounted) await _openReminderLog(selected);
  }

  Future<void> _openReminderLog(CheckinProject project) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ConstructionLogPage(project: project)));
    if (mounted) await _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _syncReminders() async {
    final auth = context.read<AuthProvider>();
    final reminders = LogReminderService.instance;
    if (!auth.isSupervisor) return;
    final actor = auth.currentUser!.id;
    final active = _projects.where((p) => p.status == 'active').toList();
    final prefs = await SharedPreferences.getInstance();
    for (final project in active) {
      final r = await ConstructionLogService.mine(project.id);
      if (r.isSuccess && r.data?['status'] == 'submitted') {
        await prefs.setBool(
            'log_submitted_${actor}_${project.id}_${r.data!['today']}', true);
      }
    }
    if (!mounted || auth.currentUser?.id != actor) return;
    await reminders.sync(actor, active.map((p) => p.id).toList());
    if (reminders.supported &&
        prefs.getBool('log_reminder_asked_$actor') != true &&
        active.isNotEmpty) {
      await prefs.setBool('log_reminder_asked_$actor', true);
      await reminders.configure(
          actor, await reminders.enabled(actor), await reminders.time(actor));
    }
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final isBoss = context.read<AuthProvider>().isBoss;
      final values = await Future.wait<dynamic>([
        ManagementService.projects(),
        if (isBoss)
          ManagementService.projectRequestCount().catchError(
              (Object _) => ApiResult<int>(code: -1, message: '待办数量加载失败'))
        else
          ManagementService.projectCatalog(),
      ]);
      final result = values[0] as ApiResult<List<CheckinProject>>;
      if (!mounted) return;
      setState(() {
        _projects = result.data ?? const [];
        _error = result.isSuccess ? null : result.message;
        if (isBoss) {
          _catalog = [];
          final count = values[1] as ApiResult<int>;
          _countError = !count.isSuccess;
          if (count.isSuccess) _pendingRequests = count.data ?? 0;
        } else {
          final catalog = values[1] as ApiResult<List<Map<String, dynamic>>>;
          if (catalog.isSuccess) {
            _catalog = catalog.data ?? [];
          } else {
            _error = catalog.message;
          }
        }
      });
      if (result.isSuccess) {
        try {
          await _syncReminders();
        } catch (_) {
          /* Project loading remains usable without notifications. */
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = '项目加载失败，请检查网络');
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
      if (mounted && LogReminderService.instance.consumeLaunch()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openReminderTarget();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBoss = context.watch<AuthProvider>().isBoss;
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 150,
        leading: const UserAccountMenu(),
        title: const Text('项目管理'),
        bottom: !isBoss
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const WorkerHomePage(showBack: true))),
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('我的打卡')),
                      TextButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const WorkerReportPage())),
                          icon: const Icon(Icons.assessment_outlined),
                          label: const Text('我的统计')),
                    ]))
            : null,
        actions: [
          if (isBoss)
            IconButton(
              tooltip: '主管管理',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const SupervisorManagementPage()),
              ),
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
          const TestAccountSwitcher(),
          IconButton(
              tooltip: '刷新项目',
              onPressed: _load,
              icon: const Icon(Icons.refresh)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '新建项目',
        onPressed: _createProject,
        child: const Icon(Icons.add),
      ),
      body: AppBackground(
          child: Column(children: [
        if (isBoss)
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Card(
                  child: ListTile(
                leading: Badge(
                    isLabelVisible: _pendingRequests > 0,
                    label: Text('$_pendingRequests'),
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.assignment_ind_outlined)),
                title: const Text('项目申请'),
                subtitle: Text(_countError
                    ? '待办数量加载失败，点击查看'
                    : _pendingRequests > 0
                        ? '$_pendingRequests 条申请待处理'
                        : '暂无待处理申请'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProjectRequestsPage()));
                  if (mounted) await _load();
                },
              ))),
        Expanded(child: _body()),
      ])),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AppEmptyState(
          icon: Icons.cloud_off_outlined,
          title: '项目加载失败',
          description: _error!,
          onRetry: _load);
    }
    final others = _catalog
        .where((p) => !_projects.any((mine) => mine.id == p['id']))
        .toList();
    if (_projects.isEmpty && others.isEmpty) {
      return AppEmptyState(
          icon: Icons.folder_open_outlined,
          title: '还没有负责的项目',
          description: '新建项目后，可在这里管理定位、班组和考勤。');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _projects.length + others.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 8),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Row(children: [
              Text('全部项目', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('共 ${_projects.length + others.length} 个',
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 12)),
            ]);
          }
          if (index <= _projects.length) {
            return _projectItem(_projects[index - 1]);
          }
          return _availableProject(others[index - _projects.length - 1]);
        },
      ),
    );
  }

  Future<void> _refreshRequestCount() async {
    if (!mounted ||
        !context.read<AuthProvider>().isBoss ||
        _fetching ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.paused) {
      return;
    }
    try {
      final result = await ManagementService.projectRequestCount();
      if (mounted && context.read<AuthProvider>().isBoss) {
        setState(() {
          _countError = !result.isSuccess;
          if (result.isSuccess) _pendingRequests = result.data ?? 0;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _countError = true);
    }
  }

  Widget _availableProject(Map<String, dynamic> project) {
    final id = (project['id'] as num).toInt();
    final pending = project['requestStatus'] == 'pending';
    final active = project['status'] == 'active';
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const Icon(Icons.folder_outlined),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${project['name']}',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                        !active
                            ? '项目已停用'
                            : pending
                                ? '申请审批中'
                                : project['requestStatus'] == 'rejected'
                                    ? '申请已拒绝'
                                    : '未负责该项目',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ])),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: '更多',
                icon: const Icon(Icons.more_vert),
                onSelected: (_) => _applyProject(id),
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'apply',
                    enabled: active && !pending && !_applying.contains(id),
                    child: Text(pending
                        ? '审批中'
                        : _applying.contains(id)
                            ? '提交中…'
                            : project['requestStatus'] == 'rejected'
                                ? '重新申请'
                                : '申请加入'),
                  ),
                ],
              ),
            ])));
  }

  Future<void> _applyProject(int id) async {
    setState(() => _applying.add(id));
    try {
      final result = await ManagementService.applyProject(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.isSuccess ? '申请已提交，等待老总审批' : result.message)));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('提交失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _applying.remove(id));
    }
  }

  Widget _projectItem(CheckinProject project) {
    final active = project.status == 'active';
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openProject(project),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.soft,
                  borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.folder_outlined,
                  color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Expanded(
                        child: Text(project.name,
                            style: Theme.of(context).textTheme.titleSmall)),
                    _statusTag(active),
                  ]),
                  const SizedBox(height: 6),
                  Text('打卡范围 ${project.fenceRadius} 米',
                      style: const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  Text(
                      '${project.gpsLat.toStringAsFixed(4)}, ${project.gpsLng.toStringAsFixed(4)}',
                      style: const TextStyle(
                          color: AppColors.textTertiary, fontSize: 12)),
                ])),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textTertiary),
          ]),
        ),
      ),
    );
  }

  Widget _statusTag(bool active) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFFF2E5) : AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(active ? '进行中' : '已停用',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: active ? AppColors.warning : AppColors.textTertiary)),
      );

  Future<void> _openProject(CheckinProject project) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProjectManagementPage(project: project)));
    if (mounted) _load();
  }

  Future<void> _createProject() async {
    final created = await Navigator.push<CheckinProject>(context,
        MaterialPageRoute(builder: (_) => const ProjectLocationPickerPage()));
    if (created != null && mounted) _load();
  }
}
