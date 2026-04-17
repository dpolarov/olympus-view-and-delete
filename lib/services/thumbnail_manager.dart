import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'camera_api.dart' show cameraIp;
import 'image_cache.dart';

/// Manages thumbnail loading with concurrency limit and priority for visible items.
class ThumbnailManager {
  static final ThumbnailManager instance = ThumbnailManager._();
  ThumbnailManager._();

  static const int _maxConcurrent = 3;
  /// Max number of thumbnails kept in the in-memory LRU cache. Disk cache
  /// handles persistence; this just bounds RAM for very large libraries.
  static const int _maxMemCache = 300;
  int _active = 0;
  final List<_Request> _queue = [];
  // LinkedHashMap keeps insertion order — we use it for LRU by re-inserting
  // on access (see [load]).
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  final Map<String, Completer<Uint8List?>> _inflight = {};
  final http.Client _client = http.Client();

  int _visibleStart = 0;
  int _visibleEnd = 20;

  /// Update the currently visible item range so the queue can prioritize.
  void updateVisibleRange(int start, int end) {
    _visibleStart = start;
    _visibleEnd = end;
  }

  /// Request a thumbnail. Returns cached data immediately if available.
  /// [imagePath] is the camera file path (e.g. /DCIM/100OLYMP/P1010001.JPG)
  Future<Uint8List?> load(String url, int index, {String imagePath = ''}) {
    final cached = _cache.remove(url);
    if (cached != null) {
      // Re-insert to move to MRU end.
      _cache[url] = cached;
      return Future.value(cached);
    }
    if (_inflight.containsKey(url)) {
      return _inflight[url]!.future;
    }

    final completer = Completer<Uint8List?>();
    _inflight[url] = completer;
    _queue.add(_Request(url: url, index: index, completer: completer, imagePath: imagePath));
    // Try disk cache first
    if (imagePath.isNotEmpty) {
      _tryDiskCache(url, imagePath, completer);
    } else {
      _processQueue();
    }
    return completer.future;
  }

  void _putInMemCache(String url, Uint8List bytes) {
    _cache[url] = bytes;
    // Evict oldest (LRU = first inserted) until within cap.
    while (_cache.length > _maxMemCache) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<void> _tryDiskCache(String url, String imagePath, Completer<Uint8List?> completer) async {
    final cached = await ImageDiskCache.instance.get(imagePath, 'thumb');
    if (cached != null) {
      _putInMemCache(url, cached);
      if (!completer.isCompleted) completer.complete(cached);
      _queue.removeWhere((r) => r.url == url);
      _inflight.remove(url);
      return;
    }
    _processQueue();
  }

  void _processQueue() {
    // Drop requests that are very far from visible range
    _queue.removeWhere((req) {
      if (_distToVisible(req.index) > 60) {
        if (!req.completer.isCompleted) req.completer.complete(null);
        _inflight.remove(req.url);
        return true;
      }
      return false;
    });

    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      // Sort: items closer to visible range first
      _queue.sort((a, b) =>
          _distToVisible(a.index).compareTo(_distToVisible(b.index)));
      final req = _queue.removeAt(0);
      _active++;
      _fetch(req);
    }
  }

  int _distToVisible(int index) {
    if (index >= _visibleStart && index <= _visibleEnd) return 0;
    if (index < _visibleStart) return _visibleStart - index;
    return index - _visibleEnd;
  }

  Future<void> _fetch(_Request req) async {
    try {
      final resp = await _client.get(
        Uri.parse(req.url),
        headers: {
          'User-Agent': 'OI.Share v2',
          'Host': cameraIp,
          'Connection': 'Keep-Alive',
        },
      ).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final bytes = Uint8List.fromList(resp.bodyBytes);
        _putInMemCache(req.url, bytes);
        if (req.imagePath.isNotEmpty) {
          ImageDiskCache.instance
              .put(req.imagePath, 'thumb', bytes)
              .catchError((_) {});
        }
        if (!req.completer.isCompleted) req.completer.complete(bytes);
      } else {
        if (!req.completer.isCompleted) req.completer.complete(null);
      }
    } catch (_) {
      if (!req.completer.isCompleted) req.completer.complete(null);
    } finally {
      _active--;
      _inflight.remove(req.url);
      _processQueue();
    }
  }

  /// Clear all cache and pending requests.
  void clear() {
    _cache.clear();
    for (final req in _queue) {
      if (!req.completer.isCompleted) req.completer.complete(null);
    }
    _queue.clear();
    for (final c in _inflight.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _inflight.clear();
    _active = 0;
  }
}

class _Request {
  final String url;
  final int index;
  final String imagePath;
  final Completer<Uint8List?> completer;
  _Request({required this.url, required this.index, required this.completer, this.imagePath = ''});
}
