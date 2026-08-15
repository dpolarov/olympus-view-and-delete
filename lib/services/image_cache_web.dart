import 'package:flutter/foundation.dart';

import 'service_config.dart';

/// Browser-safe in-memory image cache.
class ImageDiskCache {
  static final ImageDiskCache instance = ImageDiskCache._();
  ImageDiskCache._();

  static const int maxImages = kMaxCacheImages;

  final Map<String, Uint8List> _items = <String, Uint8List>{};
  final List<String> _lruImages = <String>[];

  String _key(String imagePath, String variant) => '$imagePath::$variant';

  void _touch(String imagePath) {
    _lruImages.remove(imagePath);
    _lruImages.insert(0, imagePath);

    while (_lruImages.length > maxImages) {
      final evicted = _lruImages.removeLast();
      _items.removeWhere((key, _) => key.startsWith('$evicted::'));
    }
  }

  Future<Uint8List?> get(String imagePath, String variant) async {
    final value = _items[_key(imagePath, variant)];
    if (value != null) _touch(imagePath);
    return value;
  }

  Future<void> put(String imagePath, String variant, Uint8List bytes) async {
    _items[_key(imagePath, variant)] = bytes;
    _touch(imagePath);
  }

  Future<bool> has(String imagePath, String variant) async {
    return _items.containsKey(_key(imagePath, variant));
  }

  @visibleForTesting
  Future<void> resetForTests() async {
    _items.clear();
    _lruImages.clear();
  }
}
