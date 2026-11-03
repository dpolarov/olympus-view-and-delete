import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:olympus_tg6_manager/constants.dart';
import 'package:olympus_tg6_manager/screens/photo_preview_screen.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/download_history.dart';
import 'package:olympus_tg6_manager/services/image_cache.dart';
import 'package:olympus_tg6_manager/services/preview_download_queue.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_helpers.dart';

class _FakeApi extends CameraApi {
  bool shouldSucceed = true;
  final List<String> deletedPaths = [];

  @override
  Future<bool> testConnection(
          {Duration timeout = const Duration(seconds: 5)}) async =>
      true;

  @override
  Future<bool> deleteFile(CameraFile file) async {
    deletedPaths.add(file.fullPath);
    return shouldSucceed;
  }

  @override
  Future<List<int>> downloadFile(CameraFile file) async => const <int>[];

  @override
  void dispose() {}
}

http.Client _makeMockClient() => fixedResponseClient(status: 204);

/// Minimal structurally valid JPEG (passes isCompleteCameraJpeg).
final Uint8List _validJpeg = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xD9]);

/// Responds to every request with a structurally valid JPEG, so loaded
/// previews really land in the in-memory cache.
http.Client _makeJpegClient() {
  return MockClient((_) async => http.Response.bytes(_validJpeg, 200));
}

/// JPEG client that records every requested URL (for asserting that cached
/// regions generate no camera traffic).
(http.Client, List<String>) _countingJpegClient() {
  final urls = <String>[];
  final client = MockClient((request) async {
    urls.add(request.url.toString());
    return http.Response.bytes(_validJpeg, 200);
  });
  return (client, urls);
}

CameraFile _file(String name) => CameraFile(
      directory: '/DCIM/100OLYMP',
      filename: name,
      size: 1024,
      attributes: 0,
      dateRaw: 0,
      timeRaw: 0,
      date: DateTime(2024, 6, 1, 12, 0),
    );

Future<void> _pumpPreview(
  WidgetTester tester, {
  required List<CameraFile> files,
  required int initialIndex,
  required CameraApi api,
  http.Client? httpClient,
  PreviewDownloadQueue? downloadQueue,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: PhotoPreviewScreen(
      file: files[initialIndex],
      files: files,
      initialIndex: initialIndex,
      api: api,
      httpClient: httpClient ?? _makeMockClient(),
      downloadQueue: downloadQueue,
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump();
}

Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('olympus_preview_test_');
    PathProviderPlatform.instance = FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({});
    await ImageDiskCache.instance.resetForTests();
    // Neighbor preloads gate on the background-download state; without this
    // mock the unmocked platform channel never answers inside fake async and
    // preloads never start. The same channel also serves DownloadHistory.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.flynew.photomanager/background_download'),
      (call) async {
        switch (call.method) {
          case 'getDownloadedKeys':
            return <String>[];
          case 'markDownloaded':
            return null;
          default:
            return false; // isRunning -> no downloads active
        }
      },
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.flynew.photomanager/background_download'),
      null,
    );
    debugDefaultTargetPlatformOverride = null;
    await ImageDiskCache.instance.resetForTests();
    if (await tmp.exists()) {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('initially shows the requested file in the header',
      (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    await _pumpPreview(
      tester,
      files: files,
      initialIndex: 1,
      api: _FakeApi(),
    );
    expect(find.text('B.JPG'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('does not mutate caller-supplied file list', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    final api = _FakeApi();
    await _pumpPreview(tester, files: files, initialIndex: 1, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(files.map((f) => f.filename), ['A.JPG', 'B.JPG', 'C.JPG']);
    expect(api.deletedPaths, ['/DCIM/100OLYMP/B.JPG']);
  });

  testWidgets(
      'after deleting the middle file, header shows the file now at that index',
      (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    final api = _FakeApi();
    await _pumpPreview(tester, files: files, initialIndex: 1, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(find.text('C.JPG'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('B.JPG'), findsNothing);
  });

  testWidgets('deleting the last file moves selection to the new last element',
      (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    final api = _FakeApi();
    await _pumpPreview(tester, files: files, initialIndex: 2, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(find.text('B.JPG'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('deleting the only file pops with true', (tester) async {
    final files = [_file('ONLY.JPG')];
    final api = _FakeApi();
    bool? popResult;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.of(ctx).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PhotoPreviewScreen(
                      file: files[0],
                      files: files,
                      initialIndex: 0,
                      api: api,
                      httpClient: _makeMockClient(),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(popResult, isTrue);
    expect(api.deletedPaths, ['/DCIM/100OLYMP/ONLY.JPG']);
  });

  testWidgets('failed delete keeps file in the list', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    final api = _FakeApi()..shouldSucceed = false;
    await _pumpPreview(tester, files: files, initialIndex: 1, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(find.text('B.JPG'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('swiping forward updates the header', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    await _pumpPreview(
      tester,
      files: files,
      initialIndex: 0,
      api: _FakeApi(),
    );
    expect(find.text('A.JPG'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await _settle(tester);

    expect(find.text('B.JPG'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('swipe back returns to the previous file', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG')];
    await _pumpPreview(
      tester,
      files: files,
      initialIndex: 1,
      api: _FakeApi(),
    );
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await _settle(tester);
    expect(find.text('A.JPG'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the file', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG')];
    final api = _FakeApi();
    await _pumpPreview(tester, files: files, initialIndex: 0, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    expect(api.deletedPaths, isEmpty);
    expect(find.text('A.JPG'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('downloads are queued across swipes and survive closing preview',
      (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG')];
    final finishA = Completer<void>();
    final finishB = Completer<void>();
    final started = <String>[];
    final queue = PreviewDownloadQueue(downloadAndSave: (file) async {
      started.add(file.filename);
      if (file.filename == 'A.JPG') {
        await finishA.future;
      } else {
        await finishB.future;
      }
    });
    await _pumpPreview(
      tester,
      files: files,
      initialIndex: 0,
      api: _FakeApi(),
      httpClient: _makeJpegClient(),
      downloadQueue: queue,
    );

    await tester.tap(find.byTooltip('Download'));
    await tester.pump();
    expect(started, ['A.JPG']);
    expect(queue.isQueued(files[0]), isTrue);

    final controller =
        tester.widget<PageView>(find.byType(PageView)).controller!;
    controller.jumpToPage(1);
    await tester.pump();
    await tester.tap(find.byTooltip('Download'));
    await tester.pump();

    expect(queue.queuedCount, 2);
    expect(started, ['A.JPG']);
    expect(queue.isQueued(files[1]), isTrue);

    // Closing the preview must not dispose the queue or its active download.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    finishA.complete();
    await tester.pump();
    await tester.pump();
    expect(started, ['A.JPG', 'B.JPG']);

    finishB.complete();
    await tester.pump();
    await tester.pump();
    await queue.whenIdle();
    expect(queue.isBusy, isFalse);
    expect(queue.completedKeys, containsAll(files.map((f) => f.downloadHistoryKey)));
  });

  testWidgets('downloaded file shows download-done marker in preview',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final file = _file('DONE.JPG');
      SharedPreferences.setMockInitialValues({
        'download_history_v1': <String>[file.downloadHistoryKey],
      });

      expect(await DownloadHistory.load(), contains(file.downloadHistoryKey));

      await _pumpPreview(
        tester,
        files: [file],
        initialIndex: 0,
        api: _FakeApi(),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.download_done), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets(
      'long overlapping paging session keeps the in-memory preview cache bounded',
      (tester) async {
    int cacheCount() => (tester.state(find.byType(PhotoPreviewScreen))
            as dynamic)
        .debugPreviewCacheCount as int;

    const bound = kPreviewKeepNeighbors * 2 + 4;
    final files =
        List.generate(40, (i) => _file('F${i.toString().padLeft(2, '0')}.JPG'));
    // An in-memory disk cache keeps loads inside the fake-async test zone
    // (real file I/O never completes there). Valid JPEG responses make every
    // visited frame land in the in-memory preview cache, so a missing
    // eviction shows up as unbounded growth across the session.
    final memCache = _MemDiskCache();
    final savedDiskCache = ImageDiskCache.instance;
    ImageDiskCache.instance = memCache;
    try {
      await _pumpPreview(
        tester,
        files: files,
        initialIndex: 0,
        api: _FakeApi(),
        httpClient: _makeJpegClient(),
      );

      final controller =
          tester.widget<PageView>(find.byType(PageView)).controller!;

      // Two paging modes interleave:
      //  - rapid steps (60ms) are faster than the 100ms neighbor-preload gate,
      //    so only visible frames accumulate — the exact pattern that leaked
      //    before the synchronous eviction fix;
      //  - settled steps (300ms) let the full ±3 window load, so the cache
      //    actually fills up and eviction must keep it bounded.
      // The bound is asserted at every step, not only at the end.
      const rapid = Duration(milliseconds: 30);
      const settled = Duration(milliseconds: 300);
      final sweep = <(int, Duration)>[
        for (var i = 1; i <= 8; i++) (i, rapid),
        for (var i = 9; i <= 15; i++) (i, settled),
        ...List.generate(3, (_) => (15, settled)),
        for (var i = 14; i >= 5; i--) (i, settled),
        ...List.generate(3, (_) => (5, settled)),
        for (var i = 6; i <= 10; i++) (i, rapid),
      ];
      var grewPastHalf = false;
      for (final (page, pause) in sweep) {
        controller.jumpToPage(page);
        await tester.pump(pause);
        await tester.pump(rapid);
        grewPastHalf |= cacheCount() > bound / 2;
        expect(cacheCount(), lessThanOrEqualTo(bound),
            reason: 'cache exceeded $bound at page $page');
      }
      // Flush the last step's neighbor-preload chain: its 100ms gate delay is
      // still pending, and flutter_test fails on timers left after disposal.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      // Sanity: frames really do land in the cache — without this the bound
      // above could pass on an empty cache.
      expect(grewPastHalf, isTrue,
          reason: 'no frames were cached; the bound check is vacuous');
      expect(cacheCount(), lessThanOrEqualTo(bound));
    } finally {
      ImageDiskCache.instance = savedDiskCache;
    }
  });

  testWidgets(
      're-browsing a large already-cached region serves previews entirely '
      'from disk (zero camera traffic)', (tester) async {
    int cacheCount() => (tester.state(find.byType(PhotoPreviewScreen))
            as dynamic)
        .debugPreviewCacheCount as int;

    final files =
        List.generate(40, (i) => _file('F${i.toString().padLeft(2, '0')}.JPG'));
    final memCache = _MemDiskCache();
    final savedDiskCache = ImageDiskCache.instance;
    ImageDiskCache.instance = memCache;
    try {
      // Big overlap: the first 20 frames are already cached from a previous
      // browse session — a full neighborhood around every page visited below.
      for (var i = 0; i < 20; i++) {
        await memCache.put(files[i].downloadHistoryKey, 'preview', _validJpeg);
      }

      final (client, urls) = _countingJpegClient();
      await _pumpPreview(
        tester,
        files: files,
        initialIndex: 10,
        api: _FakeApi(),
        httpClient: client,
      );

      final controller =
          tester.widget<PageView>(find.byType(PageView)).controller!;
      for (var page = 3; page <= 16; page++) {
        controller.jumpToPage(page);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 30));
        expect(cacheCount(), greaterThan(0),
            reason: 'page $page should render from the disk cache');
      }
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();

      expect(urls, isEmpty,
          reason:
              'a fully cached region must generate zero camera HTTP traffic');
    } finally {
      ImageDiskCache.instance = savedDiskCache;
    }
  });
}

/// In-memory stand-in for [ImageDiskCache]: completes synchronously inside
/// widget-test fake-async and never touches the filesystem.
class _MemDiskCache extends ImageDiskCache {
  _MemDiskCache() : super.forTesting();

  final _store = <String, Uint8List>{};

  String _key(String imagePath, String variant) => '${imagePath}__$variant';

  @override
  Future<Uint8List?> get(String imagePath, String variant) async =>
      _store[_key(imagePath, variant)];

  @override
  Future<void> put(String imagePath, String variant, Uint8List bytes) async {
    _store[_key(imagePath, variant)] = bytes;
  }

  @override
  Future<bool> has(String imagePath, String variant) async =>
      _store.containsKey(_key(imagePath, variant));
}
