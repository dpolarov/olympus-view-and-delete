import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadHistory {
  DownloadHistory._();

  static const MethodChannel _channel =
      MethodChannel('com.flynew.photomanager/background_download');
  static const String _prefsKey = 'download_history_v1';

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<Set<String>> load() async {
    if (_isAndroid) {
      try {
        final keys = await _channel.invokeListMethod<String>('getDownloadedKeys');
        return (keys ?? const <String>[]).toSet();
      } on PlatformException {
        // Fall through for tests / unsupported embeddings.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet();
  }

  static Future<void> mark(String key) async {
    if (_isAndroid) {
      try {
        await _channel.invokeMethod<void>('markDownloaded', <String, String>{
          'key': key,
        });
        return;
      } on PlatformException {
        // Fall through for tests / unsupported embeddings.
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final keys = (prefs.getStringList(_prefsKey) ?? const <String>[]).toSet()
      ..add(key);
    await prefs.setStringList(_prefsKey, keys.toList());
  }
}
