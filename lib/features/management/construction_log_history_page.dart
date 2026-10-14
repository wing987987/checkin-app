import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/checkin_project.dart';
import '../../services/construction_log_service.dart';
import 'construction_log_page.dart';
import 'construction_log_export_page.dart';

class ConstructionLogHistoryPage extends StatefulWidget {
  final CheckinProject project;
  const ConstructionLogHistoryPage({super.key, required this.project});
  @override
  State<ConstructionLogHistoryPage> createState() =>
      _ConstructionLogHistoryPageState();
}

class _ConstructionLogHistoryPageState
    extends State<ConstructionLogHistoryPage> {
  List<Map<String, dynamic>> _items = [], _authors = [];
  String? _date, _error;
  int? _supervisor;
  bool _loading = true;
  bool _loadingMore = false, _hasMore = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ConstructionLogService.history(widget.project.id,
            date: _date, supervisorId: _supervisor),
        ConstructionLogService.authors(widget.project.id),
      ]);
      final r = results[0];
      if (!r.isSuccess) throw Exception(r.message);
      if (!results[1].isSuccess) throw Exception(results[1].message);
      if (mounted && generation == _generation) {
        setState(() {
          _items = r.data ?? [];
          _authors = results[1].data ?? [];
          _hasMore = _items.length == 200;
          _loadingMore = false;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = '日志加载失败，请重试');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    final generation = _generation;
    setState(() => _loadingMore = true);
    try {
      final r = await ConstructionLogService.history(widget.project.id,
          date: _date, supervisorId: _supervisor, offset: _items.length);
      if (!r.isSuccess) throw Exception(r.message);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(r.data ?? []);
        _hasMore = (r.data?.length ?? 0) == 200;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('加载失败，请重试')));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
        context: context,
        initialDate: _date == null ? DateTime.now() : DateTime.parse(_date!),
        firstDate: DateTime(2020),
        lastDate: DateTime.now());
    if (d != null && mounted) {
      setState(() {
        _date = DateFormat('yyyy-MM-dd').format(d);
      });
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final supervisors = <int, String>{
      for (final row in _authors) row['id'] as int: row['name'] as String
    };
    return Scaffold(
        appBar: AppBar(title: const Text('项目施工日志'), actions: [
          IconButton(
              tooltip: '导出PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ConstructionLogExportPage(
                          project: widget.project,
                          supervisorId: _supervisor,
                          supervisorName: supervisors[_supervisor])))),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ]),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: Text(_date ?? '全部日期')),
                    DropdownButton<int>(
                        value: _supervisor,
                        hint: const Text('全部主管'),
                        items: [
                          const DropdownMenuItem<int>(
                              value: null, child: Text('全部主管')),
                          ...supervisors.entries.map((e) => DropdownMenuItem(
                              value: e.key, child: Text(e.value)))
                        ],
                        onChanged: _loading
                            ? null
                            : (v) {
                                setState(() {
                                  _supervisor = v;
                                });
                                _load();
                              }),
                    if (_date != null || _supervisor != null)
                      TextButton(
                          onPressed: _loading
                              ? null
                              : () {
                                  setState(() {
                                    _date = null;
                                    _supervisor = null;
                                  });
                                  _load();
                                },
                          child: const Text('清除筛选')),
                  ])),
          Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: TextButton(
                              onPressed: _load, child: Text(_error!)))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                              padding: const EdgeInsets.all(16),
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                if (_items.isEmpty)
                                  const Padding(
                                      padding: EdgeInsets.all(32),
                                      child: Center(child: Text('暂无已提交日志'))),
                                for (final date in _items
                                    .map((row) => row['logDate'] as String)
                                    .toSet()
                                    .toList()
                                  ..sort((a, b) => b.compareTo(a))) ...[
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          0, 16, 0, 8),
                                      child: Text(date,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium)),
                                  ..._items
                                      .where((row) => row['logDate'] == date)
                                      .map((row) => Card(
                                          child: ListTile(
                                              title: Text(
                                                  '${row['supervisorName']}'),
                                              subtitle: Text(
                                                  row['progress'] as String,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis),
                                              trailing: const Icon(
                                                  Icons.chevron_right),
                                              onTap: () => Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                      builder: (_) =>
                                                          ConstructionLogPage(
                                                              project: widget.project,
                                                              logId: row['id'] as int)))))),
                                ],
                                if (_hasMore)
                                  TextButton(
                                      onPressed: _loading || _loadingMore
                                          ? null
                                          : _loadMore,
                                      child: Text(
                                          _loadingMore ? '加载中…' : '加载更早日志')),
                                Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                        '已显示 ${_items.length} 份日志 · 日期由新到旧',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12))),
                              ]))),
        ]));
  }
}
