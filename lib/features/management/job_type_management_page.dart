import 'package:flutter/material.dart';

import '../../models/checkin_job_type.dart';
import '../../services/management_service.dart';

class JobTypeManagementPage extends StatefulWidget {
  const JobTypeManagementPage({super.key});

  @override
  State<JobTypeManagementPage> createState() => _JobTypeManagementPageState();
}

class _JobTypeManagementPageState extends State<JobTypeManagementPage> {
  List<CheckinJobType> types = const [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final result = await ManagementService.jobTypes();
      if (!mounted) return;
      if (result.isSuccess) {
        setState(() => types = result.data ?? const []);
      } else {
        _message(result.message);
      }
    } catch (_) {
      if (mounted) _message('加载工种失败');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _message(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _edit([CheckinJobType? type]) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => JobTypeNameDialog(initialName: type?.name),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      final result = type == null
          ? await ManagementService.createJobType(name)
          : await ManagementService.updateJobType(type.id, name);
      if (!mounted) return;
      if (result.isSuccess) {
        await _load();
      } else {
        _message(result.message);
      }
    } catch (_) {
      if (mounted) _message('保存工种失败');
    }
  }

  Future<void> _delete(CheckinJobType type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除工种'),
        content: Text('确定删除“${type.name}”吗？如果还有工人使用，系统会阻止删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final result = await ManagementService.deleteJobType(type.id);
      if (!mounted) return;
      if (result.isSuccess) {
        await _load();
      } else {
        _message(result.message);
      }
    } catch (_) {
      if (mounted) _message('删除工种失败');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('工种管理')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          icon: const Icon(Icons.add),
          label: const Text('新增工种'),
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  children: [
                    if (types.isEmpty) const ListTile(title: Text('暂无工种，请新增')),
                    for (final type in types)
                      Card(
                          child: ListTile(
                        leading: const Icon(Icons.handyman_outlined),
                        title: Text(type.name),
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) =>
                              action == 'edit' ? _edit(type) : _delete(type),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('修改名称')),
                            PopupMenuItem(value: 'delete', child: Text('删除')),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
      );
}

class JobTypeNameDialog extends StatefulWidget {
  final String? initialName;

  const JobTypeNameDialog({super.key, this.initialName});

  @override
  State<JobTypeNameDialog> createState() => _JobTypeNameDialogState();
}

class _JobTypeNameDialogState extends State<JobTypeNameDialog> {
  late String name = widget.initialName ?? '';

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.initialName == null ? '新增工种' : '修改工种'),
        content: TextFormField(
          initialValue: name,
          onChanged: (value) => name = value,
          autofocus: true,
          maxLength: 50,
          decoration:
              const InputDecoration(labelText: '工种名称', hintText: '如：钢筋工'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, name.trim()),
              child: const Text('保存')),
        ],
      );
}
