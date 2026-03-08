import 'package:flutter/material.dart';
import '../services/camera_api.dart';

class PhotoGrid extends StatelessWidget {
  final List<CameraFile> files;
  final bool gridView;
  final bool selectionMode;
  final Set<String> selectedPaths;
  final void Function(CameraFile) onTap;
  final void Function(CameraFile) onLongPress;

  const PhotoGrid({
    super.key,
    required this.files,
    required this.gridView,
    required this.selectionMode,
    required this.selectedPaths,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    if (gridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 0.8,
        ),
        itemCount: files.length,
        itemBuilder: (ctx, i) => _GridItem(
          file: files[i],
          selected: selectedPaths.contains(files[i].fullPath),
          selectionMode: selectionMode,
          onTap: () => onTap(files[i]),
          onLongPress: () => onLongPress(files[i]),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: files.length,
      itemBuilder: (ctx, i) => _ListItem(
        file: files[i],
        selected: selectedPaths.contains(files[i].fullPath),
        selectionMode: selectionMode,
        onTap: () => onTap(files[i]),
        onLongPress: () => onLongPress(files[i]),
      ),
    );
  }
}

class _GridItem extends StatelessWidget {
  final CameraFile file;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _GridItem({
    required this.file,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectionMode ? onTap : null,
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
                  Image.network(
                    file.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF252540),
                      child: const Icon(Icons.broken_image,
                          color: Colors.grey, size: 32),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
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
                    },
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
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ListItem({
    required this.file,
    required this.selected,
    required this.selectionMode,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: selectionMode ? onTap : null,
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
              child: Image.network(
                file.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF252540),
                  child: const Icon(Icons.broken_image,
                      color: Colors.grey, size: 24),
                ),
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
