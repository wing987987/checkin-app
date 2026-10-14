import 'dart:io';
import 'package:dio/dio.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';

class PdfFileService {
  static Future<bool> exists(String path) => File(path).exists();
  static Future<String> download(String url, String name,
      {String? taskId, void Function(double)? onProgress}) async {
    final directory = await getApplicationDocumentsDirectory();
    final key =
        (taskId ?? 'download').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final folder = Directory('${directory.path}/construction_exports/$key');
    await folder.create(recursive: true);
    // Keep downloaded PDFs until the user removes the app or its data.
    final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = '${folder.path}/$safeName';
    final temp = '$path.part';
    try {
      await Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(minutes: 5)))
          .download(url, temp, onReceiveProgress: (received, total) {
        if (total > 0) onProgress?.call(received / total);
      });
      final file = File(temp);
      final input = await file.open();
      final header = await input.read(5);
      await input.close();
      if (String.fromCharCodes(header) != '%PDF-') {
        throw const FormatException('下载内容不是PDF');
      }
      if (await File(path).exists()) await File(path).delete();
      await file.rename(path);
      return path;
    } catch (_) {
      if (await File(temp).exists()) await File(temp).delete();
      rethrow;
    }
  }

  static Future<void> open(String path) async {
    final result = await OpenFile.open(path, type: 'application/pdf');
    if (result.type != ResultType.done) throw Exception('没有可打开PDF的应用，请使用分享功能');
  }

  static Future<void> share(String path, Rect origin) async {
    await Share.shareXFiles([XFile(path, mimeType: 'application/pdf')],
        sharePositionOrigin: origin);
  }
}
