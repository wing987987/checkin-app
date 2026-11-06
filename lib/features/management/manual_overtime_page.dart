import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/network/dio_client.dart';
import '../../services/anomaly_reason_service.dart';

class ManualOvertimePage extends StatefulWidget {
  final int? projectId;
  final String? projectName;
  final DateTime? date;
  const ManualOvertimePage(
      {super.key, this.projectId, this.projectName, this.date});

  @override
  State<ManualOvertimePage> createState() => _ManualOvertimePageState();
}

class _ManualOvertimePageState extends State<ManualOvertimePage> {
  static const _path = '/api/ck/manual-overtime';
  final _reason = TextEditingController();
  late DateTime _date = widget.date ?? DateTime.now();
  late int? _project = widget.projectId;
  int? _worker;
  TimeOfDay? _start, _end;
  List<Map<String, dynamic>> _projects = [], _people = [], _records = [];
  bool _busy = true;
  String? _error;
  bool get _manager => widget.projectId != null;
  String get _dateText => DateFormat('yyyy-MM-dd').format(_date);

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<dynamic> _result(Future<dynamic> request) async {
    final response = await request;
    final body = response.data as Map;
    if (body['code'] != 200) throw Exception(body['message'] ?? '操作失败');
    return body['data'];
  }

  List<Map<String, dynamic>> _rows(dynamic data) => (data as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> _loadProjects() async {
    try {
      if (!_manager) {
        final teams = await AnomalyReasonService.myTeams();
        if (!mounted) return;
        final projects = {for (final team in teams) team['projectId']: team};
        _projects = projects.values.toList();
        _project =
            _projects.isEmpty ? null : _projects.first['projectId'] as int;
      }
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _message(e);
        });
      }
    }
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final query = {'projectId': _project, 'date': _dateText};
      final values = _project == null
          ? [null, null]
          : await Future.wait([
              _result(DioClient.instance
                  .get('$_path/people', queryParameters: query)),
              _result(DioClient.instance.get(_path, queryParameters: query)),
            ]);
      if (!mounted) return;
      setState(() {
        _people = _rows(values[0]);
        _records = _rows(values[1]);
        if (!_people.any((p) => p['id'] == _worker)) _worker = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _people = [];
          _records = [];
          _error = _message(e);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object error) =>
      error.toString().replaceFirst('Exception: ', '');
  String _time(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;
  int get _duration =>
      _start == null || _end == null ? 0 : _minutes(_end!) - _minutes(_start!);

  Future<bool> _confirm(List warnings, String action) async {
    if (!mounted) return false;
    return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                  title: Text(action),
                  content: Text(warnings.isEmpty
                      ? '确认后将生成加班开始和结束两张打卡记录。'
                      : warnings.join('\n')),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('返回')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('确认')),
                  ],
                )) ==
        true;
  }

  Future<void> _submit() async {
    if (_worker == null ||
        _start == null ||
        _end == null ||
        _duration <= 0 ||
        _reason.text.trim().isEmpty) {
      _notice('请选择工人及当天有效的起止时间，并填写加班原因');
      return;
    }
    final data = <String, dynamic>{
      'projectId': _project,
      'workerId': _worker,
      'date': _dateText,
      'start': _time(_start!),
      'end': _time(_end!),
      'reason': _reason.text.trim()
    };
    setState(() => _busy = true);
    try {
      final warnings =
          await _result(DioClient.instance.post('$_path/check', data: data))
              as List;
      if ((_manager || warnings.isNotEmpty) &&
          !await _confirm(warnings, _manager ? '确认手填加班' : '确认提交审批')) {
        return;
      }
      if (!mounted) return;
      await _result(DioClient.instance.post(_path,
          data: {...data, 'acceptExtraShift': warnings.isNotEmpty}));
      if (!mounted) return;
      _reason.clear();
      _notice(_manager ? '加班已记录' : '已提交，等待主管或老总审批');
      await _load();
    } catch (e) {
      _notice(_message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(int id, bool approve) async {
    setState(() => _busy = true);
    try {
      final warnings = approve
          ? await _result(DioClient.instance.get('$_path/$id/review-check'))
              as List
          : ['退回后该申请不会计入加班。'];
      if (!await _confirm(warnings, approve ? '确认通过申请' : '确认退回申请')) return;
      if (!mounted) return;
      await _result(DioClient.instance.post('$_path/$id/review', data: {
        'approve': approve,
        'acceptExtraShift': approve && warnings.isNotEmpty
      }));
      _notice(approve ? '已通过，加班已记录' : '申请已退回');
      if (mounted) await _load();
    } catch (e) {
      _notice(_message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _pickTime(bool start) async {
    final value = await showTimePicker(
        context: context,
        initialTime: (start ? _start : _end) ?? TimeOfDay.now());
    if (value == null || !mounted) return;
    setState(() {
      if (start) {
        _start = value;
      } else {
        _end = value;
      }
    });
  }

  String _status(dynamic status) =>
      const {'pending': '待审批', 'approved': '已记录', 'rejected': '已退回'}[status] ??
      '$status';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_manager ? '手填加班与审批' : '班组长加班申请'), actions: [
          IconButton(
              tooltip: '刷新',
              onPressed: _busy ? null : _loadProjects,
              icon: const Icon(Icons.refresh)),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (widget.projectName != null)
            Text(widget.projectName!,
                style: Theme.of(context).textTheme.titleMedium),
          if (!_manager && _projects.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _project,
              decoration: const InputDecoration(labelText: '实际加班项目'),
              items: _projects
                  .map((p) => DropdownMenuItem(
                      value: p['projectId'] as int,
                      child: Text('${p['projectName']}')))
                  .toList(),
              onChanged: _busy
                  ? null
                  : (id) {
                      setState(() {
                        _project = id;
                        _worker = null;
                      });
                      _load();
                    },
            ),
          if (!_busy && !_manager && _projects.isEmpty && _error == null)
            const Text('暂无可提交加班申请的班组。'),
          if (_project != null) ...[
            OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text('考勤日期 $_dateText'),
                onPressed: _busy
                    ? null
                    : () async {
                        final today = DateUtils.dateOnly(DateTime.now());
                        final picked = await showDatePicker(
                            context: context,
                            initialDate: _date.isAfter(today) ? today : _date,
                            firstDate: DateTime(2000),
                            lastDate: today);
                        if (!mounted || picked == null) return;
                        setState(() {
                          _date = picked;
                          _worker = null;
                        });
                        await _load();
                      }),
            DropdownButtonFormField<int>(
                key: ValueKey('$_project/$_dateText/$_worker'),
                initialValue: _worker,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '工人'),
                items: _people
                    .map((p) => DropdownMenuItem(
                        value: p['id'] as int, child: Text('${p['name']}')))
                    .toList(),
                onChanged: _busy || _people.isEmpty
                    ? null
                    : (id) => setState(() => _worker = id)),
            if (!_busy && _people.isEmpty && _error == null)
              const Text('当天暂无可提交的工人。'),
            Wrap(spacing: 12, children: [
              OutlinedButton(
                  onPressed: _busy ? null : () => _pickTime(true),
                  child:
                      Text('开始 ${_start == null ? '选择时间' : _time(_start!)}')),
              OutlinedButton(
                  onPressed: _busy ? null : () => _pickTime(false),
                  child: Text('结束 ${_end == null ? '选择时间' : _time(_end!)}')),
            ]),
            if (_duration > 0)
              Text('加班时长 ${_duration ~/ 60}小时${_duration % 60}分钟'),
            TextField(
                controller: _reason,
                enabled: !_busy,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '加班原因（必填）')),
            FilledButton(
                onPressed: _busy || _people.isEmpty ? null : _submit,
                child: Text(_manager ? '确认记录加班' : '提交加班申请')),
            const Divider(height: 32),
            Text('加班记录与待审批申请', style: Theme.of(context).textTheme.titleMedium),
            if (!_busy && _records.isEmpty && _error == null)
              const Text('暂无记录'),
            for (final row in _records)
              Card(
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${row['workerName']} · ${_status(row['status'])}',
                              style: Theme.of(context).textTheme.titleSmall),
                          Text('${row['startsAt']} — ${row['endsAt']}'),
                          Text('加班原因：${row['reason']}'),
                          Text(
                              '提交人：${row['submittedBy']} · ${row['submittedAt']}'),
                          if (row['reviewedBy'] != null)
                            Text(
                                '处理人：${row['reviewedBy']} · ${row['reviewedAt']}'),
                          if (_manager && row['status'] == 'pending')
                            Wrap(spacing: 8, children: [
                              TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _review(row['id'] as int, false),
                                  child: const Text('退回')),
                              FilledButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _review(row['id'] as int, true),
                                  child: const Text('通过')),
                            ]),
                        ],
                      ))),
          ],
        ]),
      );
}
