import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'camera_api.dart';

class BackgroundDownloadService {
  BackgroundDownloadService._();

  static const MethodChannel _channel =
      MethodChannel('com.flynew.photomanager/background_download');

  // HomeScreen refreshes downloaded-file history before asking whether the
  // native service is still running. The native worker writes the final
  // history key immediately before it switches isRunning to false, so without
  // a short completion grace the UI can observe the old history snapshot and
  // then stop polling on the same tick. Keep reporting "running" briefly after
  // the first native false transition; the next polling tick then refreshes the
  // final key before the monitor is allowed to stop.
  static const Duration _completionGrace = Duration(seconds: 5);
  static bool _observedRunning = false;
  static DateTime? _completionGraceUntil;

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
    _observedRunning = true;
    _completionGraceUntil = null;
  }

  static Future<bool> isRunning() async {
    if (!isSupported) return false;
    final nativeRunning = await _channel.invokeMethod<bool>('isRunning') ?? false;
    if (nativeRunning) {
      _observedRunning = true;
      _completionGraceUntil = null;
      return true;
    }

    final now = DateTime.now();
    if (_observedRunning) {
      _observedRunning = false;
      _completionGraceUntil = now.add(_completionGrace);
    }

    final graceUntil = _completionGraceUntil;
    if (graceUntil != null && now.isBefore(graceUntil)) return true;
    _completionGraceUntil = null;
    return false;
  }
}
