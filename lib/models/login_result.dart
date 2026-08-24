import 'user_info.dart';

class LoginResult {
  final String token;
  final String refreshToken;
  final UserInfo user;

  const LoginResult({
    required this.token,
    required this.refreshToken,
    required this.user,
  });

  factory LoginResult.fromJson(Map<String, dynamic> json) {
    final token = json['token'] as String? ?? '';
    final refreshToken = json['refreshToken'] as String? ?? '';
    if (token.trim().isEmpty || refreshToken.trim().isEmpty) {
      throw const FormatException('登录响应缺少认证令牌');
    }
    return LoginResult(
      token: token,
      refreshToken: refreshToken,
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
