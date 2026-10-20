import 'dart:async';
import 'package:checkin_app/services/signed_image_urls.dart';
import 'package:checkin_app/core/models/api_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:checkin_app/core/widgets/cached_app_image.dart';
import 'package:checkin_app/core/widgets/deferred_image.dart';
import 'package:checkin_app/core/widgets/image_batch.dart';

void main() {
  test('signature requests are combined and logout drops old pending entries',
      () async {
    SignedImageUrls.clear();
    final pending = Completer<ApiResult<String>>();
    var requests = 0;
    Future<ApiResult<String>> load() {
      requests++;
      return pending.future;
    }

    final first = SignedImageUrls.get('photo:thumbnail', load);
    expect(
        identical(first, SignedImageUrls.get('photo:thumbnail', load)), isTrue);
    expect(requests, 1);
    SignedImageUrls.clear();
    final next = SignedImageUrls.get('photo:thumbnail',
        () async => ApiResult(code: 200, message: '', data: 'new-account-url'));
    pending
        .complete(ApiResult(code: 200, message: '', data: 'old-account-url'));
    await first;
    await next;
    expect(
        identical(next, SignedImageUrls.get('photo:thumbnail', load)), isTrue);
    expect(requests, 1);
    SignedImageUrls.clear();
  });

  test('rotating signatures reuse bytes, variants and accounts stay separate',
      () {
    const base = 'https://bucket.oss-cn-shanghai.aliyuncs.com/photo.jpg';
    final a =
        imageCacheKey('$base?Expires=1&Signature=a&OSSAccessKeyId=id', 'user1');
    expect(
        imageCacheKey('$base?Signature=b&Expires=2&OSSAccessKeyId=id', 'user1'),
        a);
    expect(imageCacheKey('$base?x-oss-process=image/resize,w_320', 'user1'),
        isNot(a));
    expect(imageCacheKey(base, 'user2'), isNot(a));
    expect(imageCacheKey('$base?versionId=new', 'user1'), isNot(a));
  });

  testWidgets('offscreen images defer work until scrolled into view',
      (tester) async {
    var loads = 0;
    final scroll = ScrollController();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                controller: scroll,
                child: Column(children: [
                  const SizedBox(height: 1200),
                  DeferredImage(
                      identity: 'photo',
                      width: 80,
                      height: 80,
                      builder: (_) {
                        loads++;
                        return const Text('loaded');
                      }),
                ])))));
    await tester.pump();
    expect(loads, 0);
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
    await tester.pump();
    expect(find.text('loaded'), findsOneWidget);
    expect(loads, 1);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });

  testWidgets('batch builds six images and loads remaining on demand',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ImageBatch(
      identity: 'day',
      count: 8,
      itemBuilder: (_, index) => Text('photo $index'),
    ))));
    expect(find.text('photo 5'), findsOneWidget);
    expect(find.text('photo 6'), findsNothing);
    await tester.tap(find.text('加载更多图片（剩余 2 张）'));
    await tester.pump();
    expect(find.text('photo 7'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });
}
