// TODO: Migrate this small browser adapter to package:web when the project
// raises its minimum Dart SDK. dart:html remains supported by the current SDK.
// ignore_for_file: deprecated_member_use
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

import 'filename_sanitizer.dart';

Future<String> saveFileToDevice(
    String filename, List<int> bytes, String? dirPath) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = sanitizeFilename(filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'Downloaded via browser';
}

Future<String> getSaveDirectory() async {
  return 'browser_download';
}

Future<void> ensureDirectory(String path) async {
  // No-op on web.
}
