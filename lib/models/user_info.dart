/// 打卡 App 用户（ck_user，与采购 App 的 user_info 完全隔离）
class UserInfo {
  final int id;
  final String username;
  final String? realName;
  final String? phone;

  /// 角色：admin=主管理员，worker=工人
  final String role;

  UserInfo({
    required this.id,
    required this.username,
    this.realName,
    this.phone,
    required this.role,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      realName: json['realName'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'worker',
    );
  }
}