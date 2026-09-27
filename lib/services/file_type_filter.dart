import 'package:shared_preferences/shared_preferences.dart';

enum FileTypeFilter { raw, jpg, both }

class FileTypeFilterPreferences {
  static const String _key = 'file_type_filter';

  static Future<FileTypeFilter> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    for (final filter in FileTypeFilter.values) {
      if (filter.name == saved) return filter;
    }
    return FileTypeFilter.jpg;
  }

  static Future<void> save(FileTypeFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, filter.name);
  }
}

bool isRawCameraFile(String filename) {
  final lower = filename.toLowerCase();
  return lower.endsWith('.orf') ||
      lower.endsWith('.raw') ||
      lower.endsWith('.dng');
}

bool isJpgCameraFile(String filename) {
  final lower = filename.toLowerCase();
  return lower.endsWith('.jpg') || lower.endsWith('.jpeg');
}

bool isVideoCameraFile(String filename) {
  final lower = filename.toLowerCase();
  return lower.endsWith('.mov') ||
      lower.endsWith('.mp4') ||
      lower.endsWith('.m4v') ||
      lower.endsWith('.avi') ||
      lower.endsWith('.mts') ||
      lower.endsWith('.m2ts');
}

/// OM System cameras reliably expose the small thumbnail endpoint for RAW and
/// movie files. High-resolution resize previews are primarily intended for
/// JPEG stills and can fail for RAW/movie paths on some bodies (including
/// OM-1), so those file types should try the thumbnail endpoint first.
bool prefersThumbnailGridPreview(String filename) =>
    isRawCameraFile(filename) || isVideoCameraFile(filename);

bool fileMatchesTypeFilter(String filename, FileTypeFilter filter) {
  final raw = isRawCameraFile(filename);
  final jpg = isJpgCameraFile(filename);
  final video = isVideoCameraFile(filename);

  // The RAW/JPG selector filters still photos only. Camera video files must
  // remain visible regardless of the selected still-image format, matching
  // the pre-v1.3.9 gallery behaviour where only RAW files were hidden.
  if (video) return true;

  switch (filter) {
    case FileTypeFilter.raw:
      return raw;
    case FileTypeFilter.jpg:
      return jpg;
    case FileTypeFilter.both:
      return raw || jpg;
  }
}
