import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/attendance_report.dart';
import '../../core/widgets/zoomable_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/worker_service.dart';

enum _ReportMode { day, month }

class WorkerReportPage extends StatefulWidget {
  const WorkerReportPage({super.key});
  @override
  State<WorkerReportPage> createState() => _WorkerReportPageState();
}

class _WorkerReportPageState extends State<WorkerReportPage> {
  static const _blue = Color(0xFF165DFF);
  static const _background = Color(0xFFF8F8FA);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  _ReportMode mode = _ReportMode.day;
  WorkerMonthReport? report;
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
      final result =
          await WorkerService.monthReport(DateFormat('yyyy-MM').format(month));
      if (!mounted) return;
      setState(() {
        report = result.data;
        if (!result.isSuccess) error = result.message;
      });
    } catch (_) {
      if (mounted) setState(() => error = '考勤记录加载失败，请稍后重试');
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
        backgroundColor: _background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('我的统计', style: TextStyle(fontWeight: FontWeight.w700)),
            Text(
              context.watch<AuthProvider>().currentUser?.realName?.isNotEmpty ==
                      true
                  ? context.watch<AuthProvider>().currentUser!.realName!
                  : context.watch<AuthProvider>().currentUser?.username ?? '',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF62636A)),
            ),
          ]),
          centerTitle: true,
        ),
        body: Column(children: [
          _header(),
          Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? _errorView()
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: mode == _ReportMode.day
                              ? _dailyReport()
                              : _monthlyReport(),
                        )),
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
                  color: const Color(0xFFF0F1F3),
                  borderRadius: BorderRadius.circular(10)),
              child: SegmentedButton<_ReportMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: _ReportMode.day, label: Text('日报')),
                  ButtonSegment(value: _ReportMode.month, label: Text('月报')),
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
          const SizedBox(height: 16),
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

  Widget _errorView() => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(error!, style: const TextStyle(color: Colors.redAccent)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('重新加载')),
      ]));

  Widget _dailyReport() => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _calendar(),
          const SizedBox(height: 12),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _selectedDayCard()),
          const SizedBox(height: 24),
        ],
      );

  Widget _calendar() {
    final first = DateTime(month.year, month.month, 1);
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final leading = first.weekday % 7;
    final cellCount = ((leading + days) / 7).ceil() * 7;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
      child: Column(children: [
        const Row(children: [
          Expanded(
              child: Center(
                  child:
                      Text('日', style: TextStyle(color: Color(0xFF92939A))))),
          Expanded(
              child: Center(
                  child:
                      Text('一', style: TextStyle(color: Color(0xFF92939A))))),
          Expanded(
              child: Center(
                  child:
                      Text('二', style: TextStyle(color: Color(0xFF92939A))))),
          Expanded(
              child: Center(
                  child:
                      Text('三', style: TextStyle(color: Color(0xFF92939A))))),
          Expanded(
              child: Center(
                  child:
                      Text('四', style: TextStyle(color: Color(0xFF92939A))))),
          Expanded(
              child: Center(
                  child:
                      Text('五', style: TextStyle(color: Color(0xFF92939A))))),
          Expanded(
              child: Center(
                  child:
                      Text('六', style: TextStyle(color: Color(0xFF92939A))))),
        ]),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cellCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: .88),
          itemBuilder: (_, index) {
            final day = index - leading + 1;
            if (day < 1 || day > days) return const SizedBox.shrink();
            return _calendarDay(DateTime(month.year, month.month, day));
          },
        ),
      ]),
    );
  }

  Widget _calendarDay(DateTime date) {
    final attendance = _attendanceFor(date);
    final selected = DateUtils.isSameDay(date, selectedDate);
    final today = DateUtils.isSameDay(date, DateTime.now());
    final abnormal = attendance != null &&
        attendance.status != 'normal' &&
        attendance.status != 'manual' &&
        attendance.status != 'in_progress';
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => setState(() => selectedDate = date),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? _blue
                  : today
                      ? const Color(0xFFDDEEFF)
                      : null),
          child: Text('${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : today
                        ? _blue
                        : Colors.black87,
              )),
        ),
        const SizedBox(height: 2),
        Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: attendance == null
                  ? Colors.transparent
                  : abnormal
                      ? Colors.redAccent
                      : _blue,
            )),
      ]),
    );
  }

  Widget _selectedDayCard() {
    final day = _attendanceFor(selectedDate);
    if (day == null) {
      return _surface(
          child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          const Icon(Icons.event_busy_outlined,
              size: 42, color: Color(0xFF92939A)),
          const SizedBox(height: 10),
          Text('${DateFormat('M月d日').format(selectedDate)}暂无考勤记录',
              style: const TextStyle(color: Color(0xFF62636A))),
        ]),
      ));
    }
    return _surface(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(
                '上下班打卡（工时 ${_hours(day.workHours)}${day.overtimeHours > 0 ? ' · 加班 ${_hours(day.overtimeHours)}' : ''}）',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700))),
        _statusBadge(day),
      ]),
      const SizedBox(height: 6),
      Text('${day.projectName} · ${day.teamName} · ${day.shiftName}',
          style: const TextStyle(color: Color(0xFF62636A))),
      if (day.statusMessage.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(day.statusMessage,
            style: TextStyle(
                color: day.status == 'normal'
                    ? const Color(0xFF62636A)
                    : Colors.orange[800])),
      ],
      const Divider(height: 28),
      if (day.clocks.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('暂无打卡明细')))
      else
        ...List.generate(
            day.clocks.length,
            (index) => _timelineClock(day.clocks[index], index,
                day.clocks.length, day.status == 'in_progress')),
    ]));
  }

  Widget _timelineClock(
      AttendanceClockDetail clock, int index, int count, bool inProgress) {
    final missing = clock.status == 'missing';
    final warning = (missing && !inProgress) || (!missing && !clock.countable);
    return IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
          width: 66,
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(missing ? '--:--' : _shortTime(clock.clockTime),
                style:
                    const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
          )),
      SizedBox(
          width: 26,
          child: Column(children: [
            Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 9),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: warning ? Colors.orange : _blue)),
            if (index < count - 1)
              Expanded(
                  child: Container(width: 2, color: const Color(0xFFE7E7EA))),
          ])),
      Expanded(
          child: Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 22),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(clock.checkpointName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600))),
            if (clock.hasPhoto && clock.recordId != null)
              IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: '查看打卡照片',
                  onPressed: () => _showClockPhoto(clock),
                  icon: const Icon(Icons.photo_camera_outlined, color: _blue)),
          ]),
          const SizedBox(height: 3),
          Text(_clockDescription(clock, inProgress),
              style: TextStyle(
                  color:
                      warning ? Colors.orange[800] : const Color(0xFF62636A))),
          if (clock.adjustmentAction.isNotEmpty)
            Text(
                '${_adjustmentLabel(clock.adjustmentAction)}${clock.correctionReason.isEmpty ? '' : ' · 原因：${clock.correctionReason}'}',
                style: const TextStyle(
                    color: Colors.indigo, fontWeight: FontWeight.w500)),
        ]),
      )),
    ]));
  }

  Widget _monthlyReport() {
    final value = report!;
    final normalDays = value.days
        .where((day) => day.status == 'normal' || day.status == 'manual')
        .length;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _surface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('月度考勤汇总',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _summaryMetric('$normalDays', '正常天数', _blue),
            _summaryMetric('${value.anomalyDays}', '异常天数', Colors.redAccent),
            _summaryMetric(
                _hours(value.totalWorkHours), '正常工时', Colors.black87),
          ]),
          const Divider(height: 32),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _summaryMetric(
                value.totalWorkUnits.toStringAsFixed(2), '工数', Colors.black87),
            _summaryMetric(
                _hours(value.totalOvertimeHours), '加班', Colors.black87),
            _summaryMetric('${value.correctedDays}', '修正天数', Colors.black87),
          ]),
        ])),
        const SizedBox(height: 14),
        if (value.days.isEmpty)
          _surface(
              child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('本月暂无考勤记录'))))
        else
          ...value.days.reversed.map(_monthDayCard),
      ],
    );
  }

  Widget _monthDayCard(DailyAttendance day) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _surface(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              leading: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF5FD),
                    borderRadius: BorderRadius.circular(12)),
                child: Text(day.date.length >= 10 ? day.date.substring(8) : '',
                    style: const TextStyle(
                        color: _blue,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
              title: Text('${day.projectName} · ${day.shiftName}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  Text('工时 ${_hours(day.workHours)} · 工数 ${day.workUnits}'),
              trailing: _statusBadge(day),
              children: day.clocks
                  .map((clock) =>
                      _compactClock(clock, day.status == 'in_progress'))
                  .toList(),
            )),
      );

  Widget _compactClock(AttendanceClockDetail clock, bool inProgress) {
    final missing = clock.status == 'missing';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(
            missing
                ? Icons.cancel_outlined
                : clock.countable
                    ? Icons.check_circle_outline
                    : Icons.error_outline,
            size: 20,
            color: (missing && !inProgress) || (!missing && !clock.countable)
                ? Colors.orange
                : _blue),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(clock.checkpointName),
          if (clock.adjustmentAction.isNotEmpty)
            Text(
                '${_adjustmentLabel(clock.adjustmentAction)}${clock.correctionReason.isEmpty ? '' : ' · 原因：${clock.correctionReason}'}',
                style: const TextStyle(color: Colors.indigo, fontSize: 12)),
        ])),
        if (clock.hasPhoto && clock.recordId != null)
          IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '查看打卡照片',
              onPressed: () => _showClockPhoto(clock),
              icon: const Icon(Icons.photo_camera_outlined, color: _blue)),
        Text(
            missing ? (inProgress ? '待打卡' : '缺卡') : _shortTime(clock.clockTime),
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _showClockPhoto(AttendanceClockDetail clock) async {
    final recordId = clock.recordId;
    if (recordId == null) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${clock.checkpointName} · 打卡照片'),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder(
            future: WorkerService.clockPhotoViewUrl(recordId),
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

  String _adjustmentLabel(String action) =>
      const {
        'supplement': '主管补卡',
        'correct': '时间调整',
        'confirm': '确认有效',
        'void': '历史误打',
      }[action] ??
      action;

  Widget _statusBadge(DailyAttendance day) {
    final normal = day.status == 'normal';
    final inProgress = day.status == 'in_progress';
    final text = normal
        ? '正常'
        : inProgress
            ? '班次进行中'
            : day.status == 'missing'
                ? '缺卡'
                : day.status == 'manual'
                    ? '人工工时'
                    : '异常';
    final color = normal
        ? const Color(0xFF00B42A)
        : inProgress
            ? _blue
            : Colors.orange[800]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _summaryMetric(String value, String label, Color color) =>
      Column(children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text.rich(TextSpan(children: _metricSpans(value, color))),
        ),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(color: Color(0xFF62636A))),
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
              color: color, fontSize: 24, fontWeight: FontWeight.w700),
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
            color: Color(0xFF62636A),
            fontSize: 13,
            fontWeight: FontWeight.w500),
      ));
      start = match.end;
    }
    if (start < value.length) {
      spans.add(TextSpan(
        text: value.substring(start),
        style:
            TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w700),
      ));
    }
    return spans;
  }

  Widget _surface({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 3))
          ],
        ),
        child: child,
      );

  DailyAttendance? _attendanceFor(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    for (final day in report?.days ?? const <DailyAttendance>[]) {
      if (day.date == key) return day;
    }
    return null;
  }

  String _shortTime(String value) {
    if (value.isEmpty) return '--:--';
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return DateFormat('HH:mm').format(parsed);
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  String _clockDescription(AttendanceClockDetail clock, bool inProgress) {
    if (clock.checkpointName.startsWith('加班')) {
      if (!clock.countable) {
        return clock.anomalyMessage.isEmpty ? '加班打卡异常' : clock.anomalyMessage;
      }
      return clock.corrected ? '加班打卡 · 已修正' : '加班打卡 · 正常';
    }
    if (clock.status == 'missing') {
      return '${inProgress ? '待打卡' : '缺卡'} · 标准 ${_shortTime(clock.expectedTime)}';
    }
    final parts = <String>[
      clock.countable
          ? '正常'
          : clock.anomalyMessage.isEmpty
              ? '异常'
              : clock.anomalyMessage,
      '标准 ${_shortTime(clock.expectedTime)}',
    ];
    if (clock.corrected) parts.add('已修正');
    return parts.join(' · ');
  }

  String _hours(double value) {
    final hours = value.floor();
    final minutes = ((value - hours) * 60).round();
    return minutes == 0 ? '$hours小时' : '$hours小时$minutes分钟';
  }
}
