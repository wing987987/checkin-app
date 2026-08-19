/// 后端统一响应包装（与 seahorizon-backgroud 的 Result 结构一致）
class ApiResult<T> {
  final int code;
  final String message;
  final T? data;

  ApiResult({required this.code, required this.message, this.data});

  bool get isSuccess => code == 200;

  factory ApiResult.fromJson(
      Map<String, dynamic> json, T? Function(dynamic)? parse) {
    return ApiResult<T>(
      code: json['code'] as int? ?? -1,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && parse != null ? parse(json['data']) : null,
    );
  }
}