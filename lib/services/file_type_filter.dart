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

bool fileMatchesTypeFilter(String filename, FileTypeFilter filter) {
  final lower = filename.toLowerCase();
  final raw =
      lower.endsWith('.orf') ||
      lower.endsWith('.raw') ||
      lower.endsWith('.dng');
  final jpg = lower.endsWith('.jpg') || lower.endsWith('.jpeg');

  switch (filter) {
    case FileTypeFilter.raw:
      return raw;
    case FileTypeFilter.jpg:
      return jpg;
    case FileTypeFilter.both:
      return raw || jpg;
  }
}
