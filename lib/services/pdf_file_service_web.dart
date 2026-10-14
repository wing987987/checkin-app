import 'package:web/web.dart' as html;
import 'package:flutter/material.dart';

class PdfFileService {
  static Future<bool> exists(String path) async => false;
  static Future<String> download(String url, String name,
      {String? taskId, void Function(double)? onProgress}) async {
    final link = (html.document.createElement('a') as html.HTMLAnchorElement)
      ..href = url
      ..target = '_blank'
      ..rel = 'noopener'
      ..download = name;
    html.document.body!.appendChild(link);
    link.click();
    link.remove();
    return url;
  }

  static Future<void> open(String path) async {
    html.window.open(path, '_blank');
  }

  static Future<void> share(String path, Rect origin) async {
    // Browser PDF viewer offers download and print without loading it in app memory.
    html.window.open(path, '_blank');
  }
}
