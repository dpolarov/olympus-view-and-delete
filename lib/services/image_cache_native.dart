import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_logger.dart';
import 'service_config.dart';

/// Persistent disk cache for camera images (thumbnails + previews).
/// Keeps the last [maxImages] images cached across all resolutions.
class ImageDiskCache {
  static final ImageDiskCache instance = ImageDiskCache._();
  ImageDiskCache._();

  static const int maxImages = kMaxCacheImages;
  static const String _lruKey = 'image_cache_lru';

  Directory? _cacheDir;
  List<String>? _lruList;
  Completer<void>? _initCompleter;
  Timer? _lruSaveTimer;

  Future<void> _ensureInit() {
    if (_cacheDir != null && _lruList != null) return Future.value();
    final existing = _initCompleter;
    if (existing != null) return existing.future;
    final c = Completer<void>();
    _initCompleter = c;
    () async {
      try {
        final appDir = await getApplicationCacheDirectory();
        _cacheDir = Directory('${appDir.path}/img_cache');
        if (!await _cacheDir!.exists()) {
          await _cacheDir!.create(recursive: true);
        }
        final prefs = await SharedPreferences.getInstance();
        _lruList = prefs.getStringList(_lruKey) ?? [];
        c.complete();
      } catch (e, st) {
        _initCompleter = null;
        c.completeError(e, st);
      }
    }();
    return c.future;
  }

  Future<void> _saveLru() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_lruKey, _lruList!);
  }

  void _scheduleLruSave() {
    _lruSaveTimer?.cancel();
    _lruSaveTimer = Timer(kLruSaveDebounce, () {
      _lruSaveTimer = null;
      _saveLru().catchError((Object e, StackTrace st) {
        AppLogger.warning('LRU save failed',
            name: 'image_cache', error: e, stackTrace: st);
      });
    });
  }

  String _fileName(String imagePath, String variant) {
    final safe = imagePath.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    return '${safe}__$variant';
  }

  Future<void> _touch(String imagePath) async {
    _lruList!.remove(imagePath);
    _lruList!.insert(0, imagePath);
    while (_lruList!.length > maxImages) {
      final evicted = _lruList!.removeLast();
      await _deleteAllVariants(evicted);
    }
    await _saveLru();
  }

  Future<void> _deleteAllVariants(String imagePath) async {
    for (final variant in ['thumb', 'preview']) {
      final file = File('${_cacheDir!.path}/${_fileName(imagePath, variant)}');
      if (await file.exists()) {
        try {
          await file.delete();
        } catch (e) {
          AppLogger.debug('failed to delete cache variant $variant: $e',
              name: 'image_cache');
        }
      }
    }
  }

  Future<Uint8List?> get(String imagePath, String variant) async {
    await _ensureInit();
    final file = File('${_cacheDir!.path}/${_fileName(imagePath, variant)}');
    if (await file.exists()) {
      _lruList!.remove(imagePath);
      _lruList!.insert(0, imagePath);
      _scheduleLruSave();
      return file.readAsBytes();
    }
    return null;
  }

  Future<void> put(String imagePath, String variant, Uint8List bytes) async {
    await _ensureInit();
    final file = File('${_cacheDir!.path}/${_fileName(imagePath, variant)}');
    await file.writeAsBytes(bytes, flush: true);
    await _touch(imagePath);
  }

  Future<bool> has(String imagePath, String variant) async {
    await _ensureInit();
    final file = File('${_cacheDir!.path}/${_fileName(imagePath, variant)}');
    return file.exists();
  }

  @visibleForTesting
  Future<void> resetForTests() async {
    _lruSaveTimer?.cancel();
    _lruSaveTimer = null;
    _cacheDir = null;
    _lruList = null;
    _initCompleter = null;
  }
}
