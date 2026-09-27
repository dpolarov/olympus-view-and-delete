import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_logger.dart';
import 'camera_api.dart' show cameraIp;
import 'camera_image_validator.dart';
import 'image_cache.dart';
import 'service_config.dart';

/// Manages thumbnail loading with concurrency limit and priority for visible items.
class ThumbnailManager {
  static final ThumbnailManager instance = ThumbnailManager._();
  ThumbnailManager._({http.Client? client})
      : _client = client ?? http.Client();

  /// Isolated manager with an injected [client] for tests only.
  /// Production code must use [instance].
  @visibleForTesting
  factory ThumbnailManager.forTesting({http.Client? client}) =>
      ThumbnailManager._(client: client);

  static const int _maxConcurrent = kMaxConcurrentThumbs;
  static const int _maxAttempts = 3;

  /// Max number of thumbnails kept in the in-memory LRU cache. Disk cache
  /// handles persistence; this just bounds RAM for very large libraries.
  static const int _maxMemCache = kMaxMemThumbs;

  /// Max total bytes kept in the in-memory cache (second RAM cap).
  static const int _maxMemBytes = kMaxMemThumbBytes;
  int _active = 0;
  int _generation = 0;
  int _networkPauseCount = 0;
  final List<_Request> _queue = [];
  // LinkedHashMap keeps insertion order — we use it for LRU by re-inserting
  // on access (see [load]).
  final Map<String, Uint8List> _cache = <String, Uint8List>{};
  // Running total of bytes held in [_cache], kept in sync on insert/evict.
  int _cacheBytes = 0;
  final Map<String, Completer<Uint8List?>> _inflight = {};
  final http.Client _client;

  int _visibleStart = 0;
  int _visibleEnd = 20;

  bool get _networkPaused => _networkPauseCount > 0;

  /// Update the currently visible item range so the queue can prioritize.
  void updateVisibleRange(int start, int end) {
    _visibleStart = start;
    _visibleEnd = end;
  }

  /// Pause starting new camera thumbnail HTTP requests.
  ///
  /// Pauses are reference-counted because full-screen preview and app lifecycle
  /// handling can overlap. Active requests may finish; if one fails while the
  /// network is paused, it is queued for retry instead of being reported as a
  /// permanent broken image.
  void pauseNetwork() {
    _networkPauseCount++;
  }

  /// Release one network pause. Queued work resumes only after every owner that
  /// paused thumbnail traffic has released its pause.
  void resumeNetwork() {
    if (_networkPauseCount == 0) return;
    _networkPauseCount--;
    if (_networkPaused) return;
    _processQueue();
  }

  /// Request a thumbnail. Returns cached data immediately if available.
  /// [imagePath] is a stable cache identity for the camera file.
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
    final request = _Request(
      url: url,
      index: index,
      completer: completer,
      imagePath: imagePath,
      generation: _generation,
      // No imagePath means there is no disk lookup to wait for.
      diskChecked: imagePath.isEmpty,
    );
    _queue.add(request);

    // Try disk cache first even while network traffic is paused. This lets
    // already-cached previews remain available after the camera Wi-Fi drops.
    if (imagePath.isNotEmpty) {
      unawaited(_tryDiskCache(request));
    } else {
      _processQueue();
    }
    return completer.future;
  }

  void _putInMemCache(String url, Uint8List bytes) {
    // If replacing an existing entry, drop its old size first.
    final previous = _cache.remove(url);
    if (previous != null) _cacheBytes -= previous.lengthInBytes;
    _cache[url] = bytes;
    _cacheBytes += bytes.lengthInBytes;
    // Evict oldest (LRU = first inserted) until within both caps. Keep at
    // least one entry so a single oversized thumbnail is still usable.
    while (_cache.length > 1 &&
        (_cache.length > _maxMemCache || _cacheBytes > _maxMemBytes)) {
      final oldestKey = _cache.keys.first;
      final removed = _cache.remove(oldestKey);
      if (removed != null) _cacheBytes -= removed.lengthInBytes;
    }
  }

  /// Number of thumbnails currently held in the in-memory cache.
  @visibleForTesting
  int get memCacheCount => _cache.length;

  /// Total bytes currently held in the in-memory cache.
  @visibleForTesting
  int get memCacheBytes => _cacheBytes;

  /// Test-only insertion into the in-memory LRU (bypasses the network).
  @visibleForTesting
  void debugPutInMemCache(String url, Uint8List bytes) =>
      _putInMemCache(url, bytes);

  Future<void> _tryDiskCache(_Request request) async {
    Uint8List? cached;
    try {
      cached = await ImageDiskCache.instance.get(request.imagePath, 'thumb');
    } catch (e) {
      AppLogger.debug(
        'thumb disk cache read failed: $e',
        name: 'thumbnail_manager',
      );
    } finally {
      // Always release the request into the queue, even on error — a failed
      // lookup must fall back to HTTP instead of stalling the completer.
      request.diskChecked = true;
    }

    if (request.generation != _generation) return;

    if (cached != null && isCompleteCameraJpeg(cached)) {
      _putInMemCache(request.url, cached);
      if (!request.completer.isCompleted) request.completer.complete(cached);
      _queue.removeWhere((r) => identical(r, request));
      if (_inflight[request.url] == request.completer) {
        _inflight.remove(request.url);
      }
      return;
    }

    if (cached != null) {
      AppLogger.debug(
        'discarding incomplete cached thumbnail for ${request.imagePath}',
        name: 'thumbnail_manager',
      );
    }
    _processQueue();
  }

  void _processQueue() {
    if (_networkPaused) return;
    // Drop requests that are very far from visible range.
    _queue.removeWhere((req) {
      if (_distToVisible(req.index) > 60) {
        if (!req.completer.isCompleted) req.completer.complete(null);
        if (_inflight[req.url] == req.completer) {
          _inflight.remove(req.url);
        }
        return true;
      }
      return false;
    });

    while (_active < _maxConcurrent && _queue.isNotEmpty) {
      // Sort: items closer to visible range first.
      _queue.sort(
          (a, b) => _distToVisible(a.index).compareTo(_distToVisible(b.index)));
      // Never start the HTTP fetch of a request whose disk-cache lookup has
      // not resolved yet: the disk read is cheap and, on a hit, makes the
      // fetch unnecessary — and a wasted slot starves the camera connection.
      final nextReady = _queue.indexWhere((req) => req.diskChecked);
      if (nextReady < 0) break;
      final req = _queue.removeAt(nextReady);
      _active++;
      unawaited(_fetch(req));
    }
  }

  int _distToVisible(int index) {
    if (index >= _visibleStart && index <= _visibleEnd) return 0;
    if (index < _visibleStart) return _visibleStart - index;
    return index - _visibleEnd;
  }

  Future<Uint8List?> _fetchValidBytes(String url) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final resp = await _client.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'OI.Share v2',
            'Host': cameraIp,
            'Connection': 'Keep-Alive',
          },
        ).timeout(kCameraRequestTimeout);

        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          final bytes = Uint8List.fromList(resp.bodyBytes);
          if (isCompleteCameraJpeg(
            bytes,
            expectedLength: resp.contentLength,
          )) {
            return bytes;
          }
          AppLogger.debug(
            'incomplete thumbnail response for $url '
            '(${bytes.lengthInBytes} bytes, attempt $attempt)',
            name: 'thumbnail_manager',
          );
        } else {
          AppLogger.debug(
            'thumbnail HTTP ${resp.statusCode} for $url (attempt $attempt)',
            name: 'thumbnail_manager',
          );
        }
      } catch (e) {
        AppLogger.debug(
          'thumbnail fetch failed for $url (attempt $attempt): $e',
          name: 'thumbnail_manager',
        );
      }

      // If the app/background lifecycle paused network traffic while this
      // request was already active, stop retrying on whatever Wi-Fi Android
      // switched to. _fetch() will park the request until the camera network is
      // verified again.
      if (_networkPaused) return null;

      if (attempt < _maxAttempts) {
        await Future.delayed(Duration(milliseconds: 150 * attempt));
      }
    }
    return null;
  }

  Future<void> _fetch(_Request req) async {
    var requeued = false;
    try {
      final bytes = await _fetchValidBytes(req.url);
      if (req.generation != _generation) return;

      if (bytes != null) {
        _putInMemCache(req.url, bytes);
        if (req.imagePath.isNotEmpty) {
          try {
            // A thumbnail is considered successfully loaded only after its
            // persistent cache write completes. If Android backgrounds the app
            // immediately afterwards, every image that was shown is already on
            // disk instead of relying on a best-effort fire-and-forget write.
            await ImageDiskCache.instance.put(req.imagePath, 'thumb', bytes);
          } catch (e) {
            AppLogger.debug(
              'thumb disk cache put failed: $e',
              name: 'thumbnail_manager',
            );
          }
        }
        if (!req.completer.isCompleted) req.completer.complete(bytes);
      } else if (_networkPaused && !req.completer.isCompleted) {
        _queue.add(req);
        requeued = true;
      } else if (!req.completer.isCompleted) {
        req.completer.complete(null);
      }
    } finally {
      _active--;
      if (_active < 0) _active = 0;
      if (!requeued && _inflight[req.url] == req.completer) {
        _inflight.remove(req.url);
      }
      _processQueue();
    }
  }

  /// Clear all in-memory cache and pending requests.
  ///
  /// Persistent disk-cached images are intentionally retained. Active HTTP
  /// calls are allowed to finish, but [_generation] prevents their old
  /// responses from entering a freshly reloaded gallery. We intentionally keep
  /// [_active] unchanged so old requests cannot make the concurrency counter
  /// negative when they complete.
  void clear() {
    _generation++;
    _cache.clear();
    _cacheBytes = 0;
    for (final req in _queue) {
      if (!req.completer.isCompleted) req.completer.complete(null);
    }
    _queue.clear();
    for (final c in _inflight.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _inflight.clear();
  }
}

class _Request {
  final String url;
  final int index;
  final String imagePath;
  final int generation;
  final Completer<Uint8List?> completer;

  /// True once this request's disk-cache lookup has resolved. The queue must
  /// not start the HTTP fetch of an unchecked request: doing so races the
  /// (cheap) disk read and can waste a scarce camera connection on data we
  /// already have on disk.
  bool diskChecked;

  _Request({
    required this.url,
    required this.index,
    required this.completer,
    required this.generation,
    this.imagePath = '',
    this.diskChecked = true,
  });
}
