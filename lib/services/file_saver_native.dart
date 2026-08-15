import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'filename_sanitizer.dart';

const MethodChannel _mediaStoreChannel =
    MethodChannel('com.flynew.photomanager/media_store');

Future<String> saveFileToDevice(
    String filename, List<int> bytes, String? dirPath) async {
  final safe = sanitizeFilename(filename);

  if (Platform.isAndroid) {
    return _saveAndroid(safe, bytes);
  }

  final dir = dirPath ?? await getSaveDirectory();
  await ensureDirectory(dir);
  final filePath = '$dir/$safe';
  final file = File(filePath);
  await file.writeAsBytes(bytes, flush: true);
  return filePath;
}

Future<String> _saveAndroid(String filename, List<int> bytes) async {
  Future<String> invoke() async {
    final location = await _mediaStoreChannel.invokeMethod<String>(
      'saveCameraFile',
      <String, Object>{
        'filename': filename,
        'bytes': Uint8List.fromList(bytes),
      },
    );
    if (location == null || location.isEmpty) {
      throw const FileSystemException('Android did not return a saved location');
    }
    return location;
  }

  try {
    return await invoke();
  } on PlatformException catch (error) {
    if (error.code != 'storage_permission_required') rethrow;

    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw const FileSystemException(
        'Storage permission is required on Android 9 and older',
      );
    }
    return invoke();
  }
}

Future<String> getSaveDirectory() async {
  if (Platform.isAndroid) {
    return 'DCIM/OlympusView';
  }

  final appDir = await getApplicationDocumentsDirectory();
  return '${appDir.path}/OlympusView';
}

Future<void> ensureDirectory(String path) async {
  if (Platform.isAndroid) return;

  final dir = Directory(path);
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
}
