import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:olympus_tg6_manager/services/image_cache.dart';
import 'package:olympus_tg6_manager/services/thumbnail_manager.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_helpers.dart';

Uint8List _validJpeg() => Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed active request waits for resume instead of becoming broken',
      () async {
    final firstStarted = Completer<void>();
    final releaseFirst = Completer<void>();
    var calls = 0;

    final client = MockClient((_) async {
      calls++;
      if (calls == 1) {
        firstStarted.complete();
        await releaseFirst.future;
        return http.Response('camera WiFi gone', 500);
      }
      return http.Response.bytes(_validJpeg(), 200);
    });
    final manager = ThumbnailManager.forTesting(client: client);
    manager.updateVisibleRange(0, 20);

    final resultFuture = manager.load(
      'http://192.168.0.10/get_resizeimg.cgi?DIR=/DCIM/A.ORF&size=1024',
      0,
    );
    await firstStarted.future;

    manager.pauseNetwork();
    releaseFirst.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    var completedWhilePaused = false;
    resultFuture.then((_) => completedWhilePaused = true);
    await Future<void>.delayed(Duration.zero);
    expect(completedWhilePaused, isFalse);
    expect(calls, 1);

    manager.resumeNetwork();
    final result = await resultFuture.timeout(const Duration(seconds: 1));

    expect(result, equals(_validJpeg()));
    expect(calls, 2);
  });

  test('overlapping pause owners must both resume before HTTP restarts',
      () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response.bytes(_validJpeg(), 200);
    });
    final manager = ThumbnailManager.forTesting(client: client);

    manager.pauseNetwork();
    manager.pauseNetwork();
    final resultFuture = manager.load(
      'http://192.168.0.10/get_thumbnail.cgi?DIR=/DCIM/B.JPG',
      0,
    );
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);

    manager.resumeNetwork();
    await Future<void>.delayed(Duration.zero);
    expect(calls, 0);

    manager.resumeNetwork();
    final result = await resultFuture.timeout(const Duration(seconds: 1));
    expect(result, equals(_validJpeg()));
    expect(calls, 1);
  });

  test('successful thumbnail is on disk before load completes', () async {
    final root = await Directory.systemTemp.createTemp('olympus_thumb_cache_');
    PathProviderPlatform.instance = FakePathProvider(root.path);
    SharedPreferences.setMockInitialValues({});
    await ImageDiskCache.instance.resetForTests();

    try {
      final client = MockClient(
        (_) async => http.Response.bytes(_validJpeg(), 200),
      );
      final manager = ThumbnailManager.forTesting(client: client);
      const key = '/DCIM/A.ORF|123|1|2|grid1024';

      final result = await manager.load(
        'http://192.168.0.10/get_resizeimg.cgi?DIR=/DCIM/A.ORF&size=1024',
        0,
        imagePath: key,
      );

      expect(result, equals(_validJpeg()));
      expect(await ImageDiskCache.instance.has(key, 'thumb'), isTrue);
    } finally {
      await ImageDiskCache.instance.resetForTests();
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    }
  });
}
