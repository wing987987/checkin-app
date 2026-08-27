import 'package:flutter/material.dart';

import '../../services/app_update_service.dart';

class UpdateDialog extends StatefulWidget {
  final VersionInfo version;
  final String currentVersion;
  const UpdateDialog(
      {super.key, required this.version, required this.currentVersion});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool downloading = false;
  double progress = 0;
  String? error;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !widget.version.forceUpdate && !downloading,
        child: AlertDialog(
          title: const Row(children: [
            Icon(Icons.system_update, color: Color(0xFF2B7FFF)),
            SizedBox(width: 8),
            Text('发现新版本'),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Align(
                alignment: Alignment.centerLeft,
                child: Text('当前版本：${widget.currentVersion}')),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('新版本：${widget.version.versionName}',
                    style: const TextStyle(
                        color: Color(0xFF2B7FFF),
                        fontWeight: FontWeight.w600))),
            if (widget.version.releaseNotes.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(widget.version.releaseNotes)),
            ],
            if (downloading) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 6),
              Text('下载中…… ${(progress * 100).round()}%'),
            ],
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ]),
          actions: [
            if (!widget.version.forceUpdate && !downloading)
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('稍后更新')),
            if (!downloading)
              FilledButton(onPressed: _download, child: const Text('立即更新')),
          ],
        ),
      );

  Future<void> _download() async {
    setState(() {
      downloading = true;
      progress = 0;
      error = null;
    });
    try {
      await AppUpdateService.instance
          .downloadAndInstall(widget.version.downloadUrl, onProgress: (value) {
        if (mounted) setState(() => progress = value);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          downloading = false;
          error = '下载或安装失败：$e';
        });
      }
    }
  }
}

void showUpdateDialog(
    BuildContext context, VersionInfo version, String currentVersion) {
  showDialog<void>(
    context: context,
    barrierDismissible: !version.forceUpdate,
    builder: (_) =>
        UpdateDialog(version: version, currentVersion: currentVersion),
  );
}
