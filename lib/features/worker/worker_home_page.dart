import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/my_schedule.dart';
import '../../providers/auth_provider.dart';
import '../../services/worker_service.dart';
import '../../core/utils/watermark_utils.dart';
import '../../core/utils/photo_cleanup_stub.dart'
    if (dart.library.io) '../../core/utils/photo_cleanup_io.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:camera/camera.dart';
import 'worker_report_page.dart';
import 'foreman_anomalies_page.dart';
import '../../core/widgets/test_account_switcher.dart';
import '../../core/models/api_result.dart';
import '../../core/widgets/zoomable_network_image.dart';
import '../../core/widgets/user_account_menu.dart';
import '../../core/widgets/dialog_scroll_view.dart';
import 'worker_location_map_page.dart';
import 'package:latlong2/latlong.dart';
import 'clock_camera_page.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_background.dart';

class WorkerHomePage extends StatefulWidget {
  final bool showBack;
  const WorkerHomePage({super.key, this.showBack = false});
  @override
  State<WorkerHomePage> createState() => _WorkerHomePageState();
}

class _WorkerHomePageState extends State<WorkerHomePage>
    with WidgetsBindingObserver {
  Timer? _pauseRefresh;
  @override
  void dispose() {
    _pauseRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPause();
  }

  Future<void> _refreshPause() async {
    if (clocking || loading || !mounted) return;
    try {
      final r = await WorkerService.schedule();
      if (mounted && r.isSuccess && r.data != null) {
        setState(() => schedule = r.data);
      }
    } catch (_) {
      /* Existing data remains available; server still checks every clock. */
    }
  }

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
    WidgetsBinding.instance.addObserver(this);
    _pauseRefresh =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshPause());
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
            leadingWidth: widget.showBack ? 56 : 160,
            leading:
                widget.showBack ? const BackButton() : const UserAccountMenu(),
            title: const Text('今日打卡'),
            actions: [
              IconButton(
                  tooltip: '班组异常原因',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => const ForemanAnomaliesPage())),
                  icon: const Icon(Icons.groups_outlined)),
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
                        Text(value.teamName),
                        Text(
                            '考勤日期 ${value.attendanceDate} · 围栏 ${value.fenceRadius} 米'),
                      ]))),
          const SizedBox(height: 16),
          if (value.fieldWork || value.tomorrowFieldWork)
            Card(
                color: AppColors.soft,
                child: ListTile(
                    leading: const Icon(Icons.badge_outlined,
                        color: AppColors.primary),
                    title: Text(value.fieldWork ? '今日外勤' : '已安排次日外勤'),
                    subtitle: Text(value.fieldWork
                        ? '只需外勤上班、下班，不限制围栏和班次时间。完整有效计1工；缺卡计0工，午夜结算。${value.fieldReason == null ? '' : '\n事由：${value.fieldReason}'}'
                        : '次日按自然日进行外勤上下班打卡'))),
          if (value.pauseStatus != 'active')
            Card(
                child: ListTile(
                    leading: const Icon(Icons.pause_circle_outline),
                    title: Text(
                        value.isPausedAt(DateTime.now()) ? '打卡已暂停' : '打卡时间安排'),
                    subtitle: Text(value.isPausedAt(DateTime.now())
                        ? '可正常登录，暂不能普通或加班打卡。${value.resumeAt == null ? '请联系主管恢复。' : '恢复时间：${value.resumeAt}'}'
                        : '暂停时间：${value.pauseStartAt}'))),
          _locationCard(value),
          const SizedBox(height: 16),
          Text('打卡进度', style: Theme.of(context).textTheme.titleMedium),
          _scheduleProgressCard(value),
          if (value.extraSchedules.isNotEmpty) ...[
            ...value.extraSchedules.map(_scheduleProgressCard),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                  value.secondment
                      ? '按上午、下午分别在对应项目打卡；每个项目只检查分配的时段。'
                      : '附加班次未打卡不会产生缺勤；开始打卡后，不完整班次需要主管确认。',
                  style: const TextStyle(color: Colors.grey)),
            ),
          ],
          const SizedBox(height: 20),
          if (value.fieldWork) ...[
            FilledButton.icon(
                onPressed: clocking ||
                        value.isPausedAt(DateTime.now()) ||
                        value.records
                            .any((r) => r.checkpointCode == 'field_start')
                    ? null
                    : () => _clock(fieldAction: 'start'),
                icon: const Icon(Icons.login),
                label: Text(
                    clocking ? (clockingStatus ?? '正在提交…') : '外勤上班 · 定位拍照')),
            const SizedBox(height: 12),
            OutlinedButton.icon(
                onPressed: clocking ||
                        value.isPausedAt(DateTime.now()) ||
                        !value.records
                            .any((r) => r.checkpointCode == 'field_start') ||
                        value.records
                            .any((r) => r.checkpointCode == 'field_end')
                    ? null
                    : () => _clock(fieldAction: 'end'),
                icon: const Icon(Icons.logout),
                label: const Text('外勤下班 · 定位拍照')),
          ] else
            FilledButton.icon(
                onPressed: clocking || value.isPausedAt(DateTime.now())
                    ? null
                    : _selectAndClock,
                icon: clocking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.camera_alt),
                label:
                    Text(clocking ? (clockingStatus ?? '正在提交…') : '定位并拍照打卡')),
        ]));
  }

  Widget _scheduleProgressCard(MySchedule value) => Card(
        margin: const EdgeInsets.only(top: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                '${value.secondment ? value.secondmentLabel : value.fieldWork ? '自然日考勤' : value.extraShift ? '附加班次' : '标准班次'} · ${value.shiftName}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text(
                '${value.attendanceDate}  ${value.startTime}–${value.shiftType == 'night' ? '次日 ' : ''}${value.endTime} · ${value.records.where((r) => value.checkpoints.any((p) => p.id == r.checkpointId)).length}/${value.checkpoints.length} 次'),
            const SizedBox(height: 8),
            if (value.checkpoints.any(value.isFinalClockOut)) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.more_time,
                          size: 20,
                          color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            const Text('延时下班 · 自动计加班',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                                '最后一次下班请在${value.shiftType == 'night' ? '次日12:00' : '当天24:00'}前打卡。超过标准下班每满30分钟计0.5小时，不满不计。',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text('持续工作到下班时直接打卡，无需另点加班开始。',
                                style: Theme.of(context).textTheme.bodySmall),
                          ])),
                    ]),
              ),
            ],
            ...value.checkpoints.map((point) {
              final matches =
                  value.records.where((r) => r.checkpointId == point.id);
              final record = matches.isEmpty ? null : matches.first;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                    record == null
                        ? Icons.radio_button_unchecked
                        : record.countable
                            ? Icons.check_circle
                            : Icons.warning,
                    color: record == null
                        ? Colors.grey
                        : record.countable
                            ? AppColors.success
                            : AppColors.warning),
                title: Text(point.name),
                subtitle: Text(
                    '标准时间 ${point.expectedTime}${point.dayOffset == 1 ? '（次日）' : ''}\n允许打卡 ${DateFormat('MM-dd HH:mm').format(value.windowStart(point))}–${DateFormat('MM-dd HH:mm').format(value.windowEnd(point))}${value.isFinalClockOut(point) ? '前' : ''}'),
                trailing: Text(record == null
                    ? '未打卡'
                    : record.anomalyType == null
                        ? '已完成'
                        : '异常'),
                onTap: record == null
                    ? null
                    : () => _showClockDetail(point, record),
              );
            }),
            if (!value.fieldWork && value.overtimeAvailable) ...[
              const Divider(height: 24),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: clocking || value.isPausedAt(DateTime.now())
                        ? null
                        : () => _clock(overtime: true, target: value),
                    icon: const Icon(Icons.more_time),
                    label: Text(_overtimeButtonText(value)),
                  )),
              const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '已下班后再次工作：先记录加班开始，结束时再打卡。重叠时间不会重复计算。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )),
            ],
          ]),
        ),
      );

  Future<void> _selectAndClock() async {
    final primary = schedule;
    if (primary == null) return;
    if (primary.extraSchedules.isEmpty) {
      await _clock(target: primary);
      return;
    }
    final selected = await showModalBottomSheet<MySchedule>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('选择打卡班次', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [primary, ...primary.extraSchedules].map((shift) {
                  final completed = shift.checkpoints
                      .where((point) =>
                          shift.records.any((r) => r.checkpointId == point.id))
                      .length;
                  return ListTile(
                    leading: Icon(shift.extraShift
                        ? Icons.add_circle_outline
                        : Icons.schedule),
                    title: Text(
                        '${shift.secondment ? shift.secondmentLabel : shift.extraShift ? '附加班次' : '标准班次'} · ${shift.shiftName}'),
                    subtitle: Text(
                        '${shift.attendanceDate}  ${shift.startTime}–${shift.shiftType == 'night' ? '次日 ' : ''}${shift.endTime}  ·  已打卡 $completed/${shift.checkpoints.length} 次'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(ctx, shift),
                  );
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
    if (!mounted || selected == null) return;
    await _clock(target: selected);
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
                value.fieldWork
                    ? '今日外勤，不受项目围栏限制'
                    : inside
                        ? '当前在项目打卡范围内'
                        : '当前在围栏外，提交会产生异常',
                style: TextStyle(
                    color: value.fieldWork
                        ? AppColors.primary
                        : inside
                            ? AppColors.success
                            : AppColors.warning,
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
    if (count == 0) {
      return value.records.any((r) =>
              r.checkpointCode == 'end' || r.checkpointCode == 'afternoon_out')
          ? '已下班，再次加班'
          : '单独加班 · 记录开始';
    }
    return '加班打卡（更新结束时间）';
  }

  int _overtimeClockCount(MySchedule value) => value.records
      .where((record) => record.checkpointCode.startsWith('overtime_'))
      .length;

  Future<void> _clock(
      {bool overtime = false, MySchedule? target, String? fieldAction}) async {
    await _refreshPause();
    if (!mounted) return;
    if (schedule?.isPausedAt(DateTime.now()) == true) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('打卡已暂停，请联系主管恢复')));
      return;
    }
    final value = schedule!.fieldWork ? schedule! : target ?? schedule!;
    if (fieldAction != null && !value.fieldWork) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('外勤安排已变化，请刷新后打卡')));
      return;
    }
    if (!overtime && !value.canClockAt(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('当前不在允许打卡时段内，请按班次显示的时间打卡。如已漏卡，请联系主管处理。')));
      return;
    }
    final user = context.read<AuthProvider>().currentUser;
    XFile? sourcePhoto;
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
      if (!value.fieldWork && distance > value.fenceRadius) {
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
      final photo = await Navigator.push<XFile>(
          context, MaterialPageRoute(builder: (_) => const ClockCameraPage()));
      if (!mounted || photo == null) return;
      sourcePhoto = photo;
      final now = DateTime.now();
      setState(() => clockingStatus = '正在添加水印…');
      final watermarked = await WatermarkUtils.addClockWatermark(
          await photo.readAsBytes().timeout(const Duration(seconds: 15)), [
        value.fieldWork
            ? fieldAction == 'end'
                ? '外勤下班'
                : '外勤上班'
            : overtime
                ? '加班打卡'
                : '${value.shiftName}打卡',
        value.projectName,
        user?.realName ?? user?.username ?? '',
        DateFormat('yyyy-MM-dd HH:mm:ss').format(now),
        'GPS ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
        'Distance ${distance.round()}m',
      ]);
      if (mounted) {
        setState(() => clockingStatus = '正在上传照片…');
      }
      final uploaded = await WorkerService.uploadPhoto(watermarked.bytes,
          filename: watermarked.filename, subtype: watermarked.subtype);
      if (!uploaded.isSuccess || uploaded.data == null) {
        throw Exception(uploaded.message);
      }
      final payload = {
        if (value.fieldWork) 'fieldAction': fieldAction ?? 'start',
        if (value.fieldWork) 'attendanceDate': value.attendanceDate,
        'shiftId': value.shiftId,
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
      if (sourcePhoto != null) {
        await deleteTemporaryPhoto(sourcePhoto.path);
      }
      if (mounted) {
        setState(() {
          clocking = false;
          clockingStatus = null;
        });
      }
    }
  }
}
