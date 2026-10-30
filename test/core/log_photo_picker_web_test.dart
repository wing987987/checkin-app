@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:checkin_app/core/utils/log_photo_picker_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:web/web.dart' as web;

void attachPhoto(web.HTMLInputElement input) {
  final transfer = web.DataTransfer();
  transfer.items.add(web.File(
      [
        Uint8List.fromList([1, 2, 3]).toJS
      ].toJS,
      'camera.jpg',
      web.FilePropertyBag(type: 'image/jpeg')));
  input.files = transfer.files;
}

void main() {
  test('camera result is handled even during picker activation', () async {
    final files =
        await pickLogPhotos(ImageSource.camera, activateInput: (input) {
      expect(input.getAttribute('capture'), 'environment');
      attachPhoto(input);
      input.dispatchEvent(web.Event('change'));
    });
    expect(files, hasLength(1));
    expect(await files.single.readAsBytes(), [1, 2, 3]);
    expect(web.document.querySelector('input[type=file]'), isNull);
  });

  test('iOS cancel before delayed photo does not discard the photo', () async {
    final files =
        await pickLogPhotos(ImageSource.camera, activateInput: (input) {
      input.dispatchEvent(web.Event('cancel'));
      Timer(const Duration(milliseconds: 400), () {
        attachPhoto(input);
        input.dispatchEvent(web.Event('change'));
      });
    });
    expect(files, hasLength(1));
    expect(await files.single.readAsBytes(), [1, 2, 3]);
  });

  test('photo is recovered when browser omits change', () async {
    final files =
        await pickLogPhotos(ImageSource.gallery, activateInput: (input) {
      expect(input.multiple, isTrue);
      attachPhoto(input);
    });
    expect(files, hasLength(1));
  });

  test('genuine cancellation finishes and cleans up input', () async {
    final files =
        await pickLogPhotos(ImageSource.camera, activateInput: (input) {
      input.dispatchEvent(web.Event('cancel'));
    });
    expect(files, isEmpty);
    expect(web.document.querySelector('input[type=file]'), isNull);
  });
}
