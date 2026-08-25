import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/my_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../services/worker_service.dart';
import '../../core/utils/watermark_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'worker_report_page.dart';
import '../../core/widgets/test_account_switcher.dart';
import '../../core/models/api_result.dart';
import '../../core/config/env_config.dart';

class _TestClockOptions {
  final DateTime clockTime;
  final double offsetMeters;
  const _TestClockOptions(this.clockTime, this.offsetMeters);
}

class WorkerHomePage extends StatefulWidget {
  const WorkerHomePage({super.key});
  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage> {
  MySchedule? schedule;
  String? error;
  bool loading = true;
  bool clocking = false;
  String? clockingStatus;
  Position? previewPosition;
  double? previewDistance;
  String? previewLocationError;
  bool checkingLocation = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await WorkerService.schedule();
      if (!mounted) return;
      setState(() {
        schedule = result.data;
        error = result.isSuccess ? null : result.message;
      });
    } catch (_) {
      if (mounted) setState(() => error = '无法加载当前排班，请检查网络');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('今日打卡'), actions: [
          const TestAccountSwitcher(),
          IconButton(
              tooltip: '月度考勤',
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const WorkerReportPage())),
              icon: const Icon(Icons.assessment)),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(
              onPressed: () => context.read<AuthProvider>().logout(),
              icon: const Icon(Icons.logout))
        ]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(error!, textAlign: TextAlign.center)))
                : _content(),
      );
  Widget _content() {
    final value = schedule!;
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value.projectName,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 8),
                        Text('${value.teamName} · ${value.shiftName}'),
                        Text(
                            '考勤日期 ${value.attendanceDate} · 围栏 ${value.fenceRadius} 米'),
                      ]))),
          const SizedBox(height: 16),
          _locationCard(value),
          const SizedBox(height: 16),
          Text('打卡进度', style: Theme.of(context).textTheme.titleMedium),
          ...value.checkpoints.map((point) {
            final matches =
                value.records.where((r) => r.checkpointId == point.id);
            final record = matches.isEmpty ? null : matches.first;
            return Card(
                child: ListTile(
              leading: Icon(
                  record == null
                      ? Icons.radio_button_unchecked
                      : record.countable
                          ? Icons.check_circle
                          : Icons.warning,
                  color: record == null
                      ? null
                      : record.countable
                          ? Colors.green
                          : Colors.orange),
              title: Text(point.name),
              subtitle: Text(
                  '标准时间 ${point.expectedTime}${point.dayOffset == 1 ? '（次日）' : ''}'),
              trailing: Text(record == null
                  ? '未打卡'
                  : record.anomalyType == null
                      ? '已完成'
                      : '异常'),
              onTap:
                  record == null ? null : () => _showClockDetail(point, record),
            ));
          }),
          const SizedBox(height: 20),
          FilledButton.icon(
              onPressed: clocking ? null : _clock,
              icon: clocking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_alt),
              label: Text(clocking ? (clockingStatus ?? '正在提交…') : '定位并拍照打卡')),
        ]));
  }

  Widget _locationCard(MySchedule value) {
    final position = previewPosition;
    final distance = previewDistance;
    final inside = distance != null && distance <= value.fenceRadius;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(position == null
                ? Icons.location_searching
                : inside
                    ? Icons.location_on
                    : Icons.location_off),
            const SizedBox(width: 8),
            Expanded(
                child: Text('现场定位',
                    style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(
                onPressed: checkingLocation ? null : _checkLocation,
                icon: checkingLocation
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh),
                label: Text(position == null ? '检查定位' : '刷新')),
          ]),
          if (previewLocationError != null)
            Text(previewLocationError!,
                style: const TextStyle(color: Colors.red))
          else if (position == null)
            const Text('打卡前可先检查定位精度和项目距离')
          else ...[
            Text('定位精度：约 ±${position.accuracy.toStringAsFixed(0)} 米'),
            Text('距项目中心：约 ${distance!.round()} 米'),
            const SizedBox(height: 4),
            Text(
              inside ? '当前在项目打卡范围内' : '当前在围栏外，提交会产生异常',
              style: TextStyle(
                  color: inside ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ]),
      ),
    );
  }

  Future<void> _checkLocation() async {
    setState(() {
      checkingLocation = true;
      previewLocationError = null;
    });
    try {
      final position = await _getHighAccuracyPosition();
      final value = schedule!;
      final distance = Geolocator.distanceBetween(
          position.latitude, position.longitude, value.gpsLat, value.gpsLng);
      if (mounted) {
        setState(() {
          previewPosition = position;
          previewDistance = distance;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => previewLocationError =
            error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => checkingLocation = false);
    }
  }

  Future<void> _showClockDetail(
      ScheduleCheckpoint checkpoint, ClockStatus record) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(checkpoint.name),
        content: SingleChildScrollView(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('服务器时间：${record.serverTime}'),
            Text(
                '状态：${record.anomalyType == null ? '正常' : '异常（${record.anomalyType}）'}'),
            if (record.gpsAccuracy != null)
              Text('定位精度：约 ±${record.gpsAccuracy!.toStringAsFixed(0)} 米'),
            if (record.distanceMeters != null)
              Text('距项目中心：约 ${record.distanceMeters!.round()} 米'),
            if (record.hasPhoto) ...[
              const SizedBox(height: 12),
              FutureBuilder<ApiResult<String>>(
                future: WorkerService.clockPhotoViewUrl(record.id),
                builder: (_, snapshot) {
                  final url = snapshot.data?.data;
                  if (url == null) {
                    return const SizedBox(
                        height: 160,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                            height: 100, child: Center(child: Text('照片加载失败')))),
                  );
                },
              ),
            ],
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))
        ],
      ),
    );
  }

  Future<Position> _getHighAccuracyPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('请先打开手机定位服务');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('需要定位权限才能打卡');
    }
    return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 15)));
  }

  Future<void> _clock() async {
    final value = schedule!;
    final user = context.read<AuthProvider>().currentUser;
    String? sourcePhotoPath;
    String? watermarkedPhotoPath;
    try {
      final testOptions = EnvConfig.instance.showTestFeatures
          ? await _showTestClockOptions()
          : null;
      if (EnvConfig.instance.showTestFeatures && testOptions == null) return;
      setState(() {
        clocking = true;
        clockingStatus =
            testOptions == null ? '正在定位…' : '正在生成测试定位…';
      });
      final position =
          testOptions == null ? await _getHighAccuracyPosition() : null;
      final latitude = testOptions == null
          ? position!.latitude
          : value.gpsLat + testOptions.offsetMeters / 111320.0;
      final longitude = testOptions == null ? position!.longitude : value.gpsLng;
      final accuracy = testOptions == null ? position!.accuracy : 0.0;
      final distance = Geolocator.distanceBetween(
          latitude, longitude, value.gpsLat, value.gpsLng);
      if (mounted && position != null) {
        setState(() {
          previewPosition = position;
          previewDistance = distance;
        });
      }
      if (!mounted) return;
      if (distance > value.fenceRadius) {
        final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    icon: const Icon(Icons.warning_amber,
                        color: Colors.orange, size: 42),
                    title: const Text('当前在项目围栏外'),
                    content: Text(
                        '距离项目约 ${distance.round()} 米，允许范围 ${value.fenceRadius} 米。\n\n继续打卡会标记为异常，不计入工时，需要项目主管确认或修正。'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('取消')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('仍要打卡'))
                    ]));
        if (proceed != true) return;
      }
      final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 88,
          maxWidth: 1920,
          requestFullMetadata: false);
      if (photo == null) return;
      sourcePhotoPath = photo.path;
      final now = testOptions?.clockTime ?? DateTime.now();
      setState(() => clockingStatus = '正在添加水印…');
      final path =
          await WatermarkUtils.addClockWatermark(await photo.readAsBytes(), [
        value.projectName,
        user?.realName ?? user?.username ?? '',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        'GPS ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
        'Distance ${distance.round()}m',
      ]);
      watermarkedPhotoPath = path;
      await _deleteTemporaryFile(sourcePhotoPath);
      sourcePhotoPath = null;
      if (mounted) setState(() => clockingStatus = '正在上传照片…');
      final uploaded = await WorkerService.uploadPhoto(path);
      if (!uploaded.isSuccess || uploaded.data == null) {
        throw Exception(uploaded.message);
      }
      final result = await WorkerService.clock({
        'requestId': '${now.microsecondsSinceEpoch}-${user?.id ?? 0}',
        'gpsLat': latitude,
        'gpsLng': longitude,
        'gpsAccuracy': accuracy,
        'clientTime': now.toIso8601String(),
        'photoUrl': uploaded.data
      });
      if (!result.isSuccess) {
        throw Exception(result.message);
      }
      await _deleteTemporaryFile(watermarkedPhotoPath);
      watermarkedPhotoPath = null;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.data?['anomalyType'] == null
                ? '打卡成功'
                : '打卡已记录，存在异常，等待主管处理')));
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            backgroundColor: Colors.red));
      }
    } finally {
      await _deleteTemporaryFile(sourcePhotoPath);
      if (watermarkedPhotoPath != null) {
        await _deleteTemporaryFile(watermarkedPhotoPath);
      }
      if (mounted) {
        setState(() {
          clocking = false;
          clockingStatus = null;
        });
      }
    }
  }

  Future<_TestClockOptions?> _showTestClockOptions() async {
    var selected = DateTime.now();
    final offsetController = TextEditingController(text: '0');
    final result = await showDialog<_TestClockOptions>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDialogState) {
        Future<void> chooseTime() async {
          final date = await showDatePicker(
              context: ctx,
              initialDate: selected,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035));
          if (date == null || !ctx.mounted) return;
          final time = await showTimePicker(
              context: ctx, initialTime: TimeOfDay.fromDateTime(selected));
          if (time == null) return;
          setDialogState(() => selected = DateTime(
              date.year, date.month, date.day, time.hour, time.minute));
        }

        return AlertDialog(
          title: const Text('测试打卡参数'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('模拟打卡时间'),
              subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(selected)),
              trailing: const Icon(Icons.edit_calendar),
              onTap: chooseTime,
            ),
            TextField(
              controller: offsetController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '距项目中心的偏移距离（米）',
                helperText: '以项目中心向北计算测试坐标，0 表示项目中心',
                suffixText: '米',
              ),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                final offset = double.tryParse(offsetController.text.trim());
                if (offset == null || offset < 0 || offset > 100000) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('请输入 0～100000 米的有效距离')));
                  return;
                }
                Navigator.pop(ctx, _TestClockOptions(selected, offset));
              },
              child: const Text('确定并拍照'),
            ),
          ],
        );
      }),
    );
    offsetController.dispose();
    return result;
  }

  Future<void> _deleteTemporaryFile(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
