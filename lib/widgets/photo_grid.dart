import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/olympus_theme.dart';

import '../constants.dart';
import '../services/camera_api.dart';
import '../services/thumbnail_manager.dart';

BoxDecoration _itemDecoration({
  required bool selected,
  required bool downloaded,
  required double borderWidth,
}) {
  final borderColor = selected
      ? OlympusPalette.coral
      : downloaded
          ? OlympusPalette.success
          : OlympusPalette.border;
  return BoxDecoration(
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: borderColor,
      width: selected ? borderWidth : 0.8,
    ),
    color: selected
        ? OlympusPalette.coral.withValues(alpha: 0.11)
        : downloaded
            ? OlympusPalette.success.withValues(alpha: 0.055)
            : OlympusPalette.card,
  );
}

class PhotoGrid extends StatefulWidget {
  final List<CameraFile> files;
  final bool gridView;
  final bool selectionMode;
  final Set<String> selectedPaths;
  final Set<String> downloadedKeys;
  final void Function(CameraFile) onTap;
  final void Function(CameraFile) onLongPress;
  final void Function(CameraFile, int)? onPreview;

  const PhotoGrid({
    super.key,
    required this.files,
    required this.gridView,
    required this.selectionMode,
    required this.selectedPaths,
    required this.downloadedKeys,
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
    final columns = _columnCount(MediaQuery.sizeOf(context).width);
    final width = MediaQuery.sizeOf(context).width - 24;
    final itemWidth = (width - (columns - 1) * 8) / columns;
    final itemHeight = itemWidth / 0.8 + 8;
    final firstRow = (metrics.pixels / itemHeight).floor();
    final lastRow =
        ((metrics.pixels + metrics.viewportDimension) / itemHeight).ceil();
    final first = (firstRow * columns).clamp(0, widget.files.length);
    final last = (lastRow * columns).clamp(0, widget.files.length);
    ThumbnailManager.instance.updateVisibleRange(first, last);
  }

  int _columnCount(double width) {
    if (width >= 1100) return 6;
    if (width >= 780) return 5;
    if (width >= 520) return 4;
    return 3;
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _columnCount(MediaQuery.sizeOf(context).width),
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: widget.files.length,
      itemBuilder: (ctx, i) => _GridItem(
        file: widget.files[i],
        index: i,
        selected: widget.selectedPaths.contains(widget.files[i].fullPath),
        downloaded: widget.downloadedKeys.contains(
          widget.files[i].downloadHistoryKey,
        ),
        selectionMode: widget.selectionMode,
        onTap: () => widget.onTap(widget.files[i]),
        onLongPress: () => widget.onLongPress(widget.files[i]),
        onPreview: widget.onPreview != null
            ? () => widget.onPreview!(widget.files[i], i)
            : null,
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.files.length,
      itemBuilder: (ctx, i) => _ListItem(
        file: widget.files[i],
        index: i,
        selected: widget.selectedPaths.contains(widget.files[i].fullPath),
        downloaded: widget.downloadedKeys.contains(
          widget.files[i].downloadHistoryKey,
        ),
        selectionMode: widget.selectionMode,
        onTap: () => widget.onTap(widget.files[i]),
        onLongPress: () => widget.onLongPress(widget.files[i]),
        onPreview: widget.onPreview != null
            ? () => widget.onPreview!(widget.files[i], i)
            : null,
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final CameraFile file;
  final int index;
  final bool selected;
  final bool downloaded;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPreview;

  const _GridItem({
    required this.file,
    required this.index,
    required this.selected,
    required this.downloaded,
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
        decoration: _itemDecoration(
          selected: selected,
          downloaded: downloaded,
          borderWidth: 2,
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
                    url: file.resizeImgUrl(1024),
                    fallbackUrl: file.thumbnailUrl,
                    index: index,
                    // Large grid tiles use a camera-supported 1024 px preview
                    // instead of stretching the tiny 160x120 thumbnail.
                    // Version the cache identity so older low-resolution or
                    // invalid 480-preview entries are never reused.
                    imagePath: '${file.downloadHistoryKey}|grid1024',
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
                          color: kPrimaryColor,
                        ),
                        child: const Icon(Icons.check,
                            color: OlympusPalette.onCoral, size: 16),
                      ),
                    ),
                  if (downloaded)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: OlympusPalette.success,
                        ),
                        child: const Icon(
                          Icons.download_done,
                          color: OlympusPalette.background,
                          size: 15,
                        ),
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
                    style: const TextStyle(
                      fontSize: 11, color: OlympusPalette.text),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    file.sizeHuman,
                    style: const TextStyle(
                      fontSize: 10, color: OlympusPalette.mutedText),
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
  final bool downloaded;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onPreview;

  const _ListItem({
    required this.file,
    required this.index,
    required this.selected,
    required this.downloaded,
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
        decoration: _itemDecoration(
          selected: selected,
          downloaded: downloaded,
          borderWidth: 1,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: _CameraThumbnail(
                url: file.thumbnailUrl,
                fallbackUrl: file.resizeImgUrl(1024),
                index: index,
                imagePath: file.downloadHistoryKey,
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
                      style: const TextStyle(
                        fontSize: 12, color: OlympusPalette.secondaryText),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      file.directory,
                      style: const TextStyle(
                        fontSize: 11, color: OlympusPalette.mutedText),
                    ),
                  ],
                ),
              ),
            ),
            if (selected)
              Container(
                width: 40,
                height: 72,
                color: kPrimaryColor,
                child: const Icon(Icons.check, color: OlympusPalette.onCoral),
              ),
            if (!selected && downloaded)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.download_done,
                  color: OlympusPalette.success,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraThumbnail extends StatefulWidget {
  final String url;
  final String fallbackUrl;
  final int index;
  final String imagePath;
  final BoxFit fit;

  const _CameraThumbnail({
    required this.url,
    required this.fallbackUrl,
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
  int _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CameraThumbnail old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url ||
        old.fallbackUrl != widget.fallbackUrl ||
        old.imagePath != widget.imagePath) {
      setState(() {
        _loading = true;
        _error = false;
        _bytes = null;
      });
      _load();
    }
  }

  Future<void> _load() async {
    final token = ++_loadToken;
    var bytes = await ThumbnailManager.instance
        .load(widget.url, widget.index, imagePath: widget.imagePath);

    // Some camera firmwares occasionally fail the preferred image endpoint for
    // a single file. Fall back to the alternate endpoint instead of leaving a
    // permanent broken tile. Do not write fallback bytes into the preferred
    // disk-cache identity: a transient failure must not make a low-resolution
    // fallback persist across future launches.
    if (bytes == null && widget.fallbackUrl != widget.url) {
      bytes = await ThumbnailManager.instance.load(
        widget.fallbackUrl,
        widget.index,
      );
    }

    if (!mounted || token != _loadToken) return;
    setState(() {
      _bytes = bytes;
      _loading = false;
      _error = bytes == null;
    });
  }

  Widget _brokenImage() {
    return Container(
      color: OlympusPalette.raised,
      child: const Icon(Icons.broken_image, color: Colors.grey, size: 32),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return _brokenImage();
    if (_loading || _bytes == null) {
      return Container(
        color: OlympusPalette.raised,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: OlympusPalette.coral,
            ),
          ),
        ),
      );
    }
    return Image.memory(
      _bytes!,
      fit: widget.fit,
      cacheWidth: 1024,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _brokenImage(),
    );
  }
}
