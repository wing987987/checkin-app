import '../core/models/api_result.dart';

/// Cache credentials separately from image bytes; combine concurrent requests.
class SignedImageUrls {
  static final _entries = <String, _Entry>{};
  static int _generation = 0;
  static void clear() {
    _generation++;
    _entries.clear();
  }

  static Future<ApiResult<String>> get(
      String key, Future<ApiResult<String>> Function() load) {
    final existing = _entries[key];
    if (existing != null && existing.expires.isAfter(DateTime.now())) {
      return existing.future;
    }
    final generation = _generation;
    final entry = _Entry(load());
    _entries[key] = entry;
    entry.future.then((result) {
      if (!result.isSuccess &&
          generation == _generation &&
          identical(_entries[key], entry)) {
        _entries.remove(key);
      }
    }, onError: (Object _, StackTrace __) {
      if (generation == _generation && identical(_entries[key], entry)) {
        _entries.remove(key);
      }
    });
    return entry.future;
  }
}

class _Entry {
  final Future<ApiResult<String>> future;
  final DateTime expires = DateTime.now().add(const Duration(minutes: 50));
  _Entry(this.future);
}
