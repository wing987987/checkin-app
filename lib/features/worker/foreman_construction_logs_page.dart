import 'package:flutter/material.dart';
import '../../models/checkin_project.dart';
import '../../services/construction_log_service.dart';
import '../management/construction_log_page.dart';

class ForemanConstructionLogsPage extends StatefulWidget {
  const ForemanConstructionLogsPage({super.key});
  @override
  State<ForemanConstructionLogsPage> createState() =>
      _ForemanConstructionLogsPageState();
}

class _ForemanConstructionLogsPageState
    extends State<ForemanConstructionLogsPage> {
  List<CheckinProject> _projects = [];
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
      final result = await ConstructionLogService.availableProjects();
      if (!result.isSuccess) throw Exception(result.message);
      if (mounted) setState(() => _projects = result.data ?? []);
    } catch (e) {
      if (mounted) setState(() => _error = '项目加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('班组长施工日志'), actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                const Text('填写今日施工进度、明日计划并上传照片。昨日考勤汇总仅包含本人负责班组、工种的人员。'),
                if (_error != null) Text(_error!),
                if (_error == null && _projects.isEmpty)
                  const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: Text('暂无可填写项目，请确认您已被设置为本班组的班组长。')),
                for (final project in _projects)
                  Card(
                      child: ListTile(
                    title: Text(project.name),
                    subtitle: const Text('填写 / 查看今日施工日志'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                ConstructionLogPage(project: project))),
                  )),
              ]),
      );
}
