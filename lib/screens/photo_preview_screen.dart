import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../services/app_logger.dart';
import '../services/camera_api.dart';
import '../services/camera_image_validator.dart';
import '../services/download_history.dart';
import '../services/file_saver.dart' as file_saver;
import '../services/image_cache.dart';
import '../services/service_config.dart';
import '../services/thumbnail_manager.dart';

/// Full-screen photo preview loaded via get_resizeimg (high quality).
class PhotoPreviewScreen extends StatefulWidget {
  final CameraFile file;
  final List<CameraFile> files;
  final int initialIndex;
  final CameraApi? api;
  final http.Client? httpClient;

  const PhotoPreviewScreen({
    super.key,
    required this.file,
    required this.files,
    required this.initialIndex,
    this.api,
    this.httpClient,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  static const int _keepNeighbors = kPreviewKeepNeighbors;
  static const int _maxPreviewAttempts = 3;
  static const int _priorityVisiblePreview = 0;
  static const int _priorityDownload = 1;
  static const int _priorityNeighborPreload = 2;

  late PageController _pageController;
  late int _currentIndex;
  late List<CameraFile> _files;
  final Set<String> _deletedPaths = {};
  final Map<String, Uint8List?> _imageCache = {};
  final Set<String> _loading = {};
  final Map<String, Future<void>> _loadFutures = {};
  final Set<String> _error = {};
  late final http.Client _client;
  late final bool _ownsClient;
  late final CameraApi _api;
  final _PreviewCameraQueue _cameraQueue = _PreviewCameraQueue();
  late final bool _ownsApi;
  bool _busy = false;
  Set<String> _downloadedKeys = <String>{};

  @override
  void initState() {
    super.initState();
    _ownsApi = widget.api == null;
    _api = widget.api ?? CameraApi();
    _ownsClient = widget.httpClient == null;
    _client = widget.httpClient ?? http.Client();
    _files = List.of(widget.files);
    _currentIndex = widget.initialIndex.clamp(0, _files.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    ThumbnailManager.instance.pauseNetwork();
    unawaited(_refreshDownloadedHistory());
    _loadAround(_currentIndex);
  }

  @override
  void dispose() {
    _cameraQueue.dispose();
    ThumbnailManager.instance.resumeNetwork();
    _pageController.dispose();
    if (_ownsClient) _client.close();
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  String _cacheKey(CameraFile file) => file.downloadHistoryKey;

  bool _isDownloaded(CameraFile file) =>
      _downloadedKeys.contains(file.downloadHistoryKey);

  Future<void> _refreshDownloadedHistory() async {
    final keys = await DownloadHistory.load();
    if (!mounted) return;
    setState(() => _downloadedKeys = keys);
  }

  void _loadAround(int index) {
    unawaited(_loadAroundPrioritized(index));
  }

  Future<void> _loadAroundPrioritized(int index) async {
    if (index < 0 || index >= _files.length) return;

    // Do not even enqueue neighbor network work until the visible frame has
    // finished (or failed). This makes the user's current screen deterministic.
    await _loadImage(index, priority: _priorityVisiblePreview);
    if (!mounted || index != _currentIndex) return;

    // Give an immediately requested Download a short chance to enter the queue
    // before low-priority neighbor preloads begin.
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted || index != _currentIndex || _busy) return;

    for (int d = 1; d <= _keepNeighbors; d++) {
      if (index - d >= 0) {
        unawaited(_loadImage(
          index - d,
          priority: _priorityNeighborPreload,
        ));
      }
      if (index + d < _files.length) {
        unawaited(_loadImage(
          index + d,
          priority: _priorityNeighborPreload,
        ));
      }
    }
    _evictFar(index);
  }

  void _evictFar(int index) {
    if (_imageCache.isEmpty) return;
    final keep = <String>{};
    final lo = (index - _keepNeighbors).clamp(0, _files.length - 1);
    final hi = (index + _keepNeighbors).clamp(0, _files.length - 1);
    for (int i = lo; i <= hi; i++) {
      keep.add(_cacheKey(_files[i]));
    }
    _imageCache.removeWhere((k, _) => !keep.contains(k));
  }

  Future<void> _downloadCurrent() async {
    final file = _files[_currentIndex];
    final key = _cacheKey(file);
    setState(() => _busy = true);
    try {
      // Highest priority is always the image the user is currently waiting to
      // see. If it is still pending, finish/promote it before starting the full
      // file download. Downloads then run ahead of all neighbor preloads.
      await _loadImage(
        _currentIndex,
        priority: _priorityVisiblePreview,
      );

      final bytes = await _cameraQueue.schedule(
        key: 'download:$key',
        priority: _priorityDownload,
        run: () async => Uint8List.fromList(await _api.downloadFile(file)),
      );
      if (bytes == null) throw StateError('Camera returned no file data');

      final saveDirPath = kIsWeb ? null : await file_saver.getSaveDirectory();
      await file_saver.saveFileToDevice(file.filename, bytes, saveDirPath);
      await DownloadHistory.mark(file.downloadHistoryKey);
      if (!mounted) return;

      setState(() {
        _downloadedKeys.add(key);
        _loading.remove(key);
        _error.remove(key);
        if (isCompleteCameraJpeg(bytes)) {
          // The downloaded original is also a valid full-screen preview. Reuse
          // it immediately rather than leaving a failed resize request spinning.
          _imageCache[key] = bytes;
        }
      });
      _loadAround(_currentIndex);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.download}: ${file.filename}')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading.remove(key);
        _error.remove(key);
      });
      unawaited(_loadImage(
        _currentIndex,
        priority: _priorityVisiblePreview,
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.download} failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCurrent() async {
    final file = _files[_currentIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kBackgroundColor,
        title: const Text(AppStrings.deleteFiles),
        content: Text(
          '${AppStrings.delete} ${file.filename} (${file.sizeHuman})?\n\nThis cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kErrorColor),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      final ok = await _api.deleteFile(file);
      if (!mounted) return;
      if (ok) {
        _deletedPaths.add(file.fullPath);
        final key = _cacheKey(file);
        _imageCache.remove(key);
        _loading.remove(key);
        _error.remove(key);
        _files.removeAt(_currentIndex);
        if (_files.isEmpty) {
          Navigator.pop(context, true);
          return;
        }
        final newIndex =
            _currentIndex >= _files.length ? _files.length - 1 : _currentIndex;
        setState(() {
          _currentIndex = newIndex;
          _busy = false;
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(newIndex);
        }
        _loadAround(newIndex);
      } else {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('${AppStrings.delete} failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.delete} failed: $e')),
        );
      }
    }
  }

  Future<Uint8List?> _fetchPreview(CameraFile file) async {
    final url = file.resizeImgUrl(kPreviewImageSize);
    for (var attempt = 1; attempt <= _maxPreviewAttempts; attempt++) {
      try {
        final resp = await _client.get(
          Uri.parse(url),
          headers: {
            'User-Agent': 'OI.Share v2',
            'Host': cameraIp,
            'Connection': 'Keep-Alive',
          },
        ).timeout(kPreviewLoadTimeout);

        if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
          final bytes = Uint8List.fromList(resp.bodyBytes);
          if (isCompleteCameraJpeg(
            bytes,
            expectedLength: resp.contentLength,
          )) {
            return bytes;
          }
          AppLogger.debug(
            'incomplete preview for ${file.fullPath} '
            '(${bytes.lengthInBytes} bytes, attempt $attempt)',
            name: 'photo_preview',
          );
        } else {
          AppLogger.debug(
            'preview HTTP ${resp.statusCode} for ${file.fullPath} '
            '(attempt $attempt)',
            name: 'photo_preview',
          );
        }
      } catch (e) {
        AppLogger.debug(
          'preview fetch failed for ${file.fullPath} '
          '(attempt $attempt): $e',
          name: 'photo_preview',
        );
      }

      if (attempt < _maxPreviewAttempts) {
        await Future.delayed(Duration(milliseconds: 200 * attempt));
      }
    }
    return null;
  }

  Future<void> _loadImage(
    int index, {
    required int priority,
  }) {
    if (index < 0 || index >= _files.length) return Future<void>.value();
    final file = _files[index];
    final key = _cacheKey(file);
    if (_imageCache.containsKey(key)) return Future<void>.value();

    final existing = _loadFutures[key];
    if (existing != null) {
      _cameraQueue.promote('preview:$key', priority);
      return existing;
    }

    late Future<void> future;
    future = _loadImageInternal(file, key, priority).whenComplete(() {
      if (identical(_loadFutures[key], future)) {
        _loadFutures.remove(key);
      }
    });
    _loadFutures[key] = future;
    return future;
  }

  Future<void> _loadImageInternal(
    CameraFile file,
    String key,
    int priority,
  ) async {
    if (mounted) {
      setState(() {
        _loading.add(key);
        _error.remove(key);
      });
    }

    try {
      final cached = await ImageDiskCache.instance.get(key, 'preview');
      if (!mounted) return;
      if (cached != null && isCompleteCameraJpeg(cached)) {
        setState(() {
          _imageCache[key] = cached;
          _loading.remove(key);
        });
        return;
      }
      if (cached != null) {
        AppLogger.debug(
          'discarding incomplete cached preview for ${file.fullPath}',
          name: 'photo_preview',
        );
      }

      final bytes = await _cameraQueue.schedule(
        key: 'preview:$key',
        priority: priority,
        run: () => _fetchPreview(file),
      );
      if (!mounted) return;
      if (bytes != null) {
        unawaited(ImageDiskCache.instance.put(key, 'preview', bytes).catchError(
              (Object e) => AppLogger.debug(
                'preview disk cache put failed: $e',
                name: 'photo_preview',
              ),
            ));
        setState(() {
          _imageCache[key] = bytes;
          _loading.remove(key);
        });
      } else {
        setState(() {
          _error.add(key);
          _loading.remove(key);
        });
      }
    } catch (e) {
      AppLogger.debug(
        'preview load failed for ${file.fullPath}: $e',
        name: 'photo_preview',
      );
      if (!mounted) return;
      setState(() {
        _error.add(key);
        _loading.remove(key);
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Promote the newly visible item over queued downloads/preloads.
    _loadAround(index);
    unawaited(_refreshDownloadedHistory());
  }

  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final file = _files[_currentIndex];
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black.withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _deletedPaths.isNotEmpty),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(file.filename, style: const TextStyle(fontSize: 14)),
              Text(
                '${file.sizeHuman} · ${file.dateTimeStr}',
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
          actions: [
            Text(
              '${_currentIndex + 1}/${_files.length}',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else ...[
              IconButton(
                icon: Icon(
                  _isDownloaded(file)
                      ? Icons.download_done
                      : Icons.download,
                  color: kAccentColor,
                ),
                tooltip: _isDownloaded(file)
                    ? 'Already downloaded · tap to download again'
                    : AppStrings.downloadTooltip,
                onPressed: _downloadCurrent,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: kErrorColor),
                tooltip: AppStrings.deleteTooltip,
                onPressed: _deleteCurrent,
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: _files.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final key = _cacheKey(_files[index]);
            final bytes = _imageCache[key];
            final isLoading = _loading.contains(key);
            final isError = _error.contains(key);

            if (isError && bytes == null) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image, color: Colors.grey, size: 64),
                    SizedBox(height: 12),
                    Text('Failed to load preview',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            if (isLoading && bytes == null) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        color: kPrimaryColor,
                        strokeWidth: 3,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Loading preview...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            if (bytes != null) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                    cacheWidth: kPreviewImageSize,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 64,
                      ),
                    ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class _PreviewCameraQueue {
  final List<_QueuedPreviewTask> _pending = <_QueuedPreviewTask>[];
  bool _running = false;
  bool _disposed = false;
  int _order = 0;

  Future<Uint8List?> schedule({
    required String key,
    required int priority,
    required Future<Uint8List?> Function() run,
  }) {
    if (_disposed) return Future<Uint8List?>.value(null);

    for (final task in _pending) {
      if (task.key == key) {
        if (priority < task.priority) task.priority = priority;
        return task.completer.future;
      }
    }

    final task = _QueuedPreviewTask(
      key: key,
      priority: priority,
      order: _order++,
      run: run,
    );
    _pending.add(task);
    unawaited(_drain());
    return task.completer.future;
  }

  void promote(String key, int priority) {
    for (final task in _pending) {
      if (task.key == key && priority < task.priority) {
        task.priority = priority;
        break;
      }
    }
  }

  Future<void> _drain() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (_pending.isNotEmpty && !_disposed) {
        _pending.sort((a, b) {
          final priorityCompare = a.priority.compareTo(b.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.order.compareTo(b.order);
        });
        final task = _pending.removeAt(0);
        try {
          final value = await task.run();
          if (!task.completer.isCompleted) task.completer.complete(value);
        } catch (error, stackTrace) {
          if (!task.completer.isCompleted) {
            task.completer.completeError(error, stackTrace);
          }
        }
      }
    } finally {
      _running = false;
      if (_pending.isNotEmpty && !_disposed) unawaited(_drain());
    }
  }

  void dispose() {
    _disposed = true;
    for (final task in _pending) {
      if (!task.completer.isCompleted) task.completer.complete(null);
    }
    _pending.clear();
  }
}

class _QueuedPreviewTask {
  _QueuedPreviewTask({
    required this.key,
    required this.priority,
    required this.order,
    required this.run,
  });

  final String key;
  int priority;
  final int order;
  final Future<Uint8List?> Function() run;
  final Completer<Uint8List?> completer = Completer<Uint8List?>();
}
