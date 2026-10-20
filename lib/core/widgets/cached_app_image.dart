import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

/// Stable identity excludes expiring credentials, but keeps processing/version parameters.
String imageCacheKey(String url, String account) {
  final uri = Uri.parse(url);
  const credentials = {
    'signature',
    'expires',
    'ossaccesskeyid',
    'security-token',
    'x-oss-signature',
    'x-oss-credential',
    'x-oss-date',
    'x-oss-expires',
    'x-oss-security-token',
    'x-oss-signature-version',
    'x-oss-additional-headers'
  };
  final query = Map<String, String>.from(uri.queryParameters)
    ..removeWhere((key, _) => credentials.contains(key.toLowerCase()));
  final keys = query.keys.toList()..sort();
  return '$account|${uri.replace(queryParameters: {
        for (final key in keys) key: query[key]!
      }, fragment: '')}';
}

/// Native platforms persist files; Web uses the browser HTTP cache and HTML images.
class CachedAppImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  const CachedAppImage(
      {super.key,
      required this.url,
      this.width,
      this.height,
      this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider?>()?.currentUser;
    final scope = '${user?.id}:${user?.username}';
    Widget error() => const Center(child: Icon(Icons.broken_image_outlined));
    if (kIsWeb) {
      return Image.network(url,
          width: width,
          height: height,
          fit: fit,
          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
          errorBuilder: (_, __, ___) => error());
    }
    return CachedNetworkImage(
        imageUrl: url,
        cacheKey: imageCacheKey(url, scope),
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => const Center(
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))),
        errorWidget: (_, __, ___) => error());
  }
}
