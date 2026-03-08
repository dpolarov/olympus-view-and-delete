import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'camera_api.dart' show cameraIp;

/// Manages thumbnail loading with concurrency limit and priority for visible items.
class ThumbnailManager {
  static final ThumbnailManager instance = ThumbnailManager._();
  ThumbnailManager._();

  static const int _maxConcurrent = 3;
  int _active = 0;
  final List<_Request> _queue = [];
  final Map<String, Uint8List> _cache = {};
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
  Future<Uint8List?> load(String url, int index) {
    if (_cache.containsKey(url)) {
      return Future.value(_cache[url]);
    }
    if (_inflight.containsKey(url)) {
      return _inflight[url]!.future;
    }

    final completer = Completer<Uint8List?>();
    _inflight[url] = completer;
    _queue.add(_Request(url: url, index: index, completer: completer));
    _processQueue();
    return completer.future;
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
        _cache[req.url] = bytes;
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
  final Completer<Uint8List?> completer;
  _Request({required this.url, required this.index, required this.completer});
}
