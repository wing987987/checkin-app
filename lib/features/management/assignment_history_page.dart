import 'package:flutter/material.dart';
import '../../services/management_service.dart';

class AssignmentHistoryPage extends StatefulWidget {
  final int projectId;
  final int? workerId;
  const AssignmentHistoryPage(
      {super.key, required this.projectId, this.workerId});
  @override
  State<AssignmentHistoryPage> createState() => _AssignmentHistoryPageState();
}

class _AssignmentHistoryPageState extends State<AssignmentHistoryPage> {
  List<Map<String, dynamic>> _items = [];
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
      final result = await ManagementService.assignmentHistory(widget.projectId,
          workerId: widget.workerId);
      if (!mounted) return;
      setState(() {
        _items = result.data ?? [];
        if (!result.isSuccess) _error = result.message;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _date(dynamic value) {
    final text = value?.toString() ?? '';
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('分配 / 转移记录'), actions: [
          IconButton(
              onPressed: _load, icon: const Icon(Icons.refresh), tooltip: '刷新'),
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('重试')),
                  ]))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text(
                            '显示与本项目有关的最近300条记录，包含已转出人员。历史记录自功能升级日起保存；此前转移日期无法自动还原。'),
                        const SizedBox(height: 12),
                        if (_items.isEmpty)
                          const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: Text('暂无记录'))),
                        ..._items.map((item) {
                          final action = const {
                                'baseline': '升级时初始分配',
                                'assign': '分配班组 / 班次',
                                'transfer': '项目转移',
                                'remove_team': '移出班组',
                                'team_shift': '班组主班次调整'
                              }[item['action']] ??
                              '分配调整';
                          final previous = item['previousProjectName'];
                          final project = item['projectName'];
                          return Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          '${item['workerName'] ?? ''} · $action',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Text(previous != null &&
                                              previous != project
                                          ? '$previous → $project'
                                          : '$project'),
                                      Text(
                                          '${item['teamName'] ?? '未分配班组'} · ${item['shiftName'] ?? '未分配班次'}'),
                                      Text(
                                          '生效：${_date(item['effectiveFrom'])}；结束：${item['effectiveTo'] == null ? '当前有效' : '${_date(item['effectiveTo'])}（不含当日）'}'),
                                      Text('操作人：${item['actorName'] ?? '系统'}'),
                                      Text('记录时间：${item['recordedAt'] ?? ''}'),
                                    ],
                                  )));
                        }),
                      ],
                    )),
      );
}
