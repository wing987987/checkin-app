import 'user_info.dart';

class LoginResult {
  final String token;
  final UserInfo user;

  const LoginResult({required this.token, required this.user});

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String? ?? '';
    if (token.trim().isEmpty) {
      throw const FormatException('登录响应缺少 token');
    }
    return LoginResult(
      token: token,
      user: UserInfo.fromJson({
        'id': json['userId'],
        'username': json['username'],
        'realName': json['realName'],
        'phone': json['phone'],
        'role': json['role'],
      }),
    );
  }
}
