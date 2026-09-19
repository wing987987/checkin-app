class DemoAccounts {
  static const accounts = <DemoAccount>[
    DemoAccount(
      username: 'ck_boss',
      password: '123456',
      name: '测试老总',
      role: 'boss',
      detail: '全部项目',
    ),
    DemoAccount(
      username: 'ck_supervisor_a',
      password: '123456',
      name: '测试主管甲',
      role: 'supervisor',
      detail: '测试项目A',
    ),
    DemoAccount(
      username: 'ck_supervisor_b',
      password: '123456',
      name: '测试主管乙',
      role: 'supervisor',
      detail: '测试项目B',
    ),
    DemoAccount(
      username: 'ck_worker_a',
      password: '123456',
      name: '张师傅',
      role: 'worker',
      detail: '测试项目A · 测试一班',
    ),
    DemoAccount(
      username: 'ck_worker_b',
      password: '123456',
      name: '李师傅',
      role: 'worker',
      detail: '测试项目A · 测试一班',
    ),
    DemoAccount(
      username: 'ck_worker_c',
      password: '123456',
      name: '王师傅',
      role: 'worker',
      detail: '测试项目B · 测试二班',
    ),
    DemoAccount(
      username: '13900000001',
      password: '123456',
      name: '李白',
      role: 'worker',
      detail: '测试项目A · 测试一班 · 标准白班',
    ),
    DemoAccount(
      username: '13900000002',
      password: '123456',
      name: '王白',
      role: 'worker',
      detail: '测试项目A · 测试一班 · 标准白班',
    ),
  ];
}

class DemoAccount {
  final String username;
  final String password;
  final String name;
  final String role;
  final String detail;

  const DemoAccount({
    required this.username,
    required this.password,
    required this.name,
    required this.role,
    required this.detail,
  });

  String get roleLabel => role == 'boss'
      ? '老总'
      : role == 'supervisor'
          ? '项目主管'
          : '工人';
}
