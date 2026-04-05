import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent disk cache for camera images (thumbnails + previews).
/// Keeps the last [maxImages] images cached across all resolutions.
/// Each image key is the file's fullPath (e.g. /DCIM/100OLYMP/P1010001.JPG).
/// Cached variants: 'thumb', 'preview' (resizeimg 1920).
class ImageDiskCache {
  static final ImageDiskCache instance = ImageDiskCache._();
  ImageDiskCache._();

  static const int maxImages = 150;
  static const String _lruKey = 'image_cache_lru';

  Directory? _cacheDir;
  List<String>? _lruList; // most recent first

  Future<void> _ensureInit() async {
    if (_cacheDir != null && _lruList != null) return;
    final appDir = await getApplicationCacheDirectory();
    _cacheDir = Directory('${appDir.path}/img_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    final prefs = await SharedPreferences.getInstance();
    _lruList = prefs.getStringList(_lruKey) ?? [];
  }

  Future<void> _saveLru() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_lruKey, _lruList!);
  }

  /// Generate a safe filename from image path + variant.
  String _fileName(String imagePath, String variant) {
    // e.g. /DCIM/100OLYMP/P1010001.JPG -> DCIM_100OLYMP_P1010001.JPG
    final safe = imagePath.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
    return '${safe}__$variant';
  }

  /// Touch an image key in LRU (move to front), evict old ones.
  Future<void> _touch(String imagePath) async {
    _lruList!.remove(imagePath);
    _lruList!.insert(0, imagePath);

    // Evict oldest beyond maxImages
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
        } catch (_) {}
      }
    }
  }

  /// Get cached image bytes, or null if not cached.
  Future<Uint8List?> get(String imagePath, String variant) async {
    await _ensureInit();
    final file = File('${_cacheDir!.path}/${_fileName(imagePath, variant)}');
    if (await file.exists()) {
      // Touch LRU without evicting (just move to front)
      _lruList!.remove(imagePath);
      _lruList!.insert(0, imagePath);
      // Save LRU occasionally (not every read for perf)
      return await file.readAsBytes();
    }
    return null;
  }

  /// Store image bytes to disk cache.
  Future<void> put(String imagePath, String variant, Uint8List bytes) async {
    await _ensureInit();
    final file = File('${_cacheDir!.path}/${_fileName(imagePath, variant)}');
    await file.writeAsBytes(bytes, flush: true);
    await _touch(imagePath);
  }

  /// Check if a variant is cached.
  Future<bool> has(String imagePath, String variant) async {
    await _ensureInit();
    final file = File('${_cacheDir!.path}/${_fileName(imagePath, variant)}');
    return file.exists();
  }
}
