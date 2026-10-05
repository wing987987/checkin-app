import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/checkin_team.dart';
import '../../services/management_service.dart';
import '../../core/widgets/supervisor_assignment_confirmation.dart';

class SupervisorAttendancePage extends StatefulWidget {
  final int projectId;
  const SupervisorAttendancePage({super.key, required this.projectId});
  @override
  State<SupervisorAttendancePage> createState() =>
      _SupervisorAttendancePageState();
}

class _SupervisorAttendancePageState extends State<SupervisorAttendancePage> {
  List<Map<String, dynamic>> people = [];
  List<CheckinTeam> teams = [];
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ManagementService.attendanceSupervisors(widget.projectId);
      final t = await ManagementService.teams(widget.projectId);
      if (mounted) {
        setState(() {
          people = r.data ?? [];
          teams = t.data ?? [];
          error = !r.isSuccess
              ? r.message
              : !t.isSuccess
                  ? t.message
                  : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _assign(Map<String, dynamic> person) async {
    int? teamId;
    final selected = await showDialog<int>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
                  title: Text('设置考勤班组 · ${person['realName']}'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                        '管理多个项目的主管只能选择一个考勤项目。使用班组默认班次及附加班次，之后可在用户管理中由另一位主管编辑。'),
                    DropdownButtonFormField<int>(
                        decoration: const InputDecoration(labelText: '考勤班组'),
                        items: teams
                            .map((t) => DropdownMenuItem(
                                value: t.id, child: Text(t.name)))
                            .toList(),
                        onChanged: (v) => setLocal(() => teamId = v)),
                  ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: teamId == null
                            ? null
                            : () => Navigator.pop(ctx, teamId),
                        child: const Text('保存'))
                  ],
                )));
    if (selected == null || !mounted) return;
    try {
      // Refresh before showing the warning, so it describes the latest known assignment.
      final current =
          await ManagementService.attendanceSupervisors(widget.projectId);
      if (!mounted) return;
      if (!current.isSuccess) {
        throw Exception(current.message);
      }
      final matching =
          (current.data ?? []).where((p) => p['id'] == person['id']).toList();
      if (matching.isEmpty) {
        throw Exception('主管项目分配已变化，请刷新后重试');
      }
      final old = matching.first;
      if (old['attendanceProjectId'] != null) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (_) => SupervisorAssignmentConfirmation(
                  name:
                      old['realName']?.toString() ?? old['username'].toString(),
                  project: old['attendanceProjectName']?.toString() ??
                      '项目${old['attendanceProjectId']}',
                  team: old['teamName']?.toString() ?? '未设置班组',
                  shift: old['shiftName']?.toString() ?? '未设置班次',
                  hours: old['startTime'] == null
                      ? ''
                      : '${old['startTime']}～${old['crossDay'] == 1 ? '次日 ' : ''}${old['endTime']}',
                  newTeam: teams.firstWhere((t) => t.id == selected).name,
                ));
        if (confirmed != true || !mounted) return;
      }
      final r = await ManagementService.assignWorker(
          person['id'] as int, widget.projectId, selected, null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.isSuccess ? '考勤班组已设置' : r.message)));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ownId = context.watch<AuthProvider>().currentUser?.id;
    return Scaffold(
        appBar: AppBar(title: const Text('主管考勤分配')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text('自己的考勤班组和异常必须由另一位主管处理。'),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      if (people.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(32),
                            child: Text('本项目暂无负责主管')),
                      ...people.map((p) => Card(
                          child: ListTile(
                              title: Text('${p['realName']}'),
                              subtitle: Text(p['attendanceProjectId'] == null
                                  ? '尚未分配考勤班组'
                                  : p['attendanceProjectId'] == widget.projectId
                                      ? '本项目 · ${p['teamName'] ?? '未选班组'}'
                                      : '考勤项目：${p['attendanceProjectName'] ?? '其他项目'} · ${p['shiftName'] ?? '未设置班次'}'),
                              trailing: p['id'] == ownId
                                  ? const Text('本人 · 只读')
                                  : TextButton(
                                      onPressed: teams.isEmpty
                                          ? null
                                          : () => _assign(p),
                                      child: const Text('设置班组'))))),
                    ])));
  }
}
