import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:media_scanner/media_scanner.dart';

Future<String> saveFileToDevice(String filename, List<int> bytes, String? dirPath) async {
  final dir = dirPath ?? await getSaveDirectory();
  final filePath = '$dir/$filename';
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
