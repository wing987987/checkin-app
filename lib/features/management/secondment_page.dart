import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/checkin_project.dart';
import '../../models/checkin_team.dart';
import '../../models/checkin_shift.dart';
import '../../models/worker_assignment.dart';
import '../../services/management_service.dart';

class SecondmentPage extends StatefulWidget {
  final CheckinProject project;
  final WorkerAssignment? worker;
  const SecondmentPage({super.key, required this.project, this.worker});
  @override
  State<SecondmentPage> createState() => _SecondmentPageState();
}

class _SecondmentPageState extends State<SecondmentPage> {
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
      final result = await ManagementService.secondments(widget.project.id);
      if (!result.isSuccess) throw Exception(result.message);
      if (mounted) {
        setState(() => _items = (result.data ?? [])
            .where((r) =>
                widget.worker == null ||
                r['worker_id'] == widget.worker!.workerId)
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _error = '借调记录加载失败，请重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? loan]) async {
    final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => SecondmentDialog(
            project: widget.project, worker: widget.worker, loan: loan));
    if (saved == true && mounted) await _load();
  }

  String _slot(dynamic date, dynamic half) =>
      '${date.toString().split('T').first} ${half == 0 ? '上午' : '下午'}起';

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(
                '${widget.worker?.realName ?? widget.project.name} · 临时借调')),
        floatingActionButton: widget.worker != null &&
                !_loading &&
                _error == null &&
                !_items.any((r) => r['end_date'] == null)
            ? FloatingActionButton.extended(
                onPressed: () => _edit(),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('开始借调'))
            : null,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: TextButton(onPressed: _load, child: Text(_error!)))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        children: [
                          const Text(
                              '临时借调不改变常驻项目。开始时不填结束日期，实际返回时设置上午或下午返回。\n普通四次打卡白班适用；由同时管理原项目和目标项目的主管或老总操作。'),
                          const SizedBox(height: 16),
                          if (_items.isEmpty)
                            const Text('暂无借调记录。可从原项目的人员菜单选择“临时借调 / 返回”开始安排。'),
                          ..._items.map((r) => Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${r['worker_name']} · ${r['source_project_name']} → ${r['target_project_name']}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium),
                                        const SizedBox(height: 8),
                                        Text(
                                            '原班组/班次：${r['source_team_name']} / ${r['source_shift_name']}\n借调班组/班次：${r['target_team_name']} / ${r['target_shift_name']}'),
                                        Text(
                                            '开始：${_slot(r['start_date'], r['start_half'])}'),
                                        Text(r['end_date'] == null
                                            ? '尚未设置返回时间 · 持续在目标项目考勤'
                                            : '返回原项目：${_slot(r['end_date'], r['end_half'])}'),
                                        if ((r['reason'] ?? '')
                                            .toString()
                                            .isNotEmpty)
                                          Text('原因：${r['reason']}'),
                                        if (r['end_date'] == null)
                                          Align(
                                              alignment: Alignment.centerRight,
                                              child: TextButton(
                                                  onPressed: () => _edit(r),
                                                  child: const Text(
                                                      '结束借调，返回原项目'))),
                                      ])))),
                        ])),
      );
}

class SecondmentDialog extends StatefulWidget {
  final CheckinProject project;
  final WorkerAssignment? worker;
  final Map<String, dynamic>? loan;
  const SecondmentDialog(
      {super.key, required this.project, this.worker, this.loan});
  @override
  State<SecondmentDialog> createState() => _SecondmentDialogState();
}

class _SecondmentDialogState extends State<SecondmentDialog> {
  final _reason = TextEditingController();
  final _scrollController = ScrollController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  int _half = 0;
  List<CheckinProject> _projects = [];
  List<CheckinTeam> _teams = [];
  List<CheckinShift> _shifts = [];
  int? _project, _team, _shift;
  bool _loading = true, _saving = false;
  String? _error;
  bool get _ending => widget.loan != null;
  @override
  void initState() {
    super.initState();
    if (_ending) {
      final start = DateTime.parse(
          widget.loan!['start_date'].toString().split('T').first);
      if (start.isAfter(_date)) _date = start;
      if (DateUtils.isSameDay(start, _date)) {
        _half = widget.loan!['start_half'] as int;
      }
      _loading = false;
    } else {
      _loadProjects();
    }
  }

  @override
  void dispose() {
    _reason.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    try {
      final result = await ManagementService.projects();
      if (!result.isSuccess) throw Exception(result.message);
      if (mounted) {
        setState(() => _projects = (result.data ?? [])
            .where((p) => p.id != widget.project.id && p.status == 'active')
            .toList());
      }
    } catch (_) {
      if (mounted) setState(() => _error = '目标项目加载失败，请关闭后重试');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectProject(int? id) async {
    if (id == null) return;
    setState(() {
      _project = id;
      _team = null;
      _shift = null;
      _teams = [];
      _shifts = [];
      _loading = true;
      _error = null;
    });
    try {
      final teams = await ManagementService.teams(id);
      final shifts = await ManagementService.shifts(id);
      if (!teams.isSuccess || !shifts.isSuccess) throw Exception();
      if (mounted) {
        setState(() {
          _teams = (teams.data ?? [])
              .where((t) => t.status == 1 && t.extraShiftIds.isEmpty)
              .toList();
          _shifts = (shifts.data ?? [])
              .where(
                  (s) => s.status == 1 && s.shiftType == 'day' && !s.crossDay)
              .toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = '班组和班次加载失败，请重新选择项目');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _loading) return;
    if (!_ending && (_project == null || _team == null || _shift == null)) {
      setState(() => _error = '请选择目标项目、班组和白班班次');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final data = <String, dynamic>{
      'date': DateFormat('yyyy-MM-dd').format(_date),
      'half': _half,
      if (!_ending) ...{
        'projectId': _project,
        'teamId': _team,
        'shiftId': _shift,
        'reason': _reason.text.trim()
      }
    };
    try {
      final result = _ending
          ? await ManagementService.endSecondment(
              widget.loan!['id'] as int, data)
          : await ManagementService.startSecondment(
              widget.worker!.workerId, data);
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = result.message);
      }
    } catch (_) {
      if (mounted) setState(() => _error = '保存失败，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title:
            Text(_ending ? '结束借调，返回原项目' : '${widget.worker!.realName} · 开始借调'),
        content: SizedBox(
            width: double.maxFinite,
            child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(0, 8, 14, 8),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!_ending) ...[
                            DropdownButtonFormField<int>(
                                initialValue: _project,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: '目标项目'),
                                items: _projects
                                    .map((p) => DropdownMenuItem(
                                        value: p.id, child: Text(p.name)))
                                    .toList(),
                                onChanged: _saving || _loading
                                    ? null
                                    : _selectProject),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                                key: ValueKey('team-$_project-$_team'),
                                initialValue: _team,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: '目标班组'),
                                items: _teams
                                    .map((t) => DropdownMenuItem(
                                        value: t.id, child: Text(t.name)))
                                    .toList(),
                                onChanged: _saving || _loading
                                    ? null
                                    : (id) => setState(() {
                                          _team = id;
                                          final t = _teams
                                              .firstWhere((t) => t.id == id);
                                          _shift = _shifts
                                                  .any((s) => s.id == t.shiftId)
                                              ? t.shiftId
                                              : null;
                                        })),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                                key: ValueKey('shift-$_project-$_shift'),
                                initialValue: _shift,
                                isExpanded: true,
                                decoration:
                                    const InputDecoration(labelText: '目标白班班次'),
                                items: _shifts
                                    .map((s) => DropdownMenuItem(
                                        value: s.id, child: Text(s.name)))
                                    .toList(),
                                onChanged: _saving || _loading
                                    ? null
                                    : (id) => setState(() => _shift = id)),
                            const SizedBox(height: 16),
                            TextField(
                                controller: _reason,
                                enabled: !_saving,
                                maxLength: 500,
                                decoration: const InputDecoration(
                                    labelText: '借调原因（选填）')),
                          ],
                          if (_loading) const LinearProgressIndicator(),
                          const SizedBox(height: 16),
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(_ending ? '返回日期' : '开始日期'),
                              subtitle:
                                  Text(DateFormat('yyyy-MM-dd').format(_date)),
                              trailing: const Icon(Icons.calendar_month),
                              onTap: _saving
                                  ? null
                                  : () async {
                                      final date = await showDatePicker(
                                          context: context,
                                          initialDate: _date,
                                          firstDate: DateUtils.dateOnly(
                                              DateTime.now()),
                                          lastDate: DateTime.now()
                                              .add(const Duration(days: 730)));
                                      if (date != null && mounted) {
                                        setState(() => _date = date);
                                      }
                                    }),
                          const SizedBox(height: 16),
                          SegmentedButton<int>(
                              segments: [
                                ButtonSegment(
                                    value: 0,
                                    label: Text(_ending ? '上午起返回' : '上午开始')),
                                ButtonSegment(
                                    value: 1,
                                    label: Text(_ending ? '下午起返回' : '下午开始'))
                              ],
                              selected: {
                                _half
                              },
                              onSelectionChanged: _saving
                                  ? null
                                  : (v) => setState(() => _half = v.first)),
                          const SizedBox(height: 16),
                          Text(_ending
                              ? '${DateFormat('yyyy-MM-dd').format(_date)} ${_half == 0 ? '上午' : '下午'}起恢复 ${widget.loan!['source_project_name']} / ${widget.loan!['source_team_name']} / ${widget.loan!['source_shift_name']}。此前借调考勤保留。\n取消未开始的借调，可选择借调开始时段返回。'
                              : '${DateFormat('yyyy-MM-dd').format(_date)} ${_half == 0 ? '上午' : '下午'}起在目标项目考勤，持续至手动结束借调。常驻项目仍为${widget.project.name}。'),
                          const SizedBox(height: 8),
                          const Text('变更时段已有打卡或人工处理记录时，不能直接覆盖。'),
                          if (_error != null)
                            Text(_error!,
                                style: const TextStyle(color: Colors.red)),
                        ])))),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text('取消')),
          FilledButton(
              onPressed: _saving || _loading ? null : _save,
              child: Text(_saving
                  ? '保存中…'
                  : _ending
                      ? '确认返回'
                      : '确认开始借调'))
        ],
      ));
}
