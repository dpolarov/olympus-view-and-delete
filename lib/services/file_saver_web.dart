// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

String _safeBasename(String raw) {
  final base = raw.split(RegExp(r'[/\\]')).last.replaceAll('\u0000', '').trim();
  if (base.isEmpty || base == '.' || base == '..') {
    return 'file_${DateTime.now().millisecondsSinceEpoch}';
  }
  return base.length > 180 ? base.substring(0, 180) : base;
}

Future<String> saveFileToDevice(String filename, List<int> bytes, String? dirPath) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = _safeBasename(filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'Downloaded via browser';
}

Future<String> getSaveDirectory() async {
  return 'browser_download';
}

Future<void> ensureDirectory(String path) async {
  // No-op on web
}
