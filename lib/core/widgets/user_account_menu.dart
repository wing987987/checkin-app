import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../models/user_info.dart';
import '../../providers/auth_provider.dart';
import '../../services/app_update_service.dart';
import 'update_dialog.dart';
import '../../features/management/job_type_management_page.dart';

class UserAccountMenu extends StatefulWidget {
  const UserAccountMenu({super.key});

  @override
  State<UserAccountMenu> createState() => _UserAccountMenuState();
}

class _UserAccountMenuState extends State<UserAccountMenu> {
  String version = '读取中';
  bool checking = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) {
        setState(() => version = '${info.version}+${info.buildNumber}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final name = _name(user);
    return PopupMenuButton<String>(
      tooltip: '用户菜单',
      offset: const Offset(0, 46),
      onSelected: (value) => _onSelected(value, user),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          height: 72,
          child: SizedBox(
            width: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('用户名：${user?.username ?? '-'}',
                    style: const TextStyle(color: Color(0xFF6F7883))),
                Text('角色：${_roleName(user?.role)}',
                    style: const TextStyle(color: Color(0xFF6F7883))),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          enabled: false,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('App 版本'),
            trailing: Text('v$version'),
          ),
        ),
        const PopupMenuItem(
          value: 'info',
          child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.account_circle_outlined),
              title: Text('用户信息')),
        ),
        if (user?.role == 'supervisor' || user?.role == 'boss')
          const PopupMenuItem(
            value: 'jobTypes',
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.handyman_outlined),
              title: Text('工种管理'),
            ),
          ),
        PopupMenuItem(
          value: 'update',
          enabled: !checking,
          child: const ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.system_update_outlined),
              title: Text('检查更新')),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout, color: Colors.redAccent),
              title: Text('退出登录', style: TextStyle(color: Colors.redAccent))),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          CircleAvatar(
              radius: 16,
              child: Text(name.isEmpty ? '?' : name.substring(0, 1))),
          const SizedBox(width: 7),
          Expanded(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          const Icon(Icons.arrow_drop_down, size: 20),
        ]),
      ),
    );
  }

  Future<void> _onSelected(String value, UserInfo? user) async {
    switch (value) {
      case 'info':
        _showUserInfo(user);
        break;
      case 'update':
        await _checkUpdate();
        break;
      case 'jobTypes':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const JobTypeManagementPage()));
        break;
      case 'logout':
        await context.read<AuthProvider>().logout();
        break;
    }
  }

  void _showUserInfo(UserInfo? user) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('用户信息'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _infoRow('姓名', _name(user)),
          _infoRow('用户名', user?.username ?? '-'),
          _infoRow('角色', _roleName(user?.role)),
          _infoRow(
              '手机号', user?.phone?.isNotEmpty == true ? user!.phone! : '未填写'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('关闭'))
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 66,
              child: Text(label,
                  style: const TextStyle(color: Color(0xFF62636A)))),
          Expanded(child: SelectableText(value)),
        ]),
      );

  Future<void> _checkUpdate() async {
    if (checking) return;
    setState(() => checking = true);
    showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));
    final result = await AppUpdateService.instance.checkUpdate();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => checking = false);
    if (result.errorMessage != null) {
      _message(result.errorMessage!);
    } else if (result.hasUpdate && result.latestVersion != null) {
      showUpdateDialog(context, result.latestVersion!, result.currentVersion);
    } else {
      _message('当前已是最新版本（v$version）');
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  String _name(UserInfo? user) => user?.realName?.isNotEmpty == true
      ? user!.realName!
      : user?.username ?? '用户';

  String _roleName(String? role) => role == 'boss'
      ? '老总'
      : role == 'supervisor'
          ? '项目主管'
          : role == 'worker'
              ? '工人'
              : role ?? '-';
}
