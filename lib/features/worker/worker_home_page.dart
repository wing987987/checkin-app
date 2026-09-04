import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/my_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../services/worker_service.dart';
import '../../core/utils/watermark_utils.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'worker_report_page.dart';
import '../../core/widgets/test_account_switcher.dart';
import '../../core/models/api_result.dart';
import '../../core/config/env_config.dart';
import '../../core/widgets/zoomable_network_image.dart';
import '../../core/widgets/user_account_menu.dart';
import '../../core/widgets/dialog_scroll_view.dart';
import 'worker_location_map_page.dart';
import 'package:latlong2/latlong.dart';
import 'clock_camera_page.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_background.dart';

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
        appBar: AppBar(
            leadingWidth: 160,
            leading: const UserAccountMenu(),
            title: const Text('今日打卡'),
            actions: [
              const TestAccountSwitcher(),
              IconButton(
                  tooltip: '考勤统计',
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WorkerReportPage())),
                  icon: const Icon(Icons.assessment)),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ]),
        body: AppBackground(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                    ? AppEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: '排班加载失败',
                        description: error!,
                        onRetry: _load,
                      )
                    : _content()),
      );
  Widget _content() {
    final value = schedule!;
    return RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
              margin: EdgeInsets.zero,
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: AppColors.soft,
                                borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.apartment_outlined,
                                color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Text(value.projectName,
                                  style:
                                      Theme.of(context).textTheme.titleLarge)),
                        ]),
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
                      ? AppColors.textTertiary
                      : record.countable
                          ? AppColors.success
                          : AppColors.warning),
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
              onPressed: clocking ? null : () => _clock(),
              icon: clocking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.camera_alt),
              label: Text(clocking ? (clockingStatus ?? '正在提交…') : '定位并拍照打卡')),
          if (EnvConfig.instance.showTestFeatures ||
              value.overtimeAvailable) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: clocking ? null : () => _clock(overtime: true),
              icon: const Icon(Icons.more_time),
              label: Text(_overtimeButtonText(value)),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('首次为加班开始，后续每次打卡都会更新加班结束时间',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ]));
  }

  Widget _locationCard(MySchedule value) {
    final position = previewPosition;
    final distance = previewDistance;
    final inside = distance != null && distance <= value.fenceRadius;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: checkingLocation ? null : _openLocationMap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                    color: inside ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Future<void> _openLocationMap() async {
    await _checkLocation();
    if (!mounted || previewPosition == null || previewDistance == null) return;
    final value = schedule!;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerLocationMapPage(
          current:
              LatLng(previewPosition!.latitude, previewPosition!.longitude),
          target: LatLng(value.gpsLat, value.gpsLng),
          distanceMeters: previewDistance!,
          accuracyMeters: previewPosition!.accuracy,
          fenceRadius: value.fenceRadius,
          projectName: value.projectName,
        ),
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
        content: DialogScrollView(
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
                  return ZoomableNetworkImage(url: url);
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
        locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            forceLocationManager: true,
            timeLimit: Duration(seconds: 15)));
  }

  String _overtimeButtonText(MySchedule value) {
    final count = _overtimeClockCount(value);
    if (count == 0) return '加班打卡（开始）';
    return '加班打卡（更新结束时间）';
  }

  int _overtimeClockCount(MySchedule value) => value.records
      .where((record) => record.checkpointCode.startsWith('overtime_'))
      .length;

  Future<void> _clock({bool overtime = false}) async {
    final value = schedule!;
    final user = context.read<AuthProvider>().currentUser;
    String? sourcePhotoPath;
    String? watermarkedPhotoPath;
    try {
      setState(() {
        clocking = true;
        clockingStatus = '正在定位…';
      });
      final position = await _getHighAccuracyPosition();
      final latitude = position.latitude;
      final longitude = position.longitude;
      final accuracy = position.accuracy;
      final distance = Geolocator.distanceBetween(
          latitude, longitude, value.gpsLat, value.gpsLng);
      if (mounted) {
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
      if (!mounted) return;
      final photoPath = await Navigator.push<String>(
          context, MaterialPageRoute(builder: (_) => const ClockCameraPage()));
      if (!mounted || photoPath == null) return;
      sourcePhotoPath = photoPath;
      final now = DateTime.now();
      setState(() => clockingStatus = '正在添加水印…');
      final watermarked = await WatermarkUtils.addClockWatermark(
          await File(photoPath).readAsBytes(), [
        overtime ? '加班打卡' : '班次打卡',
        value.projectName,
        user?.realName ?? user?.username ?? '',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        'GPS ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
        'Distance ${distance.round()}m',
      ]);
      watermarkedPhotoPath = watermarked.path;
      await _deleteTemporaryFile(sourcePhotoPath);
      sourcePhotoPath = null;
      if (mounted) {
        setState(() =>
            clockingStatus = '照片已压缩 ${watermarked.reductionPercent}%，正在上传…');
      }
      final uploaded = await WorkerService.uploadPhoto(watermarked.path);
      if (!uploaded.isSuccess || uploaded.data == null) {
        throw Exception(uploaded.message);
      }
      final payload = {
        'requestId': '${now.microsecondsSinceEpoch}-${user?.id ?? 0}',
        'gpsLat': latitude,
        'gpsLng': longitude,
        'gpsAccuracy': accuracy,
        'clientTime': now.toIso8601String(),
        'photoUrl': uploaded.data
      };
      final result = overtime
          ? await WorkerService.overtimeClock(payload)
          : await WorkerService.clock(payload);
      if (!result.isSuccess) {
        throw Exception(result.message);
      }
      await _deleteTemporaryFile(watermarkedPhotoPath);
      watermarkedPhotoPath = null;
      if (mounted) {
        final anomalyType = result.data?['anomalyType']?.toString() ?? '';
        final anomalyMessage = result.data?['anomalyMessage']?.toString();
        if (!overtime && anomalyType.split(',').contains('time_window')) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 42),
              title: const Text('打卡成功，时间异常'),
              content: Text(
                '${anomalyMessage ?? '本次打卡不在规定时间范围内'}。\n\n'
                '该记录暂不计入工时，请联系主管核对。',
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('我知道了'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(anomalyType.isEmpty
                  ? overtime
                      ? '加班打卡成功'
                      : '打卡成功'
                  : '打卡已记录，存在异常，等待主管处理')));
        }
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

  Future<void> _deleteTemporaryFile(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
