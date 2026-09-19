import 'package:flutter/material.dart';

import '../../core/widgets/dialog_scroll_view.dart';
import '../../models/checkin_project.dart';
import '../../models/checkin_supervisor.dart';
import '../../services/management_service.dart';

class SupervisorManagementPage extends StatefulWidget {
  const SupervisorManagementPage({super.key});

  @override
  State<SupervisorManagementPage> createState() =>
      _SupervisorManagementPageState();
}

class _SupervisorManagementPageState extends State<SupervisorManagementPage> {
  List<CheckinSupervisor> _supervisors = const [];
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
      final values = await Future.wait([
        ManagementService.supervisors(),
        ManagementService.projects(),
      ]);
      if (!mounted) return;
      setState(() {
        _supervisors = values[0].data as List<CheckinSupervisor>? ?? const [];
        _projects = values[1].data as List<CheckinProject>? ?? const [];
        if (!values[0].isSuccess) _error = values[0].message;
        if (!values[1].isSuccess) _error = values[1].message;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '主管信息加载失败，请检查网络');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('主管管理'),
          actions: [
            IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createSupervisor,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('新建主管'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _supervisors.isEmpty
                        ? ListView(children: const [
                            SizedBox(height: 180),
                            Center(child: Text('暂无主管')),
                          ])
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                            itemCount: _supervisors.length,
                            itemBuilder: (_, index) =>
                                _supervisorCard(_supervisors[index]),
                          ),
                  ),
      );

  Widget _supervisorCard(CheckinSupervisor supervisor) {
    final assigned = _projects
        .where((project) => supervisor.projectIds.contains(project.id))
        .map((project) => project.name)
        .join('、');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(supervisor.realName.isEmpty
              ? '?'
              : supervisor.realName.substring(0, 1)),
        ),
        title: Text(supervisor.realName.isEmpty
            ? supervisor.username
            : supervisor.realName),
        subtitle: Text(
            '用户名：${supervisor.username}\n负责项目：${assigned.isEmpty ? '暂未分配' : assigned}'),
        isThreeLine: true,
        trailing: TextButton.icon(
          onPressed: () => _assignProjects(supervisor),
          icon: const Icon(Icons.folder_shared_outlined, size: 20),
          label: const Text('项目绑定'),
        ),
      ),
    );
  }

  Future<void> _createSupervisor() async {
    final username = TextEditingController();
    final password = TextEditingController(text: '123456');
    final realName = TextEditingController();
    final phone = TextEditingController();
    final selected = <int>{};
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: const Text('新建主管'),
          content: DialogScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: realName,
                  decoration: const InputDecoration(labelText: '姓名')),
              const SizedBox(height: 12),
              TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: '登录用户名')),
              const SizedBox(height: 12),
              TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '初始密码')),
              const SizedBox(height: 12),
              TextField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: '手机号（选填）')),
              const SizedBox(height: 16),
              const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('负责项目',
                      style: TextStyle(fontWeight: FontWeight.w600))),
              ..._projects.map((project) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(project.name),
                    value: selected.contains(project.id),
                    onChanged: (checked) => setLocal(() {
                      if (checked == true) {
                        selected.add(project.id);
                      } else {
                        selected.remove(project.id);
                      }
                    }),
                  )),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (username.text.trim().length < 3 ||
                    password.text.length < 4 ||
                    realName.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('请填写姓名、至少3位用户名和至少4位密码')));
                  return;
                }
                final result = await ManagementService.createSupervisor({
                  'username': username.text.trim(),
                  'password': password.text,
                  'realName': realName.text.trim(),
                  'phone': phone.text.trim(),
                  'projectIds': selected.toList(),
                });
                if (!ctx.mounted) return;
                if (result.isSuccess) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(result.message)));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    username.dispose();
    password.dispose();
    realName.dispose();
    phone.dispose();
    if (saved == true) _load();
  }

  Future<void> _assignProjects(CheckinSupervisor supervisor) async {
    final selected = supervisor.projectIds.toSet();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: Text('分配项目 · ${supervisor.realName}'),
          content: DialogScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: _projects
                  .map((project) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(project.name),
                        value: selected.contains(project.id),
                        onChanged: (checked) => setLocal(() {
                          if (checked == true) {
                            selected.add(project.id);
                          } else {
                            selected.remove(project.id);
                          }
                        }),
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                final result = await ManagementService.assignSupervisorProjects(
                    supervisor.id, selected.toList());
                if (!ctx.mounted) return;
                if (result.isSuccess) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(result.message)));
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
}
