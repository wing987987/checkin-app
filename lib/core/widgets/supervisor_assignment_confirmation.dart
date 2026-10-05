import 'package:flutter/material.dart';

class SupervisorAssignmentConfirmation extends StatelessWidget {
  final String name, project, team, shift, hours, newTeam;
  const SupervisorAssignmentConfirmation(
      {super.key,
      required this.name,
      required this.project,
      required this.team,
      required this.shift,
      required this.hours,
      required this.newTeam});
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('该主管已有考勤安排'),
        content: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text('$name 已安排：'),
              const SizedBox(height: 12),
              Text(
                  '项目：$project\n班组：$team\n班次：$shift${hours.isEmpty ? '' : '\n时间：$hours'}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Text('是否确定改为当前项目的“$newTeam”？\n更改后使用该班组默认班次，原考勤分配将被替换，历史考勤保留。'),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('确定更改'))
        ],
      );
}
