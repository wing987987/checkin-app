import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_report.dart';
import '../../models/checkin_project.dart';
import '../../core/widgets/zoomable_network_image.dart';
import '../../services/management_service.dart';
import '../../core/theme/app_theme.dart';

enum _ProjectReportMode { day, month }

class ProjectReportPage extends StatefulWidget {
  final CheckinProject project;
  const ProjectReportPage({super.key, required this.project});
  @override
  State<ProjectReportPage> createState() => _ProjectReportPageState();
}

class _ProjectReportPageState extends State<ProjectReportPage> {
  static const _blue = Color(0xFF165DFF);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  _ProjectReportMode mode = _ProjectReportMode.month;
  ProjectMonthReport? report;
  bool loading = true;
  String? error;

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
      final result = await ManagementService.projectMonthReport(
          widget.project.id, DateFormat('yyyy-MM').format(month));
      if (!mounted) return;
      setState(() {
        report = result.data;
        error = result.isSuccess ? null : result.message;
      });
    } catch (_) {
      if (mounted) setState(() => error = '考勤报表加载失败');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _moveMonth(int value) {
    final next = DateTime(month.year, month.month + value);
    setState(() {
      month = next;
      selectedDate = DateTime(next.year, next.month, 1);
    });
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF8F8FA),
        appBar: AppBar(
          title: Column(children: [
            const Text('项目考勤报表', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(widget.project.name,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal)),
          ]),
          centerTitle: true,
        ),
        body: Column(children: [
          _header(),
          Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(error!))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: mode == _ProjectReportMode.day
                              ? _dayView()
                              : _monthView())),
        ]),
      );

  Widget _header() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(children: [
          Row(children: [
            Text('${month.year}年',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                  color: AppColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10)),
              child: SegmentedButton<_ProjectReportMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: _ProjectReportMode.day, label: Text('日报')),
                  ButtonSegment(
                      value: _ProjectReportMode.month, label: Text('月报')),
                ],
                selected: {mode},
                onSelectionChanged: (value) =>
                    setState(() => mode = value.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? AppColors.primary
                          : AppColors.textSecondary),
                  backgroundColor: WidgetStateProperty.resolveWith((states) =>
                      states.contains(WidgetState.selected)
                          ? Colors.white
                          : Colors.transparent),
                  side: const WidgetStatePropertyAll(BorderSide.none),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _monthButton(Icons.chevron_left, () => _moveMonth(-1)),
            Text('${month.month}月',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            _monthButton(Icons.chevron_right, () => _moveMonth(1)),
          ]),
        ]),
      );

  Widget _monthButton(IconData icon, VoidCallback action) => IconButton(
        onPressed: action,
        icon: Icon(icon, size: 22),
        style: IconButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: AppColors.soft,
          minimumSize: const Size(44, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  Widget _dayView() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _calendar(),
          const SizedBox(height: 12),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _daySummary()),
          const SizedBox(height: 24),
        ],
      );

  Widget _calendar() {
    final first = DateTime(month.year, month.month, 1);
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = first.weekday % 7;
    final cells = ((leading + count) / 7).ceil() * 7;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(children: [
        const Row(children: [
          Expanded(child: Center(child: Text('日'))),
          Expanded(child: Center(child: Text('一'))),
          Expanded(child: Center(child: Text('二'))),
          Expanded(child: Center(child: Text('三'))),
          Expanded(child: Center(child: Text('四'))),
          Expanded(child: Center(child: Text('五'))),
          Expanded(child: Center(child: Text('六'))),
        ]),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: .9),
          itemBuilder: (_, index) {
            final value = index - leading + 1;
            if (value < 1 || value > count) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, value);
            final selected = DateUtils.isSameDay(date, selectedDate);
            final days = _daysFor(date);
            final hasAnomaly = days.any((day) => day.status != 'normal');
            return InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => setState(() => selectedDate = date),
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? _blue : null),
                      child: Text('$value',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : Colors.black87)),
                    ),
                    Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: days.isEmpty
                                ? Colors.transparent
                                : hasAnomaly
                                    ? Colors.redAccent
                                    : _blue)),
                  ]),
            );
          },
        ),
      ]),
    );
  }

  Widget _daySummary() {
    final days = _daysFor(selectedDate);
    if (days.isEmpty) {
      return _surface(
          child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: Text('该日暂无项目考勤记录'))));
    }
    final normal = days.where((day) => day.status == 'normal').length;
    final abnormal = days.length - normal;
    return Column(children: [
      _surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${DateFormat('M月d日').format(selectedDate)} 上下班打卡',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 18),
        SizedBox(
            height: 145,
            child: _AttendanceGauge(normal: normal, abnormal: abnormal)),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _metric('$normal', '正常人数', _blue),
          _metric('$abnormal', '异常人数',
              abnormal > 0 ? Colors.redAccent : Colors.grey),
          _metric('${days.where((day) => day.status == 'missing').length}',
              '缺卡', Colors.orange),
          _metric('${days.where((day) => day.overtimeHours > 0).length}', '加班',
              Colors.black87),
        ]),
      ])),
      const SizedBox(height: 12),
      ...days.map(_workerDayCard),
    ]);
  }

  Widget _workerDayCard(DailyAttendance day) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _surface(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              leading: CircleAvatar(
                  child: Text(day.workerName.isEmpty
                      ? '?'
                      : day.workerName.substring(0, 1))),
              title: Text(day.workerName,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                  '${day.teamName} · ${day.shiftName}\n工时 ${_hours(day.workHours)} · 加班 ${_hours(day.overtimeHours)}'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                _statusTag(day.status == 'normal',
                    day.status == 'normal' ? '正常' : '异常'),
                const SizedBox(width: 4),
                const Icon(Icons.expand_more, color: AppColors.textTertiary),
              ]),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                ...day.clocks.map((clock) => ListTile(
                      dense: true,
                      leading: Icon(
                          clock.status == 'missing'
                              ? Icons.cancel_outlined
                              : clock.countable
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                          color: clock.status == 'missing' || !clock.countable
                              ? Colors.orange
                              : _blue),
                      title: Row(children: [
                        Flexible(child: Text(clock.checkpointName)),
                        if (clock.adjustmentAction.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: .1),
                                borderRadius: BorderRadius.circular(10)),
                            child: Text(
                                _adjustmentLabel(clock.adjustmentAction),
                                style: const TextStyle(
                                    color: Colors.indigo, fontSize: 12)),
                          ),
                        ],
                      ]),
                      subtitle: clock.correctionReason.isEmpty
                          ? null
                          : Text('原因：${clock.correctionReason}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (clock.status == 'missing' &&
                            clock.checkpointId != null)
                          TextButton.icon(
                              onPressed: () => _supplementMissing(day, clock),
                              icon: const Icon(Icons.add_task_outlined),
                              label: const Text('补卡')),
                        if (clock.hasPhoto && clock.recordId != null)
                          IconButton(
                              tooltip: '查看打卡照片',
                              onPressed: () => _showClockPhoto(day, clock),
                              icon: const Icon(Icons.photo_camera_outlined,
                                  color: _blue)),
                        if (clock.status != 'missing')
                          Text(_time(clock.clockTime)),
                      ]),
                    )),
                Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                        onPressed: () => _chooseSupplement(day),
                        icon: const Icon(Icons.add_task_outlined),
                        label: const Text('人工补打卡'))),
              ],
            )),
      );

  Future<void> _showClockPhoto(
      DailyAttendance day, AttendanceClockDetail clock) async {
    final recordId = clock.recordId;
    if (recordId == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${day.workerName} · ${clock.checkpointName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder(
            future: ManagementService.anomalyPhotoViewUrl(recordId),
            builder: (_, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                    height: 240,
                    child: Center(child: CircularProgressIndicator()));
              }
              final result = snapshot.data;
              final url = result?.data;
              if (url == null || url.isEmpty) {
                return SizedBox(
                    height: 120,
                    child: Center(child: Text(result?.message ?? '照片加载失败')));
              }
              return ZoomableNetworkImage(url: url);
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))
        ],
      ),
    );
  }

  Future<void> _supplementMissing(
      DailyAttendance day, AttendanceClockDetail clock) async {
    final checkpointId = clock.checkpointId;
    if (checkpointId == null) return;
    final attendanceDate = DateTime.tryParse(day.date);
    final timeParts = clock.expectedTime.split(':');
    if (attendanceDate == null || timeParts.length < 2) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('标准打卡时间无效，无法补卡')));
      return;
    }
    var clockTime = DateTime(
      attendanceDate.year,
      attendanceDate.month,
      attendanceDate.day + clock.expectedDayOffset,
      int.tryParse(timeParts[0]) ?? 0,
      int.tryParse(timeParts[1]) ?? 0,
    );
    final reason = TextEditingController();
    final reasonFocus = FocusNode();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: Text('${day.workerName} · ${clock.checkpointName}补卡'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('补卡时间'),
              subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(clockTime)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final date = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDate: clockTime.isAfter(DateTime.now())
                        ? DateTime.now()
                        : clockTime);
                if (date == null || !ctx.mounted) return;
                final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(clockTime));
                if (time != null) {
                  setLocal(() => clockTime = DateTime(
                      date.year, date.month, date.day, time.hour, time.minute));
                }
              },
            ),
            TextField(
              controller: reason,
              focusNode: reasonFocus,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '请输入补卡原因（必填）'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (reason.text.trim().isEmpty) {
                  reasonFocus.requestFocus();
                  return;
                }
                final result = await ManagementService.supplementClock({
                  'workerId': day.workerId,
                  'projectId': day.projectId,
                  'teamId': day.teamId,
                  'shiftId': day.shiftId,
                  'checkpointId': checkpointId,
                  'attendanceDate': day.date,
                  'clockTime': clockTime.toIso8601String(),
                  'reason': reason.text.trim(),
                });
                if (!ctx.mounted) return;
                if (result.isSuccess) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(result.message)));
                }
              },
              child: const Text('确认补卡'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    reasonFocus.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('补卡成功')));
      await _load();
    }
  }

  Future<void> _chooseSupplement(DailyAttendance day) async {
    final missing = day.clocks
        .where(
            (clock) => clock.status == 'missing' && clock.checkpointId != null)
        .toList();
    final selected = await showDialog<Object>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('选择补打卡类型'),
        children: [
          ...missing.map((clock) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, clock),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.add_task_outlined),
                  title: Text(clock.checkpointName),
                  subtitle: Text(
                      '标准时间 ${clock.expectedDayOffset > 0 ? '次日 ' : ''}${clock.expectedTime}'),
                ),
              )),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'overtime'),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.more_time_outlined),
              title: Text('补加班打卡'),
              subtitle: Text('第一次为加班开始，后续打卡刷新加班结束'),
            ),
          ),
        ],
      ),
    );
    if (selected is AttendanceClockDetail && mounted) {
      await _supplementMissing(day, selected);
    } else if (selected == 'overtime' && mounted) {
      await _supplementOvertime(day);
    }
  }

  Future<void> _supplementOvertime(DailyAttendance day) async {
    final overtime = day.clocks
        .where((clock) =>
            clock.recordId != null && clock.checkpointName.startsWith('加班'))
        .toList();
    final recordedTimes = day.clocks
        .map((clock) => DateTime.tryParse(clock.clockTime))
        .whereType<DateTime>()
        .toList()
      ..sort();
    final overtimeTimes = overtime
        .map((clock) => DateTime.tryParse(clock.clockTime))
        .whereType<DateTime>()
        .toList()
      ..sort();
    final attendanceDate = DateTime.tryParse(day.date) ?? DateTime.now();
    final expectedTimes = day.clocks
        .map((clock) {
          final parts = clock.expectedTime.split(':');
          if (parts.length < 2) return null;
          return DateTime(
              attendanceDate.year,
              attendanceDate.month,
              attendanceDate.day + clock.expectedDayOffset,
              int.tryParse(parts[0]) ?? 0,
              int.tryParse(parts[1]) ?? 0);
        })
        .whereType<DateTime>()
        .toList()
      ..sort();
    var clockTime = overtime.isNotEmpty && recordedTimes.isNotEmpty
        ? recordedTimes.last.add(const Duration(hours: 1))
        : expectedTimes.isNotEmpty
            ? expectedTimes.last.add(const Duration(minutes: 30))
            : DateTime(attendanceDate.year, attendanceDate.month,
                attendanceDate.day, 18);
    final shiftEnd = expectedTimes.isNotEmpty
        ? expectedTimes.last
        : DateTime(attendanceDate.year, attendanceDate.month,
            attendanceDate.day, 17, 30);
    final firstExpected = expectedTimes.isNotEmpty
        ? expectedTimes.first
        : DateTime(attendanceDate.year, attendanceDate.month,
            attendanceDate.day, 6, 30);
    final nextShiftStart = DateTime(attendanceDate.year, attendanceDate.month,
        attendanceDate.day + 1, firstExpected.hour, firstExpected.minute);
    if (!clockTime.isAfter(shiftEnd) || !clockTime.isBefore(nextShiftStart)) {
      clockTime = shiftEnd.add(const Duration(minutes: 30));
    }
    var selectedDayOffset = DateUtils.isSameDay(
            clockTime, attendanceDate.add(const Duration(days: 1)))
        ? 1
        : 0;
    final label = overtime.isEmpty ? '加班开始' : '加班结束';
    final reason = TextEditingController();
    final reasonFocus = FocusNode();
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (_, setLocal) => AlertDialog(
          title: Text('${day.workerName} · 补$label打卡'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Align(
                alignment: Alignment.centerLeft, child: Text('选择加班发生日期')),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('当日')),
                  ButtonSegment(value: 1, label: Text('次日')),
                ],
                selected: {selectedDayOffset},
                onSelectionChanged: (value) => setLocal(() {
                  selectedDayOffset = value.first;
                  clockTime = DateTime(
                      attendanceDate.year,
                      attendanceDate.month,
                      attendanceDate.day + selectedDayOffset,
                      clockTime.hour,
                      clockTime.minute);
                }),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('$label时间'),
              subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(clockTime)),
              trailing: const Icon(Icons.access_time_outlined),
              onTap: () async {
                final time = await showTimePicker(
                    context: ctx,
                    initialTime: TimeOfDay.fromDateTime(clockTime));
                if (time != null) {
                  setLocal(() => clockTime = DateTime(
                      attendanceDate.year,
                      attendanceDate.month,
                      attendanceDate.day + selectedDayOffset,
                      time.hour,
                      time.minute));
                }
              },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '允许范围：${DateFormat('MM-dd HH:mm').format(shiftEnd)}之后，${DateFormat('MM-dd HH:mm').format(nextShiftStart)}之前',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reason,
              focusNode: reasonFocus,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(hintText: '请输入补加班卡原因（必填）'),
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                if (reason.text.trim().isEmpty) {
                  reasonFocus.requestFocus();
                  return;
                }
                if (!clockTime.isAfter(shiftEnd) ||
                    !clockTime.isBefore(nextShiftStart)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(
                          '补加班时间必须晚于 ${DateFormat('MM-dd HH:mm').format(shiftEnd)}，并早于 ${DateFormat('MM-dd HH:mm').format(nextShiftStart)}')));
                  return;
                }
                if (overtimeTimes.isNotEmpty &&
                    !clockTime.isAfter(overtimeTimes.last)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                      content: Text(
                          '加班结束时间必须晚于已有打卡 ${DateFormat('MM-dd HH:mm').format(overtimeTimes.last)}')));
                  return;
                }
                final result = await ManagementService.supplementOvertime({
                  'workerId': day.workerId,
                  'projectId': day.projectId,
                  'teamId': day.teamId,
                  'shiftId': day.shiftId,
                  'attendanceDate': day.date,
                  'clockTime': clockTime.toIso8601String(),
                  'reason': reason.text.trim(),
                });
                if (!ctx.mounted) return;
                if (result.isSuccess) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(result.message)));
                }
              },
              child: const Text('确认补卡'),
            ),
          ],
        ),
      ),
    );
    reason.dispose();
    reasonFocus.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('补加班卡成功')));
      await _load();
    }
  }

  Widget _monthView() {
    final value = report!;
    final normal = value.days.where((day) => day.status == 'normal').length;
    final abnormal = value.days.length - normal;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _surface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('月度考勤汇总',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
              height: 145,
              child: _AttendanceGauge(normal: normal, abnormal: abnormal)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _metric('$normal', '正常人次', _blue),
            _metric('$abnormal', '异常人次',
                abnormal > 0 ? Colors.redAccent : Colors.grey),
            _metric(_hours(value.totalWorkHours + value.totalOvertimeHours), '总工时', Colors.black87),
          ]),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _metric(
                value.totalWorkUnits.toStringAsFixed(2), '总工数', Colors.black87),
            _metric(_hours(value.totalOvertimeHours), '其中加班', Colors.black87),
            _metric('${value.workers.length}', '考勤人数', Colors.black87),
          ]),
        ])),
        const SizedBox(height: 14),
        if (value.workers.isEmpty)
          _surface(
              child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('本月暂无考勤'))))
        else ...[
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text('按工种查看工时',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          ...value.workersByJobType.entries.map((entry) {
            final workers = entry.value;
            final hours = workers.fold<double>(0, (sum, worker) => sum + worker.workHours);
            final overtime = workers.fold<double>(0, (sum, worker) => sum + worker.overtimeHours);
            return Card(
              child: ExpansionTile(
                title: Text(entry.key),
                subtitle: Text('${workers.length}人 · 总工时 ${_hours(hours + overtime)}（加班 ${_hours(overtime)}）'),
                children: workers.map((worker) => ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(worker.workerName),
                  subtitle: Text('${worker.teamName} · 出勤 ${worker.attendanceDays}天 · 总工时 ${_hours(worker.workHours + worker.overtimeHours)}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showWorkerMonthDays(worker, value.days),
                )).toList(),
              ),
            );
          }),
        ],
      ],
    );
  }

  void _showWorkerMonthDays(ProjectWorkerReport worker, List<DailyAttendance> allDays) {
    final days = allDays.where((day) => day.workerId == worker.workerId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          child: Column(children: [
            ListTile(
              title: Text('${worker.workerName} · 月度工时'),
              subtitle: Text('总工时 ${_hours(worker.workHours + worker.overtimeHours)} · 其中加班 ${_hours(worker.overtimeHours)}'),
            ),
            Expanded(child: ListView.builder(
              itemCount: days.length,
              itemBuilder: (_, index) {
                final day = days[index];
                return ListTile(
                  title: Text(day.date),
                  subtitle: Text('${day.teamName} · ${day.shiftName} · 加班 ${_hours(day.overtimeHours)}\n${day.statusMessage}'),
                  trailing: Text(_hours(day.workHours + day.overtimeHours)),
                );
              },
            )),
          ]),
        ),
      ),
    );
  }

  List<DailyAttendance> _daysFor(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return report?.days.where((day) => day.date == key).toList() ?? const [];
  }

  Widget _metric(String value, String label, Color color) => Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(TextSpan(children: _metricSpans(value, color))),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ]);

  List<InlineSpan> _metricSpans(String value, Color color) {
    final spans = <InlineSpan>[];
    final unitPattern = RegExp(r'(小时|分钟)');
    var start = 0;
    for (final match in unitPattern.allMatches(value)) {
      if (match.start > start) {
        spans.add(TextSpan(
          text: value.substring(start, match.start),
          style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.w700),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500),
      ));
      start = match.end;
    }
    if (start < value.length) {
      spans.add(TextSpan(
        text: value.substring(start),
        style:
            TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w700),
      ));
    }
    return spans;
  }

  Widget _statusTag(bool normal, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: normal ? const Color(0xFFE6FFEA) : const Color(0xFFFFECEC),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label,
            style: TextStyle(
                color: normal ? AppColors.success : AppColors.danger,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      );

  Widget _surface({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: child,
      );

  String _time(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null ? value : DateFormat('HH:mm').format(parsed);
  }

  String _hours(double value) {
    final hours = value.floor();
    final minutes = ((value - hours) * 60).round();
    return minutes == 0 ? '$hours小时' : '$hours小时$minutes分钟';
  }

  String _adjustmentLabel(String action) =>
      const {
        'supplement': '主管补卡',
        'correct': '时间调整',
        'confirm': '确认有效',
        'void': '历史误打',
      }[action] ??
      action;
}

class _AttendanceGauge extends StatelessWidget {
  final int normal;
  final int abnormal;
  const _AttendanceGauge({required this.normal, required this.abnormal});

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _GaugePainter(normal: normal, abnormal: abnormal),
        child: Center(
            child: Padding(
          padding: const EdgeInsets.only(top: 45),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('正常 $normal',
                style: const TextStyle(color: Color(0xFF165DFF), fontSize: 18)),
            Text('异常 $abnormal',
                style: TextStyle(
                    color: abnormal > 0 ? Colors.redAccent : Colors.grey,
                    fontSize: 16)),
          ]),
        )),
      );
}

class _GaugePainter extends CustomPainter {
  final int normal;
  final int abnormal;
  const _GaugePainter({required this.normal, required this.abnormal});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
        center: Offset(size.width / 2, size.height - 6),
        width: math.min(size.width * .66, 250),
        height: 150);
    final base = Paint()
      ..color = const Color(0xFFE5EAF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, base);
    final total = normal + abnormal;
    if (total == 0) return;
    final normalAngle = math.pi * normal / total;
    canvas.drawArc(
        rect,
        math.pi,
        normalAngle,
        false,
        Paint()
          ..color = const Color(0xFF165DFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeCap = StrokeCap.round);
    if (abnormal > 0) {
      canvas.drawArc(
          rect,
          math.pi + normalAngle,
          math.pi - normalAngle,
          false,
          Paint()
            ..color = Colors.redAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 14
            ..strokeCap = StrokeCap.round);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.normal != normal || oldDelegate.abnormal != abnormal;
}
