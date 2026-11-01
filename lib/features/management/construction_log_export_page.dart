import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/checkin_project.dart';
import '../../providers/auth_provider.dart';
import '../../services/construction_log_service.dart';
import '../../services/pdf_file_service.dart';
import '../../core/theme/app_theme.dart';

class ConstructionExportRange {
  static DateTime beijingToday(DateTime now) {
    final clock = now.toUtc().add(const Duration(hours: 8));
    return DateTime(clock.year, clock.month, clock.day);
  }

  static DateTimeRange defaults(DateTime now) {
    final end = beijingToday(now).subtract(const Duration(days: 1));
    return DateTimeRange(
        start: end.subtract(const Duration(days: 6)), end: end);
  }

  static int days(DateTimeRange range) =>
      DateTime.utc(range.end.year, range.end.month, range.end.day)
          .difference(DateTime.utc(
              range.start.year, range.start.month, range.start.day))
          .inDays +
      1;
}

class ConstructionLogExportPage extends StatefulWidget {
  final CheckinProject project;
  final int? supervisorId;
  final String? supervisorName;
  const ConstructionLogExportPage(
      {super.key,
      required this.project,
      this.supervisorId,
      this.supervisorName});
  @override
  State<ConstructionLogExportPage> createState() =>
      _ConstructionLogExportPageState();
}

class _ConstructionLogExportPageState extends State<ConstructionLogExportPage>
    with WidgetsBindingObserver {
  late DateTimeRange _range;
  late String _key;
  Map<String, dynamic>? _job;
  String? _error, _localPath;
  bool _submitting = false, _refreshing = false, _downloading = false;
  double? _downloadProgress;
  Timer? _timer;
  final _date = DateFormat('yyyy-MM-dd');
  bool get _pending => ['queued', 'processing'].contains(_job?['status']);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _range = ConstructionExportRange.defaults(DateTime.now());
    final actor = context.read<AuthProvider>().currentUser?.id;
    _key =
        'construction_pdf_task_${actor}_${widget.project.id}_${widget.supervisorId ?? 'all'}';
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_key);
    if (!mounted) return;
    final savedPath = prefs.getString('$_key.file');
    if (savedPath != null && await PdfFileService.exists(savedPath)) {
      if (!mounted) return;
      setState(() => _localPath = savedPath);
    }
    if (id == null) return;
    setState(() => _job = {'id': id, 'status': 'queued'});
    await _refresh(restoreDates: true);
  }

  void _watch() {
    _timer?.cancel();
    if (_pending) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_job != null) _refresh();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh({bool restoreDates = false}) async {
    if (_refreshing || _job == null) return;
    _refreshing = true;
    try {
      final result =
          await ConstructionLogService.exportStatus(_job!['id'] as String);
      if (!mounted) return;
      if (!result.isSuccess || result.data == null) {
        if ([400, 403, 404].contains(result.code)) {
          _timer?.cancel();
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove(_key);
          if (!mounted) return;
          setState(() => _job = null);
        }
        throw Exception(result.message);
      }
      setState(() {
        _job = result.data;
        _error = null;
        if (restoreDates) {
          _range = DateTimeRange(
              start: DateTime.parse(_job!['startDate']),
              end: DateTime.parse(_job!['endDate']));
        }
      });
      _watch();
    } catch (e) {
      if (mounted) setState(() => _error = '状态查询失败，请刷新重试');
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _selectRange() async {
    final chosen = await showDateRangePicker(
        context: context,
        initialDateRange: _range,
        firstDate: DateTime(2020),
        lastDate: ConstructionExportRange.beijingToday(DateTime.now()),
        helpText: '选择日志日期（最多31天）',
        saveText: '确定');
    if (!mounted || chosen == null) return;
    if (ConstructionExportRange.days(chosen) > 31) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('起止日期合计最多31天')));
      return;
    }
    setState(() {
      _range = chosen;
      _error = null;
    });
  }

  Future<void> _create() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final result = await ConstructionLogService.exportPdf(widget.project.id,
          startDate: _date.format(_range.start),
          endDate: _date.format(_range.end),
          supervisorId: widget.supervisorId);
      if (!result.isSuccess || result.data == null) {
        throw Exception(result.message);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, result.data!['id'] as String);
      await prefs.remove('$_key.file');
      if (!mounted) return;
      setState(() {
        _job = result.data;
        _localPath = null;
      });
      _watch();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is Exception
            ? e.toString().replaceFirst('Exception: ', '')
            : '导出失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _downloadProgress = null;
      _error = null;
    });
    try {
      // Refresh permission and the one-hour signed link before every download.
      final result =
          await ConstructionLogService.exportStatus(_job!['id'] as String);
      if (!result.isSuccess || result.data?['status'] != 'completed') {
        if (mounted && result.data != null) setState(() => _job = result.data);
        throw Exception('文件已过期或无法下载，请重新导出');
      }
      final path = await PdfFileService.download(
          result.data!['downloadUrl'], result.data!['fileName'],
          taskId: _job!['id'] as String, onProgress: (v) {
        if (mounted) setState(() => _downloadProgress = v);
      });
      if (!kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('$_key.file', path);
      }
      if (mounted) setState(() => _localPath = path);
    } catch (_) {
      if (mounted) setState(() => _error = '下载失败，请检查网络或重新导出');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _openOrShare(bool share) async {
    try {
      if (share) {
        final box = context.findRenderObject() as RenderBox;
        await PdfFileService.share(
            _localPath!, box.localToGlobal(Offset.zero) & box.size);
      } else {
        await PdfFileService.open(_localPath!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _job?['status'];
    final statusText = switch (state) {
      'queued' => '等待生成，正在排队',
      'processing' =>
        '正在生成 ${_job?['processedCount'] ?? 0}/${_job?['logCount'] ?? 0} 份日志',
      'completed' => 'PDF已生成，共 ${_job?['logCount']} 份日志',
      'expired' => '文件已过期，请重新导出',
      'failed' => _job?['errorMessage'] as String? ?? '生成失败，请重试',
      _ => '',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('导出施工日志'), actions: [
        if (_job != null)
          IconButton(
              onPressed: _refresh,
              tooltip: '刷新导出状态',
              icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.project.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 10),
                    Text('提交人：${widget.supervisorName ?? '全部提交人'}'),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                        onPressed: _submitting || _pending || _downloading
                            ? null
                            : _selectRange,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                            '${_date.format(_range.start)} 至 ${_date.format(_range.end)}')),
                    const SizedBox(height: 8),
                    Text(
                        '共 ${ConstructionExportRange.days(_range)} 天 · 默认最近7天，不含今天'),
                    const SizedBox(height: 16),
                    const Text('A4竖版，按日期从早到晚排列。\n仅导出已提交日志，包含考勤快照和水印照片。'),
                  ],
                ))),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: _submitting || _pending || _downloading ? null : _create,
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(_submitting ? '正在创建任务…' : '生成PDF')),
        if (_job != null) ...[
          const SizedBox(height: 16),
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(statusText,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary)),
                      const SizedBox(height: 12),
                      if (_pending) const LinearProgressIndicator(),
                      if (_pending)
                        const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('可以离开此页面，稍后回来查看结果。')),
                      if (state == 'completed') ...[
                        Text(_job!['fileName'] as String),
                        const SizedBox(height: 8),
                        const Text('文件临时保留24小时，下载链接有效1小时。'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                            onPressed: _downloading ? null : _download,
                            icon: const Icon(Icons.download),
                            label: Text(_downloading ? '下载中…' : '下载PDF')),
                      ],
                      if (_downloading)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(
                                value: _downloadProgress)),
                    ],
                  ))),
        ],
        if (_localPath != null)
          Card(
              child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kIsWeb
                    ? '已请求浏览器下载，请查看浏览器下载记录。'
                    : 'PDF已保存到本机，可打开、分享或在阅读器中打印。'),
                if (!kIsWeb)
                  Wrap(spacing: 12, children: [
                    OutlinedButton.icon(
                        onPressed: () => _openOrShare(false),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('打开 / 打印')),
                    OutlinedButton.icon(
                        onPressed: () => _openOrShare(true),
                        icon: const Icon(Icons.share),
                        label: const Text('分享 / 另存')),
                  ]),
              ],
            ),
          )),
        if (_error != null)
          Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_error!, style: const TextStyle(color: Colors.red))),
      ]),
    );
  }
}
