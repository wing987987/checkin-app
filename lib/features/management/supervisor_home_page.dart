import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/checkin_project.dart';
import '../../providers/auth_provider.dart';
import '../../services/management_service.dart';
import 'project_location_picker_page.dart';
import 'project_management_page.dart';

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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('项目管理'), actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout)),
        ]),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: _createProject,
            icon: const Icon(Icons.add),
            label: const Text('新建项目')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : _projects.isEmpty
                    ? const Center(child: Text('还没有负责的项目'))
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _projects.length,
                          itemBuilder: (_, i) {
                            final p = _projects[i];
                            return ListTile(
                              leading: const CircleAvatar(
                                  child: Icon(Icons.location_on)),
                              title: Text(p.name),
                              subtitle: Text('打卡范围 ${p.fenceRadius} 米'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          ProjectManagementPage(project: p))),
                            );
                          },
                        )),
      );

  Future<void> _createProject() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const ProjectLocationPickerPage(),
      ),
    );
    if (created == true && mounted) _load();
  }
}
