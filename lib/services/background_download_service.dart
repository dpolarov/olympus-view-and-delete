import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'camera_api.dart';

class BackgroundDownloadService {
  BackgroundDownloadService._();

  static const MethodChannel _channel =
      MethodChannel('com.flynew.photomanager/background_download');

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> start(List<CameraFile> files) async {
    if (!isSupported) {
      throw UnsupportedError('Background downloads are Android-only');
    }

    final items = files
        .map(
          (file) => <String, Object>{
            'url': file.downloadUrl,
            'filename': file.filename,
            'historyKey': file.downloadHistoryKey,
            'size': file.size,
          },
        )
        .toList(growable: false);

    await _channel.invokeMethod<void>('start', <String, String>{
      'itemsJson': jsonEncode(items),
    });
  }

  static Future<bool> isRunning() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('isRunning') ?? false;
  }
}
