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
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class SupervisorHomePage extends StatefulWidget {
  const SupervisorHomePage({super.key});
  @override
  State<SupervisorHomePage> createState() => _SupervisorHomePageState();
}

class _SupervisorHomePageState extends State<SupervisorHomePage> {
  List<CheckinProject> _projects = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ManagementService.projects();
      if (!mounted) return;
      setState(() {
        _projects = result.data ?? const [];
        _error = result.isSuccess ? null : result.message;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '项目加载失败，请检查网络');
    } finally {
      if (mounted) setState(() => _loading = false);
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
      body: AppBackground(child: _body()),
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
    if (_projects.isEmpty) {
      return AppEmptyState(
          icon: Icons.folder_open_outlined,
          title: '还没有负责的项目',
          description: '新建项目后，可在这里管理定位、班组和考勤。');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _projects.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox(height: 12) : const SizedBox(height: 8),
        itemBuilder: (_, index) {
          if (index == 0) {
            return Row(children: [
              Text('全部项目', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Text('共 ${_projects.length} 个',
                  style: const TextStyle(
                      color: AppColors.textTertiary, fontSize: 12)),
            ]);
          }
          return _projectItem(_projects[index - 1]);
        },
      ),
    );
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
