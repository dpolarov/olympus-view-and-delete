import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:olympus_tg6_manager/services/image_cache.dart';

/// Minimal path_provider mock that routes application cache to a temp dir.
class _FakePathProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationCachePath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
}

/// [ImageDiskCache] is a singleton — we can't instantiate fresh instances
/// between tests. Use unique keys per test to keep them isolated.
String _uniqueKey(String tag) =>
    '/test/${tag}_${DateTime.now().microsecondsSinceEpoch}.JPG';

Uint8List _bytes(int n, {int fill = 1}) =>
    Uint8List.fromList(List<int>.filled(n, fill));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('olympus_img_cache_test_');
    PathProviderPlatform.instance = _FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({});
    await ImageDiskCache.instance.resetForTests();
  });

  tearDown(() async {
    await ImageDiskCache.instance.resetForTests();
    if (await tmp.exists()) {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  });

  test('put then get round-trips bytes', () async {
    final key = _uniqueKey('roundtrip');
    final data = _bytes(64, fill: 7);
    await ImageDiskCache.instance.put(key, 'thumb', data);
    final read = await ImageDiskCache.instance.get(key, 'thumb');
    expect(read, isNotNull);
    expect(read!, equals(data));
  });

  test('get returns null when not cached', () async {
    expect(await ImageDiskCache.instance.get(_uniqueKey('miss'), 'thumb'),
        isNull);
  });

  test('has reports presence correctly', () async {
    final key = _uniqueKey('has');
    expect(await ImageDiskCache.instance.has(key, 'thumb'), isFalse);
    await ImageDiskCache.instance.put(key, 'thumb', _bytes(16));
    expect(await ImageDiskCache.instance.has(key, 'thumb'), isTrue);
    expect(await ImageDiskCache.instance.has(key, 'preview'), isFalse);
  });

  test('thumb and preview variants are stored separately', () async {
    final key = _uniqueKey('variants');
    final thumb = _bytes(10, fill: 1);
    final preview = _bytes(20, fill: 2);
    await ImageDiskCache.instance.put(key, 'thumb', thumb);
    await ImageDiskCache.instance.put(key, 'preview', preview);
    expect(await ImageDiskCache.instance.get(key, 'thumb'), equals(thumb));
    expect(await ImageDiskCache.instance.get(key, 'preview'), equals(preview));
  });

  test('exceeding maxImages evicts oldest key and deletes files', () async {
    // Seed exactly maxImages entries, then add one more and verify the first
    // one is gone from disk.
    final firstKey = _uniqueKey('evict_first');
    await ImageDiskCache.instance.put(firstKey, 'thumb', _bytes(8));

    // Fill up to the cap minus what we just inserted.
    for (int i = 0; i < ImageDiskCache.maxImages; i++) {
      final k = _uniqueKey('evict_fill_$i');
      await ImageDiskCache.instance.put(k, 'thumb', _bytes(8));
    }

    // After one more insert beyond the cap, the first (oldest) must be gone.
    expect(await ImageDiskCache.instance.get(firstKey, 'thumb'), isNull);
  });

  test('get touches LRU so the entry survives further evictions', () async {
    final target = _uniqueKey('touched');
    await ImageDiskCache.instance.put(target, 'thumb', _bytes(8));

    // Fill past the cap, but touch `target` after the first few writes so it
    // moves to the MRU end.
    for (int i = 0; i < ImageDiskCache.maxImages + 5; i++) {
      if (i == 10) {
        await ImageDiskCache.instance.get(target, 'thumb'); // touch
      }
      final k = _uniqueKey('touch_fill_$i');
      await ImageDiskCache.instance.put(k, 'thumb', _bytes(8));
    }

    // With the touch at i=10, `target` should no longer be the oldest.
    expect(await ImageDiskCache.instance.get(target, 'thumb'), isNotNull);
  });
}
