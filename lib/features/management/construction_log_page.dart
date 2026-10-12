import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../models/checkin_project.dart';
import '../../providers/auth_provider.dart';
import '../../services/construction_log_service.dart';
import '../../services/log_reminder_service.dart';
import '../../core/utils/watermark_utils.dart';
import '../../core/widgets/zoomable_network_image.dart';
import 'anomaly_list_page.dart';
import 'no_work_requests_page.dart';

class _LogPhoto {
  int? id;
  String? url;
  Uint8List? bytes;
  String filename = 'construction.jpg', subtype = 'jpeg', source = 'camera';
  bool uploading = false;
  String? error;
  _LogPhoto();
  _LogPhoto.saved(Map<String, dynamic> value)
      : id = value['id'] as int?,
        url = value['url'] as String?;
}

class ConstructionLogPage extends StatefulWidget {
  final CheckinProject project;
  final int? logId;
  const ConstructionLogPage({super.key, required this.project, this.logId});
  @override
  State<ConstructionLogPage> createState() => _ConstructionLogPageState();
}

class _ConstructionLogPageState extends State<ConstructionLogPage>
    with WidgetsBindingObserver {
  final _progress = TextEditingController(), _plan = TextEditingController();
  final _photos = <_LogPhoto>[];
  Map<String, dynamic>? _record, _summary;
  String? _error, _summaryError, _date, _draftKey;
  int _version = 0;
  bool _loading = true,
      _saving = false,
      _preparing = false,
      _refreshing = false,
      _dirty = false,
      _canLeave = false;
  Timer? _draftTimer;
  bool get _readOnly =>
      widget.logId != null || _record?['status'] == 'submitted';
  bool get _uploading => _preparing || _photos.any((p) => p.uploading);
  String get _yesterday => DateFormat('yyyy-MM-dd')
      .format(DateTime.parse(_date!).subtract(const Duration(days: 1)));
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progress.addListener(_changed);
    _plan.addListener(_changed);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    _progress.dispose();
    _plan.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) unawaited(_persistLocal());
    if (state == AppLifecycleState.resumed && !_readOnly && _date != null) {
      unawaited(_refreshSummary());
    }
  }

  void _changed() {
    if (_loading || _readOnly) return;
    _dirty = true;
    _draftTimer?.cancel();
    _draftTimer = Timer(
        const Duration(milliseconds: 400), () => unawaited(_persistLocal()));
  }

  Map<String, dynamic> _data() => {
        'logDate': _date,
        'version': _version,
        'progress': _progress.text,
        'plan': _plan.text,
        'photoIds': _photos.where((p) => p.id != null).map((p) => p.id).toList()
      };
  Future<void> _persistLocal() async {
    if (_readOnly || _draftKey == null) return;
    final data = {
      ..._data(),
      'photos': _photos
          .where((p) => p.id != null)
          .map((p) => {'id': p.id, 'url': p.url})
          .toList()
    };
    await (await SharedPreferences.getInstance())
        .setString(_draftKey!, jsonEncode(data));
  }

  Future<void> _load() async {
    try {
      final r = widget.logId == null
          ? await ConstructionLogService.mine(widget.project.id)
          : await ConstructionLogService.detail(widget.logId!);
      if (!r.isSuccess || r.data == null) throw Exception(r.message);
      if (!mounted) return;
      _record = r.data!;
      _date = (_record!['logDate'] ?? _record!['today']) as String;
      _version = (_record!['version'] as num?)?.toInt() ?? 0;
      _progress.text = _record!['progress'] as String? ?? '';
      _plan.text = _record!['plan'] as String? ?? '';
      _photos.addAll((_record!['photos'] as List? ?? [])
          .map((p) => _LogPhoto.saved(Map<String, dynamic>.from(p))));
      _draftKey =
          'construction_draft_${context.read<AuthProvider>().currentUser!.id}_${widget.project.id}_$_date';
      if (!_readOnly) {
        final local =
            (await SharedPreferences.getInstance()).getString(_draftKey!);
        if (local != null) {
          final data = Map<String, dynamic>.from(jsonDecode(local));
          if (data['version'] == _version) {
            _progress.text = data['progress'] as String? ?? '';
            _plan.text = data['plan'] as String? ?? '';
            _photos.clear();
            _photos.addAll((data['photos'] as List? ?? [])
                .map((p) => _LogPhoto.saved(Map<String, dynamic>.from(p))));
            _dirty = true;
            for (final photo in _photos) {
              final fresh = await ConstructionLogService.photoUrl(photo.id!);
              if (fresh.isSuccess) photo.url = fresh.data;
            }
          }
        }
        await _refreshSummary();
      } else {
        _summary =
            Map<String, dynamic>.from(_record!['attendance'] as Map? ?? {});
      }
    } catch (e) {
      _error = '日志加载失败，请重试：${e.toString().replaceFirst('Exception: ', '')}';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshSummary() async {
    if (_refreshing || _date == null) return;
    if (mounted) {
      setState(() {
        _refreshing = true;
        _summaryError = null;
      });
    }
    try {
      final r =
          await ConstructionLogService.summary(widget.project.id, _yesterday);
      if (!r.isSuccess || r.data == null) throw Exception(r.message);
      if (mounted) setState(() => _summary = r.data);
    } catch (_) {
      if (mounted) setState(() => _summaryError = '考勤刷新失败，请重试');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }

  Future<bool> _save({bool submit = false}) async {
    if (_saving || _uploading || _readOnly) return false;
    if (_photos.any((p) => p.id == null)) {
      _message('请重试失败图片，或删除后再保存');
      return false;
    }
    if (submit &&
        (_progress.text.trim().isEmpty ||
            _plan.text.trim().isEmpty ||
            _photos.isEmpty)) {
      _message('请填写施工进度、明日计划，并上传1至6张图片');
      return false;
    }
    if (submit && (_summaryError != null || _refreshing || _summary == null)) {
      _message('请先刷新昨日考勤');
      return false;
    }
    if (submit) {
      final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('提交施工日志？'),
                  content: Text(
                      '提交后不可修改。${(_summary?['pendingCount'] as num? ?? 0) > 0 ? '\n昨日还有${_summary!['pendingCount']}条待处理异常，提交时将保留当前考勤情况。' : ''}'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('继续填写')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('确认提交'))
                  ]));
      if (ok != true || !mounted) return false;
    }
    setState(() => _saving = true);
    await _persistLocal();
    try {
      final r = await ConstructionLogService.save(widget.project.id, _data(),
          submit: submit);
      if (!r.isSuccess || r.data == null) throw Exception(r.message);
      if (!mounted) return false;
      setState(() {
        _record = r.data;
        _version = (_record!['version'] as num).toInt();
        _dirty = false;
      });
      final prefs = await SharedPreferences.getInstance();
      if (submit) {
        _draftTimer?.cancel();
        await prefs.remove(_draftKey!);
        _summary = Map<String, dynamic>.from(_record!['attendance']);
        if (!mounted) return true;
        try {
          await LogReminderService.instance.markSubmitted(
              context.read<AuthProvider>().currentUser!.id,
              widget.project.id,
              _date!);
        } catch (_) {
          /* A reminder error must not report a successful log as failed. */
        }
      } else {
        await _persistLocal();
      }
      _message(submit ? '施工日志已提交' : '草稿已保存');
      return true;
    } catch (e) {
      _message('保存失败，草稿已保留：${e.toString().replaceFirst('Exception: ', '')}');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _handleAnomalies({bool noWork = false}) async {
    if (_uploading || _saving) return;
    if (_dirty && !await _save()) return;
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => noWork
                ? NoWorkRequestsPage(
                    projectId: widget.project.id, date: _yesterday)
                : AnomalyListPage(project: widget.project, date: _yesterday)));
    if (mounted) await _refreshSummary();
  }

  Future<void> _addPhotos(ImageSource source) async {
    if (_photos.length >= 6 || _uploading || _saving) return;
    setState(() => _preparing = true);
    try {
      final picker = ImagePicker();
      final List<XFile> files;
      if (source == ImageSource.camera) {
        final photo = await picker.pickImage(
            source: source, maxWidth: 2200, maxHeight: 2200);
        files = photo == null ? [] : [photo];
      } else {
        files = await picker.pickMultiImage(maxWidth: 2200, maxHeight: 2200);
      }
      if (!mounted) return;
      final remaining = 6 - _photos.length;
      if (files.length > remaining) _message('最多6张，本次仅添加前$remaining张');
      String location = '拍摄位置：未获取';
      if (source == ImageSource.camera && files.isNotEmpty) {
        try {
          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always) {
            final p = await Geolocator.getCurrentPosition(
                locationSettings:
                    const LocationSettings(timeLimit: Duration(seconds: 8)));
            location =
                '拍摄位置：${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
          }
        } catch (_) {
          /* Without a fix, the watermark explicitly says unavailable. */
        }
      }
      if (!mounted) return;
      final user = context.read<AuthProvider>().currentUser!;
      for (final file in files.take(remaining)) {
        if (!mounted) return;
        final now = DateTime.now().toUtc().add(const Duration(hours: 8));
        final photo = _LogPhoto()
          ..source = source == ImageSource.camera ? 'camera' : 'gallery';
        final result =
            await WatermarkUtils.addClockWatermark(await file.readAsBytes(), [
          '施工日志 · ${widget.project.name}',
          '主管：${user.realName ?? user.username}',
          '日志日期：$_date',
          '${source == ImageSource.camera ? '拍摄后记录时间' : '导入时间'}：${DateFormat('yyyy-MM-dd HH:mm:ss').format(now)}',
          source == ImageSource.camera ? location : '来源：相册 · 拍摄时间和位置未核验',
        ]);
        photo.bytes = result.bytes;
        photo.filename = result.filename;
        photo.subtype = result.subtype;
        if (!mounted) return;
        setState(() {
          _photos.add(photo);
          _dirty = true;
        });
        await _upload(photo);
      }
    } catch (_) {
      _message('添加图片失败，请重试');
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _upload(_LogPhoto p) async {
    setState(() {
      p.uploading = true;
      p.error = null;
    });
    try {
      final r = await ConstructionLogService.upload(
          widget.project.id, _date!, p.source, p.bytes!, p.filename, p.subtype);
      if (!r.isSuccess || r.data == null) throw Exception(r.message);
      p.id = r.data!['id'] as int;
      p.url = r.data!['url'] as String;
      await _persistLocal();
    } catch (_) {
      p.error = '上传失败，点击重试';
    } finally {
      if (mounted) setState(() => p.uploading = false);
    }
  }

  Future<void> _leave() async {
    if (_saving || _uploading) {
      _message('请等待保存或图片上传完成');
      return;
    }
    if (!_readOnly && _dirty && !await _save()) {
      if (!mounted) return;
      final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
                  title: const Text('暂时离开？'),
                  content: const Text('未能保存到服务器，已保留本机草稿。当天可重新打开继续填写，跨日后不能提交。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c, false),
                        child: const Text('继续填写')),
                    FilledButton(
                        onPressed: () => Navigator.pop(c, true),
                        child: const Text('离开'))
                  ]));
      if (leave != true) return;
    }
    if (mounted) {
      setState(() => _canLeave = true);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: _canLeave || _readOnly,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_readOnly ? '施工日志详情' : '填写施工日志')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    TextButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                            _loading = true;
                            _photos.clear();
                          });
                          _load();
                        },
                        child: const Text('重试'))
                  ]))
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(
                        _record?['projectName'] as String? ??
                            widget.project.name,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text('$_date  星期${[
                      '一',
                      '二',
                      '三',
                      '四',
                      '五',
                      '六',
                      '日'
                    ][DateTime.parse(_date!).weekday - 1]}'),
                    if (_readOnly)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                              '提交主管：${_record?['supervisorName']}\n提交时间：${_record?['submittedTime']}\n已提交，不可修改')),
                    const SizedBox(height: 16),
                    _summaryCard(),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _progress,
                        readOnly: _readOnly,
                        enabled: !_saving,
                        minLines: 4,
                        maxLines: null,
                        maxLength: _readOnly ? null : 5000,
                        decoration: const InputDecoration(
                            labelText: '今日施工进度',
                            hintText: '填写施工部位、完成情况，可分条描述',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    TextField(
                        controller: _plan,
                        readOnly: _readOnly,
                        enabled: !_saving,
                        minLines: 4,
                        maxLines: null,
                        maxLength: _readOnly ? null : 5000,
                        decoration: const InputDecoration(
                            labelText: '明日施工计划',
                            hintText: '填写明日施工部位、目标和安排',
                            alignLabelWithHint: true,
                            border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    Text('施工图片 ${_photos.length}/6',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (!_readOnly)
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text('至少1张，最多6张；自动加水印，可调整顺序。')),
                    ..._photos
                        .asMap()
                        .entries
                        .map((e) => _photoTile(e.key, e.value)),
                    if (!_readOnly)
                      Wrap(spacing: 12, children: [
                        OutlinedButton.icon(
                            onPressed:
                                _uploading || _saving || _photos.length >= 6
                                    ? null
                                    : () => _addPhotos(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('拍照')),
                        OutlinedButton.icon(
                            onPressed:
                                _uploading || _saving || _photos.length >= 6
                                    ? null
                                    : () => _addPhotos(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('从相册选择')),
                      ]),
                    if (_preparing) const LinearProgressIndicator(),
                    const SizedBox(height: 32),
                  ]),
        bottomNavigationBar: _loading || _error != null || _readOnly
            ? null
            : SafeArea(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(
                          child: OutlinedButton(
                              onPressed:
                                  _saving || _uploading ? null : () => _save(),
                              child: const Text('保存草稿'))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: FilledButton(
                              onPressed: _saving || _uploading
                                  ? null
                                  : () => _save(submit: true),
                              child: Text(_saving ? '保存中…' : '提交日志'))),
                    ]))),
      ));
  Widget _summaryCard() => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text('昨日考勤 · $_yesterday',
                      style: Theme.of(context).textTheme.titleMedium)),
              if (!_readOnly)
                IconButton(
                    onPressed: _refreshing ? null : _refreshSummary,
                    icon: const Icon(Icons.refresh),
                    tooltip: '刷新考勤')
            ]),
            if (_readOnly) const Text('以下为提交时保存的考勤情况'),
            if (_refreshing) const LinearProgressIndicator(),
            if (_summaryError != null)
              Text(_summaryError!, style: const TextStyle(color: Colors.red)),
            if (_summary != null) ...[
              Text(
                  '应出勤 ${_summary!['expectedPeople']} 人 · 实际打卡 ${_summary!['clockedPeople']} 人 · 暂停免卡 ${_summary!['pausedPeople'] ?? 0} 人'),
              Text(
                  '待处理 ${_summary!['pendingPeople']} 人 / ${_summary!['pendingCount']} 条 · 已处理节点 ${_summary!['resolvedCount']} 个'),
              Text('未出工申请待审批 ${_summary!['noWorkPendingPeople'] ?? 0} 人'),
              Text(
                  '工时 ${_summary!['workHours']} 小时 · 加班 ${_summary!['overtimeHours']} 小时 · 工数 ${_summary!['workUnits']}'),
              const Text('人数按人员去重；昨日考勤不代表今日施工人数。',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              if (!_readOnly && (_summary!['pendingCount'] as num? ?? 0) > 0)
                TextButton.icon(
                    onPressed:
                        _saving || _uploading ? null : () => _handleAnomalies(),
                    icon: const Icon(Icons.warning_amber),
                    label: const Text('处理昨日异常')),
              if (!_readOnly &&
                  (_summary!['noWorkPendingPeople'] as num? ?? 0) > 0)
                TextButton.icon(
                    onPressed: _saving || _uploading
                        ? null
                        : () => _handleAnomalies(noWork: true),
                    icon: const Icon(Icons.event_busy_outlined),
                    label: const Text('审批昨日未出工申请')),
            ],
          ])));
  Widget _photoTile(int index, _LogPhoto p) => Card(
      child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            InkWell(
                onTap: p.url == null
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => Scaffold(
                                appBar:
                                    AppBar(title: Text('施工图片 ${index + 1}')),
                                body: ZoomableNetworkImage(url: p.url!)))),
                child: SizedBox(
                    width: 96,
                    height: 80,
                    child: p.bytes != null
                        ? Image.memory(p.bytes!, fit: BoxFit.cover)
                        : Image.network(p.url!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, e, s) =>
                                const Icon(Icons.broken_image_outlined)))),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('图片 ${index + 1}'),
                  if (p.uploading) const LinearProgressIndicator(),
                  if (p.error != null)
                    TextButton(
                        onPressed: _uploading ? null : () => _upload(p),
                        child: Text(p.error!)),
                ])),
            if (!_readOnly) ...[
              IconButton(
                  onPressed: index == 0 || _saving || _uploading
                      ? null
                      : () {
                          setState(() {
                            _photos.removeAt(index);
                            _photos.insert(index - 1, p);
                            _dirty = true;
                          });
                          _persistLocal();
                        },
                  icon: const Icon(Icons.arrow_upward),
                  tooltip: '前移'),
              IconButton(
                  onPressed: _saving || _uploading
                      ? null
                      : () {
                          setState(() {
                            _photos.remove(p);
                            _dirty = true;
                          });
                          _persistLocal();
                        },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '删除图片'),
            ],
          ])));
}
