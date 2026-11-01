import 'package:flutter/material.dart';
import '../../models/attendance_anomaly.dart';
import '../../services/anomaly_reason_service.dart';
import '../management/anomaly_reason_dialog.dart';

class ForemanAnomaliesPage extends StatefulWidget {
  const ForemanAnomaliesPage({super.key});
  @override
  State<ForemanAnomaliesPage> createState() => _ForemanAnomaliesPageState();
}

class _ForemanAnomaliesPageState extends State<ForemanAnomaliesPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _teams = [];
  List<AttendanceAnomaly> _items = [];
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
      final teams = await AnomalyReasonService.myTeams();
      final items = <AttendanceAnomaly>[];
      for (final t in teams) {
        items.addAll(await AnomalyReasonService.anomalies(
            t['projectId'] as int, t['teamId'] as int));
      }
      if (mounted) {
        setState(() {
          _teams = teams;
          _items = items.where((a) => !a.resolved).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '加载失败：$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('班组异常原因'), actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh))
        ]),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(padding: const EdgeInsets.all(16), children: [
                const Text('班组长仅可填写本班组、负责工种的异常原因，由主管审批处理。'),
                for (final team in _teams)
                  Text('${team['teamName']} · ${team['jobTypeName']}班组长'),
                if (_error != null) Text(_error!),
                if (_error == null && _teams.isEmpty)
                  const Text('您尚未被设置为班组长，请联系主管。'),
                if (_teams.isNotEmpty && _items.isEmpty)
                  const Text('本班组负责工种暂无待处理异常'),
                for (final item in _items)
                  Card(
                      child: ListTile(
                    title: Text('${item.workerName} · ${item.attendanceDate}'),
                    subtitle: Text(
                        '${item.teamName} / ${item.shiftName}\n${item.checkpointName} · ${item.anomalyMessage}'),
                    trailing: const Icon(Icons.edit_note),
                    onTap: () async {
                      await showAnomalyReasons(context, item);
                      if (mounted) _load();
                    },
                  )),
              ]),
      );
}
