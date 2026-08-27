import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/attendance_report.dart';
import '../../models/checkin_project.dart';
import '../../services/management_service.dart';

enum _ProjectReportMode { day, month }

class ProjectReportPage extends StatefulWidget {
  final CheckinProject project;
  const ProjectReportPage({super.key, required this.project});
  @override
  State<ProjectReportPage> createState() => _ProjectReportPageState();
}

class _ProjectReportPageState extends State<ProjectReportPage> {
  static const _blue = Color(0xFF2388F5);
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  _ProjectReportMode mode = _ProjectReportMode.day;
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
        backgroundColor: const Color(0xFFF3F6FA),
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
            SegmentedButton<_ProjectReportMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: _ProjectReportMode.day, label: Text('日报')),
                ButtonSegment(
                    value: _ProjectReportMode.month, label: Text('月报')),
              ],
              selected: {mode},
              onSelectionChanged: (value) => setState(() => mode = value.first),
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
            ),
          ]),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            IconButton.filledTonal(
                onPressed: () => _moveMonth(-1),
                icon: const Icon(Icons.chevron_left)),
            Text('${month.month}月',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
            IconButton.filledTonal(
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.chevron_right)),
          ]),
        ]),
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
              trailing: day.status == 'normal'
                  ? const Chip(label: Text('正常'))
                  : const Chip(label: Text('异常')),
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
                      title: Text(clock.checkpointName),
                      trailing: Text(clock.status == 'missing'
                          ? '未打卡'
                          : _time(clock.clockTime)),
                    )),
                if (day.status == 'missing' || day.status == 'anomaly')
                  Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                          onPressed: () => _manualHours(day),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('人工填写工时'))),
              ],
            )),
      );

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
            _metric(_hours(value.totalWorkHours), '正常工时', Colors.black87),
          ]),
          const Divider(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _metric(
                value.totalWorkUnits.toStringAsFixed(2), '总工数', Colors.black87),
            _metric(_hours(value.totalOvertimeHours), '加班', Colors.black87),
            _metric('${value.workers.length}', '考勤人数', Colors.black87),
          ]),
        ])),
        const SizedBox(height: 14),
        if (value.workers.isEmpty)
          _surface(
              child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: Text('本月暂无考勤'))))
        else
          ...value.workers.map((worker) => Card(
                  child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_outline)),
                title: Text(worker.workerName),
                subtitle: Text(
                    '${worker.teamName} · 出勤 ${worker.attendanceDays}天\n工数 ${worker.workUnits} · 工时 ${_hours(worker.workHours)} · 加班 ${_hours(worker.overtimeHours)}'),
                isThreeLine: true,
                trailing: worker.anomalyDays > 0
                    ? Chip(label: Text('异常 ${worker.anomalyDays}'))
                    : const Chip(label: Text('正常')),
              ))),
      ],
    );
  }

  List<DailyAttendance> _daysFor(DateTime date) {
    final key = DateFormat('yyyy-MM-dd').format(date);
    return report?.days.where((day) => day.date == key).toList() ?? const [];
  }

  Widget _metric(String value, String label, Color color) => Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ]);

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

  Future<void> _manualHours(DailyAttendance day) async {
    final hours = TextEditingController();
    final reason = TextEditingController();
    final saved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text('${day.workerName} · ${day.date}'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('该日打卡不完整，请根据现场实际情况人工填写正常工时。'),
                TextField(
                    controller: hours,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: '正常工时（0–24小时）')),
                TextField(
                    controller: reason,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: '判断原因（必填）')),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('取消')),
                FilledButton(
                    onPressed: () async {
                      final value = double.tryParse(hours.text);
                      if (value == null ||
                          value < 0 ||
                          value > 24 ||
                          reason.text.trim().isEmpty) {
                        return;
                      }
                      final result = await ManagementService.setManualHours({
                        'workerId': day.workerId,
                        'projectId': day.projectId,
                        'teamId': day.teamId,
                        'shiftId': day.shiftId,
                        'attendanceDate': day.date,
                        'workHours': value,
                        'reason': reason.text.trim(),
                      });
                      if (!ctx.mounted) return;
                      if (result.isSuccess) Navigator.pop(ctx, true);
                    },
                    child: const Text('确认并留痕')),
              ],
            ));
    if (saved == true) _load();
  }
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
                style: const TextStyle(color: Color(0xFF2388F5), fontSize: 18)),
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
          ..color = const Color(0xFF2388F5)
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
