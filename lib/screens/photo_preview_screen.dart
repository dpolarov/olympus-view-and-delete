import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../services/camera_api.dart';
import '../services/image_cache.dart';
import '../services/file_saver.dart' as file_saver;

/// Full-screen photo preview loaded via get_resizeimg (high quality).
class PhotoPreviewScreen extends StatefulWidget {
  final CameraFile file;
  final List<CameraFile> files;
  final int initialIndex;

  const PhotoPreviewScreen({
    super.key,
    required this.file,
    required this.files,
    required this.initialIndex,
  });

  @override
  State<PhotoPreviewScreen> createState() => _PhotoPreviewScreenState();
}

class _PhotoPreviewScreenState extends State<PhotoPreviewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  final Map<int, Uint8List?> _imageCache = {};
  final Map<int, bool> _loading = {};
  final Map<int, bool> _error = {};
  final http.Client _client = http.Client();
  final CameraApi _api = CameraApi();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadImage(_currentIndex);
    for (int d = 1; d <= 2; d++) {
      if (_currentIndex - d >= 0) _loadImage(_currentIndex - d);
      if (_currentIndex + d < widget.files.length) _loadImage(_currentIndex + d);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _client.close();
    _api.dispose();
    super.dispose();
  }

  Future<void> _downloadCurrent() async {
    final file = widget.files[_currentIndex];
    setState(() => _busy = true);
    try {
      final bytes = await _api.downloadFile(file);
      final saveDirPath = kIsWeb ? null : await file_saver.getSaveDirectory();
      await file_saver.saveFileToDevice(file.filename, bytes, saveDirPath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved: ${file.filename}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteCurrent() async {
    final file = widget.files[_currentIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Delete File'),
        content: Text('Delete ${file.filename} (${file.sizeHuman})?\n\nThis cannot be undone!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
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
        widget.files.removeAt(_currentIndex);
        if (widget.files.isEmpty) {
          Navigator.pop(context, true);
          return;
        }
        if (_currentIndex >= widget.files.length) {
          _currentIndex = widget.files.length - 1;
        }
        _imageCache.remove(_currentIndex);
        setState(() => _busy = false);
        _loadImage(_currentIndex);
      } else {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Delete failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    }
  }

  Future<void> _loadImage(int index) async {
    if (_imageCache.containsKey(index) || (_loading[index] ?? false)) return;
    setState(() {
      _loading[index] = true;
      _error[index] = false;
    });

    try {
      final file = widget.files[index];

      // Try disk cache first
      final cached = await ImageDiskCache.instance.get(file.fullPath, 'preview');
      if (cached != null) {
        if (!mounted) return;
        setState(() {
          _imageCache[index] = cached;
          _loading[index] = false;
        });
        return;
      }

      final url = file.resizeImgUrl(1920);
      final resp = await _client.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'OI.Share v2',
          'Host': cameraIp,
          'Connection': 'Keep-Alive',
        },
      ).timeout(const Duration(seconds: 30));

      if (!mounted) return;
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        final bytes = Uint8List.fromList(resp.bodyBytes);
        ImageDiskCache.instance.put(file.fullPath, 'preview', bytes);
        setState(() {
          _imageCache[index] = bytes;
          _loading[index] = false;
        });
      } else {
        setState(() {
          _error[index] = true;
          _loading[index] = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error[index] = true;
        _loading[index] = false;
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _loadImage(index);
    // Preload ±2 neighbors for smooth swiping
    for (int d = 1; d <= 2; d++) {
      if (index - d >= 0) _loadImage(index - d);
      if (index + d < widget.files.length) _loadImage(index + d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = widget.files[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.7),
        foregroundColor: Colors.white,
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
            '${_currentIndex + 1}/${widget.files.length}',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.download, color: Color(0xFF2ECC71)),
              tooltip: 'Download',
              onPressed: _downloadCurrent,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete',
              onPressed: _deleteCurrent,
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.files.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final bytes = _imageCache[index];
          final isLoading = _loading[index] ?? false;
          final isError = _error[index] ?? false;

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
                      color: Color(0xFFE94560),
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
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
