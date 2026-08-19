import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/env_config.dart';
import '../../providers/auth_provider.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('昭臣打卡'),
        actions: [
          IconButton(
              tooltip: '退出登录',
              icon: const Icon(Icons.logout),
              onPressed: () => auth.logout()),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('欢迎，${user?.realName ?? user?.username ?? ''}',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('环境: ${EnvConfig.instance.env} | 角色: ${user?.role ?? '-'}',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 24),
            Text('项目骨架已就绪，功能开发见 PLAN.md',
                style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}