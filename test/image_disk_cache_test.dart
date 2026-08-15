import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/image_cache.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_helpers.dart';

String _uniqueKey(String tag) =>
    '/test/${tag}_${DateTime.now().microsecondsSinceEpoch}.JPG';

Uint8List _bytes(int n, {int fill = 1}) =>
    Uint8List.fromList(List<int>.filled(n, fill));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('olympus_img_cache_test_');
    PathProviderPlatform.instance = FakePathProvider(tmp.path);
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
    expect(
        await ImageDiskCache.instance.get(_uniqueKey('miss'), 'thumb'), isNull);
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
    final firstKey = _uniqueKey('evict_first');
    await ImageDiskCache.instance.put(firstKey, 'thumb', _bytes(8));

    for (int i = 0; i < ImageDiskCache.maxImages; i++) {
      final k = _uniqueKey('evict_fill_$i');
      await ImageDiskCache.instance.put(k, 'thumb', _bytes(8));
    }

    expect(await ImageDiskCache.instance.get(firstKey, 'thumb'), isNull);
  });

  test('get touches LRU so the entry survives further evictions', () async {
    final target = _uniqueKey('touched');
    await ImageDiskCache.instance.put(target, 'thumb', _bytes(8));

    for (int i = 0; i < ImageDiskCache.maxImages + 5; i++) {
      if (i == 10) {
        await ImageDiskCache.instance.get(target, 'thumb');
      }
      final k = _uniqueKey('touch_fill_$i');
      await ImageDiskCache.instance.put(k, 'thumb', _bytes(8));
    }

    expect(await ImageDiskCache.instance.get(target, 'thumb'), isNotNull);
  });
}
