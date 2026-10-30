import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

/// Register listeners before opening the camera. Some embedded browsers return
/// focus/cancel before change, or populate files without delivering change.
Future<List<XFile>> pickLogPhotos(ImageSource source,
    {void Function(web.HTMLInputElement)? activateInput}) async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*'
    ..multiple = source == ImageSource.gallery;
  if (source == ImageSource.camera) {
    input.setAttribute('capture', 'environment');
  }
  input.style.display = 'none';
  final result = Completer<List<web.File>>();
  Timer? cancelTimer;
  bool takeFiles() {
    if (result.isCompleted) return true;
    final files = input.files;
    if (files == null || files.length == 0) return false;
    result.complete([
      for (var i = 0; i < files.length; i++) files.item(i)!,
    ]);
    return true;
  }

  input.onchange = ((web.Event _) {
    // An empty change can precede the real result on iOS camera return.
    takeFiles();
  }).toJS;
  input.oncancel = ((web.Event _) {
    if (takeFiles()) return;
    cancelTimer?.cancel();
    cancelTimer = Timer(const Duration(seconds: 2), () {
      if (!takeFiles()) result.complete([]);
    });
  }).toJS;
  input.onerror = ((web.Event _) {
    if (!result.isCompleted) {
      result.completeError(StateError('浏览器未能返回照片'));
    }
  }).toJS;
  web.document.body!.append(input);
  final poll = Timer.periodic(const Duration(milliseconds: 250), (_) {
    takeFiles();
  });
  try {
    if (activateInput == null) {
      input.click();
    } else {
      activateInput(input);
    }
    final files = await result.future.timeout(const Duration(minutes: 3));
    // Read the actual File while the input is alive, avoiding an extra request
    // to a blob URL after returning from the iOS native camera.
    return await Future.wait(files.map(_readFile));
  } finally {
    poll.cancel();
    cancelTimer?.cancel();
    input.onchange = null;
    input.oncancel = null;
    input.onerror = null;
    input.remove();
  }
}

Future<XFile> _readFile(web.File file) async {
  final reader = web.FileReader();
  final result = Completer<XFile>();
  reader.onload = ((web.Event _) {
    if (result.isCompleted) return;
    try {
      final dataUrl = (reader.result as JSString).toDart;
      final bytes = base64Decode(dataUrl.substring(dataUrl.indexOf(',') + 1));
      if (bytes.isEmpty) throw StateError('照片内容为空');
      result.complete(XFile.fromData(bytes,
          name: file.name, mimeType: file.type, length: bytes.length));
    } catch (error, stack) {
      result.completeError(error, stack);
    }
  }).toJS;
  reader.onerror = ((web.Event _) {
    if (!result.isCompleted) result.completeError(StateError('照片读取失败'));
  }).toJS;
  reader.onabort = ((web.Event _) {
    if (!result.isCompleted) result.completeError(StateError('照片读取中断'));
  }).toJS;
  try {
    reader.readAsDataURL(file);
    return await result.future.timeout(const Duration(seconds: 15));
  } finally {
    reader.onload = null;
    reader.onerror = null;
    reader.onabort = null;
    if (reader.readyState == web.FileReader.LOADING) reader.abort();
  }
}
