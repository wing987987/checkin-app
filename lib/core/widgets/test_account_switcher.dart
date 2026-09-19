import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../config/demo_accounts.dart';
import '../config/env_config.dart';

class TestAccountSwitcher extends StatelessWidget {
  const TestAccountSwitcher({super.key});

  static Future<void> show(BuildContext context) async {
    if (!EnvConfig.instance.showTestFeatures) return;
    final account = await showModalBottomSheet<DemoAccount>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              leading: Icon(Icons.science_outlined),
              title: Text('切换测试账号'),
              subtitle: Text('仅测试环境显示，默认密码均为 123456'),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: DemoAccounts.accounts.map((item) {
                  final current =
                      context.read<AuthProvider>().username == item.username;
                  return ListTile(
                    leading: CircleAvatar(
                      child: Icon(item.role == 'boss'
                          ? Icons.admin_panel_settings
                          : item.role == 'supervisor'
                              ? Icons.manage_accounts
                              : Icons.engineering),
                    ),
                    title: Text(item.name),
                    subtitle: Text('${item.roleLabel} · ${item.detail}'),
                    trailing: current
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: current
                        ? null
                        : () => Navigator.pop(sheetContext, item),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
    if (account == null || !context.mounted) return;

    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final success = await auth.login(account.username, account.password);
    if (!success && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('切换失败：${auth.error ?? '未知错误'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!EnvConfig.instance.showTestFeatures) return const SizedBox.shrink();
    return IconButton(
      tooltip: '切换测试账号',
      onPressed: () => show(context),
      icon: const Icon(Icons.swap_horiz),
    );
  }
}
