import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/checkin_project.dart';
import '../../services/construction_log_service.dart';
import 'construction_log_page.dart';

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
      final results = await Future.wait([
        ConstructionLogService.history(widget.project.id,
            date: _date, supervisorId: _supervisor),
        ConstructionLogService.authors(widget.project.id),
      ]);
      final r = results[0];
      if (!r.isSuccess) throw Exception(r.message);
      if (!results[1].isSuccess) throw Exception(results[1].message);
      if (mounted) {
        setState(() {
          _items = r.data ?? [];
          _authors = results[1].data ?? [];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '日志加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
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
        appBar: AppBar(title: const Text('历史施工日志'), actions: [
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
                                ..._items.map((row) => Card(
                                    child: ListTile(
                                        title: Text(
                                            '${row['logDate']} · ${row['supervisorName']}'),
                                        subtitle: Text(
                                            row['progress'] as String,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis),
                                        trailing:
                                            const Icon(Icons.chevron_right),
                                        onTap: () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) =>
                                                    ConstructionLogPage(
                                                        project: widget.project,
                                                        logId: row['id']
                                                            as int)))))),
                                const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text('显示符合筛选条件的最近200份日志',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                            color: Colors.grey, fontSize: 12))),
                              ]))),
        ]));
  }
}
