import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:olympus_tg6_manager/screens/photo_preview_screen.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/image_cache.dart';
import 'package:olympus_tg6_manager/services/thumbnail_manager.dart';

import 'helpers/fake_camera_server.dart';

/// Counts simultaneous in-flight requests to assert the concurrency cap.
class _CountingClient extends http.BaseClient {
  _CountingClient(this._inner);

  final http.Client _inner;
  int _inFlight = 0;
  int _maxInFlight = 0;

  int get maxInFlight => _maxInFlight;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _inFlight++;
    if (_inFlight > _maxInFlight) _maxInFlight = _inFlight;
    try {
      return await _inner.send(request);
    } finally {
      _inFlight--;
    }
  }

  @override
  void close() => _inner.close();
}

/// Runs the real services against the device: ImageDiskCache on the actual
/// filesystem (path_provider, SharedPreferences) and ThumbnailManager over
/// real TCP sockets to an in-process fake camera.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await ImageDiskCache.instance.resetForTests();
  });

  test('disk cache roundtrip and persistence on the real filesystem',
      () async {
    await ImageDiskCache.instance.resetForTests();
    const path = '/DCIM/INTG1.JPG|1|2|3';
    final Uint8List jpeg = FakeCameraServer.jpeg;

    await ImageDiskCache.instance.put(path, 'thumb', jpeg);
    await ImageDiskCache.instance.put(path, 'preview', jpeg);

    expect(await ImageDiskCache.instance.has(path, 'thumb'), isTrue);
    expect(await ImageDiskCache.instance.has(path, 'other'), isFalse);
    expect(await ImageDiskCache.instance.get(path, 'thumb'), jpeg);
    expect(await ImageDiskCache.instance.get(path, 'preview'), jpeg);
    expect(await ImageDiskCache.instance.get(path, 'missing'), isNull);

    // A fresh init (same as a new app session) must still find the files.
    await ImageDiskCache.instance.resetForTests();
    expect(await ImageDiskCache.instance.get(path, 'thumb'), jpeg);
  });

  test('thumbnail manager: first load goes over HTTP, reload comes from disk',
      () async {
    await ImageDiskCache.instance.resetForTests();
    final camera = FakeCameraServer();
    camera.addPhoto('/DCIM/INTG2.JPG');
    final base = await camera.start();
    addTearDown(camera.close);

    const imagePath = '/DCIM/INTG2.JPG|1|2|3';
    final url = '$base/get_thumbnail.cgi?DIR=/DCIM/INTG2.JPG';

    final first = await ThumbnailManager.forTesting()
        .load(url, 0, imagePath: imagePath);
    expect(first, isNotNull);
    expect(
      camera.requests.where((r) => r.contains('/get_thumbnail.cgi')),
      hasLength(1),
      reason: 'cache miss must fetch exactly once',
    );
    expect(await ImageDiskCache.instance.has(imagePath, 'thumb'), isTrue,
        reason: 'fetched thumbnail must land on the real disk cache');

    // Fresh manager = empty RAM cache; the camera must not be contacted again.
    final second = await ThumbnailManager.forTesting()
        .load(url, 0, imagePath: imagePath);
    expect(second, isNotNull);
    expect(
      camera.requests.where((r) => r.contains('/get_thumbnail.cgi')),
      hasLength(1),
      reason: 'second load must be served from the disk cache',
    );
  });

  test('thumbnail manager storm of 8 over real sockets: exactly-once + slot cap',
      () async {
    await ImageDiskCache.instance.resetForTests();
    final camera = FakeCameraServer()
      ..delay = const Duration(milliseconds: 30);
    for (var i = 0; i < 8; i++) {
      camera.addPhoto('/DCIM/ST$i.JPG');
    }
    final base = await camera.start();
    addTearDown(camera.close);

    final counting = _CountingClient(http.Client());
    final manager = ThumbnailManager.forTesting(client: counting);
    manager.updateVisibleRange(0, 8);

    final results = await Future.wait([
      for (var i = 0; i < 8; i++)
        manager.load(
          '$base/get_thumbnail.cgi?DIR=/DCIM/ST$i.JPG',
          i,
          imagePath: '/DCIM/ST$i.JPG|1|2|3',
        ),
    ]);

    for (final r in results) {
      expect(r, isNotNull);
    }
    for (var i = 0; i < 8; i++) {
      expect(
        camera.requests.where((r) => r.contains('/DCIM/ST$i.JPG')),
        hasLength(1),
        reason: 'ST$i.JPG must be fetched exactly once',
      );
    }
    expect(counting.maxInFlight, lessThanOrEqualTo(3),
        reason: 'the camera connection cap (3) must hold over real sockets');
  });

  /// Loads one thumbnail against a camera that fails with [failure] and
  /// asserts nothing reached the disk cache; then lets the camera recover
  /// and asserts the now-complete transfer is cached.
  ///
  /// The path is unique per failure mode: the real disk cache survives
  /// `resetForTests` (it only re-initializes, like a new app session), so a
  /// shared path would let one test's recovered entry satisfy the next.
  Future<void> expectNeverCached(FakeCameraFailure failure, String tag) async {
    await ImageDiskCache.instance.resetForTests();
    final camera = FakeCameraServer();
    camera.addPhoto('/DCIM/FAIL_$tag.JPG');
    final base = await camera.start();
    addTearDown(camera.close);
    camera.failFor('/DCIM/FAIL_$tag.JPG', failure);

    final imagePath = '/DCIM/FAIL_$tag.JPG|1|2|3';
    final url = '$base/get_thumbnail.cgi?DIR=/DCIM/FAIL_$tag.JPG';

    expect(
      await ThumbnailManager.forTesting().load(url, 0, imagePath: imagePath),
      isNull,
      reason: '$failure must not yield image bytes',
    );
    expect(
      camera.requests.any((r) => r.contains('/get_thumbnail.cgi')),
      isTrue,
      reason: '$failure: the fetch must actually have been attempted',
    );
    expect(
      await ImageDiskCache.instance.has(imagePath, 'thumb'),
      isFalse,
      reason: '$failure must not write anything to the disk cache',
    );

    // Camera recovers: the next load succeeds and only now may land on disk.
    camera.clearFailures();
    expect(
      await ThumbnailManager.forTesting().load(url, 0, imagePath: imagePath),
      isNotNull,
      reason: '$failure: a healthy camera must serve the photo again',
    );
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    var cached = false;
    while (DateTime.now().isBefore(deadline)) {
      if (await ImageDiskCache.instance.has(imagePath, 'thumb')) {
        cached = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(cached, isTrue, reason: 'only a complete transfer may be cached');
  }

  test('camera answering HTTP 500 is never cached', () async {
    await expectNeverCached(FakeCameraFailure.status500, 's500');
  });

  test('camera answering a non-JPEG body is never cached', () async {
    await expectNeverCached(FakeCameraFailure.garbageBody, 'garb');
  });

  test('camera dying mid-transfer (truncated JPEG) is never cached', () async {
    await expectNeverCached(FakeCameraFailure.truncatedJpeg, 'trunc');
  });

  testWidgets(
      'preview screen: dead camera shows the error state and caches nothing',
      (tester) async {
    await ImageDiskCache.instance.resetForTests();
    final camera = FakeCameraServer();
    camera.addPhoto('/DCIM/100OLYMP/DEAD.JPG');
    final base = await camera.start();
    addTearDown(camera.close);
    camera.failFor('/DCIM/100OLYMP/DEAD.JPG', FakeCameraFailure.truncatedJpeg);
    debugCameraBaseUrlOverride = base;
    addTearDown(() => debugCameraBaseUrlOverride = null);

    const fatDate = 22721, fatTime = 24576;
    final file = CameraFile(
      directory: '/DCIM/100OLYMP',
      filename: 'DEAD.JPG',
      size: FakeCameraServer.jpeg.lengthInBytes,
      attributes: 33,
      dateRaw: fatDate,
      timeRaw: fatTime,
      date: DateTime(2024, 6, 1, 12),
    );

    await tester.pumpWidget(MaterialApp(
      home: PhotoPreviewScreen(file: file, files: [file], initialIndex: 0),
    ));

    // Real sockets and real retry delays: poll the live tree until the
    // preview has exhausted its attempts and surfaced the error state.
    var failedVisible = false;
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump();
        if (find.text('Failed to load preview').evaluate().isNotEmpty) {
          failedVisible = true;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });
    expect(failedVisible, isTrue,
        reason: 'a dead camera must surface the error state, not hang');
    expect(
      camera.requests.any((r) => r.contains('/get_screennail.cgi')),
      isTrue,
      reason: 'the preferred screennail preview must be attempted over HTTP',
    );
    expect(
      camera.requests.any((r) => r.contains('/get_resizeimg.cgi')),
      isTrue,
      reason: 'the 1920 resize fallback must run when screennail fails',
    );

    expect(
      (tester.state(find.byType(PhotoPreviewScreen)) as dynamic)
          .debugPreviewCacheCount as int,
      0,
      reason: 'a failed fetch must not enter the in-memory preview cache',
    );
    expect(
      await ImageDiskCache.instance.get(file.downloadHistoryKey, 'preview'),
      isNull,
      reason: 'a failed fetch must not be written to the disk cache',
    );
  });
}
