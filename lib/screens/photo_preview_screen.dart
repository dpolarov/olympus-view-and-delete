import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../constants.dart';
import '../services/app_logger.dart';
import '../services/camera_api.dart';
import '../services/file_saver.dart' as file_saver;
import '../services/image_cache.dart';
import '../services/service_config.dart';

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

  late PageController _pageController;
  late int _currentIndex;
  late List<CameraFile> _files;
  final Set<String> _deletedPaths = {};
  final Map<String, Uint8List?> _imageCache = {};
  final Set<String> _loading = {};
  final Set<String> _error = {};
  late final http.Client _client;
  late final bool _ownsClient;
  late final CameraApi _api;
  late final bool _ownsApi;
  bool _busy = false;

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
    _loadAround(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    if (_ownsClient) _client.close();
    if (_ownsApi) _api.dispose();
    super.dispose();
  }

  void _loadAround(int index) {
    if (index < 0 || index >= _files.length) return;
    _loadImage(index);
    for (int d = 1; d <= _keepNeighbors; d++) {
      if (index - d >= 0) _loadImage(index - d);
      if (index + d < _files.length) _loadImage(index + d);
    }
    _evictFar(index);
  }

  void _evictFar(int index) {
    if (_imageCache.isEmpty) return;
    final keep = <String>{};
    final lo = (index - _keepNeighbors).clamp(0, _files.length - 1);
    final hi = (index + _keepNeighbors).clamp(0, _files.length - 1);
    for (int i = lo; i <= hi; i++) {
      keep.add(_files[i].fullPath);
    }
    _imageCache.removeWhere((k, _) => !keep.contains(k));
  }

  Future<void> _downloadCurrent() async {
    final file = _files[_currentIndex];
    setState(() => _busy = true);
    try {
      final bytes = await _api.downloadFile(file);
      final saveDirPath = kIsWeb ? null : await file_saver.getSaveDirectory();
      await file_saver.saveFileToDevice(file.filename, bytes, saveDirPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.download}: ${file.filename}')),
      );
    } catch (e) {
      if (!mounted) return;
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
        _imageCache.remove(file.fullPath);
        _loading.remove(file.fullPath);
        _error.remove(file.fullPath);
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

  Future<void> _loadImage(int index) async {
    if (index < 0 || index >= _files.length) return;
    final file = _files[index];
    final key = file.fullPath;
    if (_imageCache.containsKey(key) || _loading.contains(key)) return;
    setState(() {
      _loading.add(key);
      _error.remove(key);
    });

    try {
      final cached = await ImageDiskCache.instance.get(key, 'preview');
      if (!mounted) return;
      if (cached != null) {
        setState(() {
          _imageCache[key] = cached;
          _loading.remove(key);
        });
        return;
      }

      final url = file.resizeImgUrl(kPreviewImageSize);
      final resp = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'OI.Share v2',
          'Host': cameraIp,
          'Connection': 'Keep-Alive',
        },
      ).timeout(kPreviewLoadTimeout);

      if (!mounted) return;
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final bytes = Uint8List.fromList(resp.bodyBytes);
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error.add(key);
        _loading.remove(key);
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _loadAround(index);
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
                icon: const Icon(Icons.download, color: kAccentColor),
                tooltip: AppStrings.downloadTooltip,
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
            final key = _files[index].fullPath;
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
