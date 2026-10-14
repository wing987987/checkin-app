import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/log_reminder_service.dart';
import '../../services/construction_log_service.dart';
import '../theme/app_theme.dart';

/// Keeps the reminder visible across project, attendance and log routes.
class LogReminderHost extends StatefulWidget {
  final Widget child;
  final DateTime Function()? clock;
  const LogReminderHost({super.key, required this.child, this.clock});
  @override
  State<LogReminderHost> createState() => _LogReminderHostState();
}

class _LogReminderHostState extends State<LogReminderHost>
    with WidgetsBindingObserver {
  final service = LogReminderService.instance;
  Timer? _timer;
  bool _checking = false;
  int? _actor;
  int _pending = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    service.changes.addListener(_changed);
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.watch<AuthProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _changed() => _check();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  @override
  void dispose() {
    _timer?.cancel();
    service.changes.removeListener(_changed);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted ||
        _checking ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed)) {
      return;
    }
    final auth = context.read<AuthProvider>();
    final actor = auth.currentUser?.id;
    if (!auth.isSupervisor || actor == null) {
      if (_actor != null || _pending != 0) {
        setState(() {
          _actor = null;
          _pending = 0;
        });
      }
      return;
    }
    _checking = true;
    try {
      var show =
          await service.shouldShowInApp(actor, now: widget.clock?.call());
      if (show && (_actor != actor || _pending == 0)) {
        // Verify once before showing, including submissions made on another device.
        final projects =
            await service.pendingProjects(actor, now: widget.clock?.call());
        for (final project in projects) {
          try {
            final result = await ConstructionLogService.mine(project);
            if (!mounted ||
                !auth.isSupervisor ||
                auth.currentUser?.id != actor) {
              return;
            }
            if (result.isSuccess && result.data?['status'] == 'submitted') {
              await service.markSubmitted(
                  actor, project, result.data!['today'] as String);
            }
          } catch (_) {
            // Keep the local reminder available when the network is offline.
          }
        }
        show = await service.shouldShowInApp(actor, now: widget.clock?.call());
      }
      final pending = show
          ? (await service.pendingProjects(actor, now: widget.clock?.call()))
              .length
          : 0;
      if (mounted &&
          auth.isSupervisor &&
          auth.currentUser?.id == actor &&
          (_actor != actor || _pending != pending)) {
        setState(() {
          _actor = actor;
          _pending = pending;
        });
      }
    } catch (_) {
      // A failed refresh never blocks the page; try again on the next tick.
    } finally {
      _checking = false;
    }
  }

  Future<void> _dismiss({bool open = false}) async {
    final actor = _actor;
    if (actor == null) return;
    await service.dismissInApp(actor, now: widget.clock?.call());
    if (!mounted) return;
    setState(() => _pending = 0);
    final auth = context.read<AuthProvider>();
    if (open && auth.isSupervisor && auth.currentUser?.id == actor) {
      service.taps.value++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Stack(children: [
      widget.child,
      if (_pending > 0 && auth.isSupervisor && auth.currentUser?.id == _actor)
        Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
                child: Material(
              color: AppColors.surface,
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Row(children: [
                          Icon(Icons.notifications_active_outlined,
                              color: AppColors.primary),
                          SizedBox(width: 8),
                          Expanded(
                              child: Text('施工日志填写提醒',
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)))
                        ]),
                        const SizedBox(height: 8),
                        Text('今日还有 $_pending 个项目日志未提交，请完成今日进度、明日计划和施工图片。',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                height: 1.5)),
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                  onPressed: () => _dismiss(),
                                  child: const Text('知道了')),
                              const SizedBox(width: 8),
                              FilledButton(
                                  onPressed: () => _dismiss(open: true),
                                  child: const Text('去填写'))
                            ]),
                      ])),
            ))),
    ]);
  }
}
