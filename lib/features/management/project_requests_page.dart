import 'package:flutter/material.dart';
import '../../core/models/api_result.dart';
import '../../services/management_service.dart';

class ProjectRequestsPage extends StatefulWidget {
  final Future<ApiResult<List<Map<String, dynamic>>>> Function()? load;
  final Future<ApiResult<dynamic>> Function(int, String)? decide;
  const ProjectRequestsPage({super.key, this.load, this.decide});
  @override
  State<ProjectRequestsPage> createState() => _ProjectRequestsPageState();
}

class _ProjectRequestsPageState extends State<ProjectRequestsPage> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  final Set<int> _saving = {};
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
      final result = await (widget.load ?? ManagementService.projectRequests)();
      if (!mounted) return;
      setState(() {
        _items = result.data ?? [];
        if (!result.isSuccess) _error = result.message;
      });
    } catch (_) {
      if (mounted) setState(() => _error = '申请加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(int id, String action) async {
    setState(() => _saving.add(id));
    try {
      final result = await (widget.decide ??
          ManagementService.decideProjectRequest)(id, action);
      if (!mounted) return;
      if (result.isSuccess) {
        await _load();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(result.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('处理失败，请重试')));
      }
    } finally {
      if (mounted) setState(() => _saving.remove(id));
    }
  }

  Widget _list(bool pending) {
    final rows =
        _items.where((r) => (r['status'] == 'pending') == pending).toList();
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (rows.isEmpty)
                Padding(
                    padding: const EdgeInsets.all(48),
                    child:
                        Center(child: Text(pending ? '暂无待处理申请' : '暂无已处理申请'))),
              ...rows.map((r) {
                final id = (r['id'] as num).toInt();
                return Card(
                    child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${r['supervisorName']} · ${r['projectName']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('账号：${r['username']}'),
                            Text('申请时间：${r['createTime']}'),
                            if (pending)
                              Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                        onPressed: _saving.contains(id)
                                            ? null
                                            : () => _decide(id, 'reject'),
                                        child: const Text('拒绝')),
                                    const SizedBox(width: 8),
                                    FilledButton(
                                        onPressed: _saving.contains(id)
                                            ? null
                                            : () => _decide(id, 'approve'),
                                        child: Text(_saving.contains(id)
                                            ? '处理中…'
                                            : '同意')),
                                  ])
                            else
                              Text(
                                  '${r['status'] == 'approved' ? '已同意' : '已拒绝'} · ${r['actorName'] ?? ''} · ${r['decidedTime'] ?? ''}'),
                          ],
                        )));
              }),
            ]));
  }

  @override
  Widget build(BuildContext context) {
    final count = _items.where((r) => r['status'] == 'pending').length;
    return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
              title: const Text('项目申请'),
              actions: [
                IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新')
              ],
              bottom: TabBar(
                  tabs: [Tab(text: '待处理 ($count)'), const Tab(text: '已处理')])),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('重试'))
                    ]))
                  : TabBarView(children: [_list(true), _list(false)]),
        ));
  }
}
