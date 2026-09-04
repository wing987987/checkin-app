import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/demo_accounts.dart';
import '../../core/config/env_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _formError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    if (username.isEmpty || password.isEmpty) {
      setState(() => _formError = '请输入用户名和密码');
      return;
    }
    setState(() => _formError = null);
    final auth = context.read<AuthProvider>();
    final success = await auth.login(username, password);
    if (!success && mounted) setState(() => _formError = auth.error ?? '登录失败');
  }

  Future<void> _quickLogin(DemoAccount account) async {
    setState(() => _formError = null);
    final auth = context.read<AuthProvider>();
    final success = await auth.login(account.username, account.password);
    if (!success && mounted) setState(() => _formError = auth.error ?? '登录失败');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F4FF), Color(0xFFF8FBFF), Color(0xFFFFF7EA)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(children: [
                  Image.asset('assets/branding/app_logo_transparent.png',
                      width: 88, height: 88),
                  const SizedBox(height: 16),
                  const Text('昭臣打卡',
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text('工程现场 · 人员考勤 · 真实可靠',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 4),
                  const Text('让现场管理更简单',
                      style: TextStyle(
                          color: AppColors.textTertiary, fontSize: 13)),
                  const SizedBox(height: 28),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('登录',
                                style: Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 4),
                            const Text('使用企业账号继续',
                                style:
                                    TextStyle(color: AppColors.textTertiary)),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _usernameController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.person_outline),
                                  hintText: '用户名'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                hintText: '密码',
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword ? '显示密码' : '隐藏密码',
                                  onPressed: () => setState(() =>
                                      _obscurePassword = !_obscurePassword),
                                  icon: Icon(_obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined),
                                ),
                              ),
                              onSubmitted: (_) => _handleLogin(),
                            ),
                            if (_formError != null) ...[
                              const SizedBox(height: 8),
                              Text(_formError!,
                                  style: const TextStyle(
                                      color: AppColors.danger, fontSize: 12)),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: auth.isLoading ? null : _handleLogin,
                                child: auth.isLoading
                                    ? const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white)),
                                            SizedBox(width: 8),
                                            Text('登录中…'),
                                          ])
                                    : const Text('登录'),
                              ),
                            ),
                          ]),
                    ),
                  ),
                  if (EnvConfig.instance.showTestFeatures) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8EC),
                        border: Border.all(color: const Color(0xFFFFE2B8)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.science_outlined,
                                  size: 18, color: AppColors.warning),
                              const SizedBox(width: 6),
                              Text('测试环境快捷登录 · ${EnvConfig.instance.env}',
                                  style: const TextStyle(
                                      color: AppColors.warning,
                                      fontWeight: FontWeight.w600)),
                            ]),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: DemoAccounts.accounts
                              .map((account) => ActionChip(
                                    backgroundColor: Colors.white,
                                    disabledColor: AppColors.surfaceSubtle,
                                    side: const BorderSide(
                                        color: AppColors.border),
                                    labelStyle: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 8),
                                    avatar: Icon(
                                        account.role == 'supervisor'
                                            ? Icons.manage_accounts_outlined
                                            : Icons.engineering_outlined,
                                        size: 17,
                                        color: AppColors.primary),
                                    label: Text(account.name),
                                    onPressed: auth.isLoading
                                        ? null
                                        : () => _quickLogin(account),
                                  ))
                              .toList(),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
