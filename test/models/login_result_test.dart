import 'package:checkin_app/models/login_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the flat checkin login response', () {
    final result = LoginResult.fromJson({
      'token': 'token-value',
      'userId': 7,
      'username': 'worker01',
      'realName': '张三',
      'phone': '13000000000',
      'role': 'worker',
    });

    expect(result.token, 'token-value');
    expect(result.user.id, 7);
    expect(result.user.username, 'worker01');
    expect(result.user.role, 'worker');
  });

  test('rejects a successful response without a token', () {
    expect(
      () => LoginResult.fromJson({
        'userId': 7,
        'username': 'worker01',
        'role': 'worker',
      }),
      throwsFormatException,
    );
  });
}
