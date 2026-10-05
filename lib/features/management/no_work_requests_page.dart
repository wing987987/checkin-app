import 'package:flutter/material.dart';
import '../../services/management_service.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class NoWorkRequestsPage extends StatefulWidget {
  final int projectId;
  const NoWorkRequestsPage({super.key, required this.projectId});
  @override
  State<NoWorkRequestsPage> createState() => _NoWorkRequestsPageState();
}

class _NoWorkRequestsPageState extends State<NoWorkRequestsPage> {
  List<Map<String, dynamic>> items = [];
  bool loading = true, busy = false, showProcessed = false;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ManagementService.noWorkRequests(widget.projectId);
      if (!mounted) return;
      setState(() {
        items = r.data ?? [];
        error = r.isSuccess ? null : r.message;
      });
    } catch (e) {
      if (mounted) setState(() => error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> item, String action) async {
    if (item['workerId'] == context.read<AuthProvider>().currentUser?.id) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('不能处理自己的申请，请由另一位主管审批')));
      return;
    }
    final label =
        {'approve': '批准未出工', 'reject': '拒绝申请', 'revoke': '撤销申请'}[action]!;
    String reason = '';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) => AlertDialog(
                  title: Text('确认$label？'),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        '${item['workerName']} · ${item['attendanceDate']} · ${item['shiftName']}\n${action == 'approve' ? '普通工数和工时为0，不再显示缺卡异常；加班独立统计。' : action == 'reject' ? '缺卡保持已确认异常，不再进入异常待办。' : '恢复原考勤状态，之后才可补卡。'}'),
                    const SizedBox(height: 12),
                    TextField(
                        maxLength: 500,
                        onChanged: (v) => setLocal(() => reason = v),
                        decoration: InputDecoration(
                            labelText:
                                action == 'approve' ? '说明（选填）' : '原因（必填）')),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: action != 'approve' && reason.trim().isEmpty
                            ? null
                            : () => Navigator.pop(ctx, true),
                        child: Text(label))
                  ],
                )));
    if (confirmed != true || !mounted) return;
    setState(() => busy = true);
    try {
      final r = await ManagementService.decideNoWork(
          item['id'] as int, action, reason.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.isSuccess ? '已$label' : r.message)));
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('处理失败：$e')));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible =
        items.where((e) => showProcessed || e['status'] == 'pending').toList();
    return Scaffold(
        appBar: AppBar(title: const Text('未出工申请'), actions: [
          const Text('已处理'),
          Switch(
              value: showProcessed,
              onChanged: (v) => setState(() => showProcessed = v))
        ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      Text(
                          '待审批 ${items.where((e) => e['status'] == 'pending').length} 项',
                          style: Theme.of(context).textTheme.titleLarge),
                      if (visible.isEmpty)
                        const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: Text('没有未出工申请'))),
                      ...visible.map((e) => Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '${e['workerName']} · ${e['shiftName']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    Text('${e['attendanceDate']} · ${{
                                      'pending': '待审批',
                                      'approved': '批准未出工 · 0工',
                                      'rejected': '已拒绝 · 已确认异常',
                                      'revoked': '已撤销'
                                    }[e['status']]}'),
                                    if ((e['reason'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text('申请说明：${e['reason']}'),
                                    if ((e['decisionReason'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      Text('处理原因：${e['decisionReason']}'),
                                    Wrap(spacing: 8, children: [
                                      if (e['workerId'] ==
                                          context
                                              .watch<AuthProvider>()
                                              .currentUser
                                              ?.id)
                                        const Text('本人申请，请由另一位主管审批或撤销'),
                                      if (e['workerId'] !=
                                              context
                                                  .watch<AuthProvider>()
                                                  .currentUser
                                                  ?.id &&
                                          e['status'] == 'pending') ...[
                                        FilledButton(
                                            onPressed: busy
                                                ? null
                                                : () => _decide(e, 'approve'),
                                            child: const Text('批准未出工')),
                                        TextButton(
                                            style: TextButton.styleFrom(
                                                foregroundColor: Colors.red),
                                            onPressed: busy
                                                ? null
                                                : () => _decide(e, 'reject'),
                                            child: const Text('拒绝申请')),
                                      ],
                                      if (e['workerId'] !=
                                              context
                                                  .watch<AuthProvider>()
                                                  .currentUser
                                                  ?.id &&
                                          e['status'] != 'revoked')
                                        TextButton(
                                            onPressed: busy
                                                ? null
                                                : () => _decide(e, 'revoke'),
                                            child: const Text('撤销申请')),
                                    ]),
                                  ])))),
                    ])));
  }
}
