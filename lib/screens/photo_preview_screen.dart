import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/camera_api.dart';

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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadImage(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _client.close();
    super.dispose();
  }

  Future<void> _loadImage(int index) async {
    if (_imageCache.containsKey(index) || (_loading[index] ?? false)) return;
    setState(() {
      _loading[index] = true;
      _error[index] = false;
    });

    try {
      final file = widget.files[index];
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
        setState(() {
          _imageCache[index] = Uint8List.fromList(resp.bodyBytes);
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
    // Preload neighbors
    if (index > 0) _loadImage(index - 1);
    if (index < widget.files.length - 1) _loadImage(index + 1);
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
          const SizedBox(width: 16),
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
