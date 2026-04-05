import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/camera_api.dart';
import '../services/thumbnail_manager.dart';

class PhotoGrid extends StatefulWidget {
  final List<CameraFile> files;
  final bool gridView;
  final bool selectionMode;
  final Set<String> selectedPaths;
  final void Function(CameraFile) onTap;
  final void Function(CameraFile) onLongPress;
  final void Function(CameraFile, int)? onPreview;

  const PhotoGrid({
    super.key,
    required this.files,
    required this.gridView,
    required this.selectionMode,
    required this.selectedPaths,
    required this.onTap,
    required this.onLongPress,
    this.onPreview,
  });

  @override
  State<PhotoGrid> createState() => _PhotoGridState();
}

class _PhotoGridState extends State<PhotoGrid> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification ||
            notification is ScrollEndNotification) {
          _updateVisibleRange(notification);
        }
        return false;
      },
      child: widget.gridView ? _buildGrid() : _buildList(),
    );
  }

  void _updateVisibleRange(ScrollNotification notification) {
    final metrics = notification.metrics;
    // Approximate row height for grid (3 columns, aspect 0.8)
    final width = MediaQuery.of(context).size.width - 16; // padding
    final itemWidth = (width - 12) / 3; // 3 cols, 2 gaps of 6
    final itemHeight = itemWidth / 0.8 + 6; // aspect + spacing
    const columns = 3;
    final firstRow = (metrics.pixels / itemHeight).floor();
    final lastRow =
        ((metrics.pixels + metrics.viewportDimension) / itemHeight).ceil();
    final first = (firstRow * columns).clamp(0, widget.files.length);
    final last = (lastRow * columns).clamp(0, widget.files.length);
    ThumbnailManager.instance.updateVisibleRange(first, last);
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
        childAspectRatio: 0.8,
      ),
      itemCount: widget.files.length,
      itemBuilder: (ctx, i) => _GridItem(
        file: widget.files[i],
        index: i,
        selected: widget.selectedPaths.contains(widget.files[i].fullPath),
        selectionMode: widget.selectionMode,
        onTap: () => widget.onTap(widget.files[i]),
        onLongPress: () => widget.onLongPress(widget.files[i]),
        onPreview: widget.onPreview != null ? () => widget.onPreview!(widget.files[i], i) : null,
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: widget.files.length,
      itemBuilder: (ctx, i) => _ListItem(
        file: widget.files[i],
        index: i,
        selected: widget.selectedPaths.contains(widget.files[i].fullPath),
        selectionMode: widget.selectionMode,
        onTap: () => widget.onTap(widget.files[i]),
        onLongPress: () => widget.onLongPress(widget.files[i]),
        onPreview: widget.onPreview != null ? () => widget.onPreview!(widget.files[i], i) : null,
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final CameraFile file;
  final int index;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPreview;

  const _GridItem({
    required this.file,
    required this.index,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectionMode ? onTap : onPreview,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: const Color(0xFFE94560), width: 2)
              : null,
          color: selected
              ? const Color(0xFFE94560).withOpacity(0.15)
              : const Color(0xFF1A1A2E),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _CameraThumbnail(
                    url: file.thumbnailUrl,
                    index: index,
                    imagePath: file.fullPath,
                  ),
                  if (selected)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE94560),
                        ),
                        child: const Icon(Icons.check,
                            color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.filename,
                    style: const TextStyle(fontSize: 10, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    file.sizeHuman,
                    style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListItem extends StatelessWidget {
  final CameraFile file;
  final int index;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPreview;

  const _ListItem({
    required this.file,
    required this.index,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
    this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectionMode ? onTap : onPreview,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: selected
              ? Border.all(color: const Color(0xFFE94560), width: 1)
              : null,
          color: selected
              ? const Color(0xFFE94560).withOpacity(0.15)
              : const Color(0xFF1A1A2E),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: _CameraThumbnail(
                url: file.thumbnailUrl,
                index: index,
                imagePath: file.fullPath,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(file.filename,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      '${file.sizeHuman} · ${file.dateTimeStr}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      file.directory,
                      style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Container(
                width: 40,
                height: 72,
                color: const Color(0xFFE94560),
                child: const Icon(Icons.check, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}

/// Thumbnail widget that loads via ThumbnailManager (throttled, prioritized).
class _CameraThumbnail extends StatefulWidget {
  final String url;
  final int index;
  final String imagePath;
  final BoxFit fit;

  const _CameraThumbnail({
    required this.url,
    required this.index,
    this.imagePath = '',
    this.fit = BoxFit.cover,
  });

  @override
  State<_CameraThumbnail> createState() => _CameraThumbnailState();
}

class _CameraThumbnailState extends State<_CameraThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CameraThumbnail old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _loading = true;
      _error = false;
      _bytes = null;
      _load();
    }
  }

  Future<void> _load() async {
    final bytes = await ThumbnailManager.instance.load(
      widget.url, widget.index, imagePath: widget.imagePath);
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _error = bytes == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        color: const Color(0xFF252540),
        child:
            const Icon(Icons.broken_image, color: Colors.grey, size: 32),
      );
    }
    if (_loading || _bytes == null) {
      return Container(
        color: const Color(0xFF252540),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFE94560),
            ),
          ),
        ),
      );
    }
    return Image.memory(_bytes!, fit: widget.fit);
  }
}
