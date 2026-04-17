import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:media_scanner/media_scanner.dart';

/// Sanitise a filename at the save boundary. Prevents path traversal if the
/// caller forgets to pre-sanitise (defense in depth). Strips directory
/// separators, `..`, NUL, and reserved characters.
String _safeBasename(String raw) {
  final base = raw.split(RegExp(r'[/\\]')).last;
  final cleaned = base
      .replaceAll('\u0000', '')
      .replaceAll(RegExp(r'[\x00-\x1F]'), '')
      .replaceAll(RegExp(r'[<>:"|?*]'), '_')
      .trim();
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return 'file_${DateTime.now().millisecondsSinceEpoch}';
  }
  return cleaned.length > 180 ? cleaned.substring(0, 180) : cleaned;
}

Future<String> saveFileToDevice(String filename, List<int> bytes, String? dirPath) async {
  final dir = dirPath ?? await getSaveDirectory();
  await ensureDirectory(dir);
  final safe = _safeBasename(filename);
  final filePath = '$dir/$safe';
  final file = File(filePath);
  await file.writeAsBytes(bytes);

  // Notify Android MediaScanner so file appears in Gallery
  if (Platform.isAndroid) {
    try {
      MediaScanner.loadMedia(path: filePath);
    } catch (_) {}
  }

  return filePath;
}

Future<String> getSaveDirectory() async {
  if (Platform.isAndroid) {
    return '/storage/emulated/0/DCIM/OlympusView';
  } else {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/OlympusView';
  }
}

Future<void> ensureDirectory(String path) async {
  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}
