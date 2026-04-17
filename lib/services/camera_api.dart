import 'package:http/http.dart' as http;
import 'file_saver.dart' as file_saver;

const String cameraIp = '192.168.0.10';
const String baseUrl = 'http://$cameraIp';
const Duration timeout = Duration(seconds: 10);
const Duration downloadTimeout = Duration(seconds: 120);

/// Maximum directory recursion depth in [CameraApi.listImages].
/// Protects against cycles / malformed camera responses that could
/// otherwise blow the stack.
const int _maxDirDepth = 8;

/// Return a filename safe to append to a local directory, stripping any
/// path separators, `..`, NUL bytes, and control characters. Used to
/// defend against path traversal via a hostile/corrupt camera response.
String sanitizeFilename(String raw) {
  // Keep only the last path segment; reject any separator chars.
  final base = raw.split(RegExp(r'[/\\]')).last;
  final cleaned = base
      .replaceAll('\u0000', '')
      .replaceAll(RegExp(r'[\x00-\x1F]'), '')
      .replaceAll(RegExp(r'[<>:"|?*]'), '_')
      .trim();
  // Reject traversal and empty/dot-only names.
  if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') {
    return 'file_${DateTime.now().millisecondsSinceEpoch}';
  }
  // Cap length to something sane.
  return cleaned.length > 180 ? cleaned.substring(0, 180) : cleaned;
}

class CameraFile {
  final String directory;
  final String filename;
  final int size;
  final int attributes;
  final int dateRaw;
  final int timeRaw;
  final DateTime date;
  bool selected;

  CameraFile({
    required this.directory,
    required this.filename,
    required this.size,
    required this.attributes,
    required this.dateRaw,
    required this.timeRaw,
    required this.date,
    this.selected = false,
  });

  String get fullPath => '$directory/$filename';
  String get thumbnailUrl => '$baseUrl/get_thumbnail.cgi?DIR=$fullPath';
  String get screennailUrl => '$baseUrl/get_screennail.cgi?DIR=$fullPath';
  String resizeImgUrl([int size = 1920]) =>
      '$baseUrl/get_resizeimg.cgi?DIR=$fullPath&size=$size';
  String get downloadUrl => '$baseUrl$fullPath';

  String get sizeHuman {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Human-readable byte count, independent of a `CameraFile` instance.
  static String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String get dateStr {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String get dateTimeStr {
    return '$dateStr '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  /// Decode FAT packed date/time. Returns `null` if the record is invalid
  /// (zero month/day, out-of-range fields) so the caller can skip it
  /// instead of silently materialising a wrapped date (e.g. month=0 → Dec prev year).
  static DateTime? decodeFatDateTime(int dateVal, int timeVal) {
    final year = ((dateVal >> 9) & 0x7F) + 1980;
    final month = (dateVal >> 5) & 0x0F;
    final day = dateVal & 0x1F;
    final hours = (timeVal >> 11) & 0x1F;
    final minutes = (timeVal >> 5) & 0x3F;
    final seconds = (timeVal & 0x1F) * 2;
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (hours > 23 || minutes > 59 || seconds > 59) return null;
    return DateTime(year, month, day, hours, minutes, seconds);
  }
}

class CameraApi {
  final http.Client _client = http.Client();

  Map<String, String> get _headers => {
        'User-Agent': 'OI.Share v2',
        'Host': cameraIp,
        'Connection': 'Keep-Alive',
      };

  /// Test if camera is reachable.
  ///
  /// [timeout] controls how long to wait for a reply. Use a short value
  /// (e.g. 1.5s) for the initial startup probe so the error screen appears
  /// quickly when no camera is on the network.
  Future<bool> testConnection(
      {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      await _client
          .get(Uri.parse('$baseUrl/get_caminfo.cgi'), headers: _headers)
          .timeout(timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Get camera model info
  Future<Map<String, String>> getCameraInfo() async {
    final resp = await _client
        .get(Uri.parse('$baseUrl/get_caminfo.cgi'), headers: _headers)
        .timeout(timeout);
    final info = <String, String>{};
    // Parse simple XML tags
    final regex = RegExp(r'<(\w+)>([^<]*)</\1>');
    for (final match in regex.allMatches(resp.body)) {
      info[match.group(1)!] = match.group(2)!;
    }
    return info;
  }

  /// Switch camera mode: play, rec, shutter
  Future<void> switchMode(String mode) async {
    await _client
        .get(Uri.parse('$baseUrl/switch_cammode.cgi?mode=$mode'),
            headers: _headers)
        .timeout(timeout);
  }

  /// Recursively list images starting from a directory (like olympus-wifi)
  /// Uses get_imglist.cgi; directories (attrib & 16) are traversed recursively.
  /// If [onBatch] is provided, each directory's files are reported immediately
  /// so the UI can display them progressively.
  /// [depth] guards against pathologically deep / cyclic responses.
  Future<List<CameraFile>> listImages(String dir,
      {void Function(List<CameraFile>)? onBatch, int depth = 0}) async {
    if (depth > _maxDirDepth) return [];
    http.Response resp;
    try {
      resp = await _client
          .get(Uri.parse('$baseUrl/get_imglist.cgi?DIR=$dir'),
              headers: _headers)
          .timeout(timeout);
    } catch (_) {
      return []; // empty or inaccessible directory
    }

    if (resp.statusCode == 404) return []; // empty directory

    final files = <CameraFile>[];
    final immediateFiles = <CameraFile>[];
    final subDirs = <String>[];
    final lines = resp.body.trim().split(RegExp(r'\r?\n'));

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.toUpperCase().startsWith('VER')) continue;

      final parts = trimmed.split(',');
      if (parts.length < 6) continue;

      try {
        final dirName = parts[0].trim();
        final fileName = parts[1].trim();
        final size = int.parse(parts[2].trim());
        final attrib = int.parse(parts[3].trim());
        final dateRaw = int.parse(parts[4].trim());
        final timeRaw = int.parse(parts[5].trim());

        // Skip hidden (2), system (4), volume (8)
        if (attrib & 2 != 0 || attrib & 4 != 0 || attrib & 8 != 0) continue;

        if (attrib & 16 != 0) {
          // Directory — queue for recursive traversal
          subDirs.add('$dirName/$fileName');
        } else {
          final date = CameraFile.decodeFatDateTime(dateRaw, timeRaw);
          if (date == null) continue; // skip corrupt date records
          // Regular file
          final file = CameraFile(
            directory: dirName,
            filename: fileName,
            size: size,
            attributes: attrib,
            dateRaw: dateRaw,
            timeRaw: timeRaw,
            date: date,
          );
          immediateFiles.add(file);
        }
      } catch (_) {
        continue;
      }
    }

    // Report this directory's files immediately
    if (immediateFiles.isNotEmpty) {
      files.addAll(immediateFiles);
      onBatch?.call(immediateFiles);
    }

    // Then recurse into subdirectories
    for (final subDir in subDirs) {
      final subFiles =
          await listImages(subDir, onBatch: onBatch, depth: depth + 1);
      files.addAll(subFiles);
    }

    return files;
  }

  /// List all files on the camera.
  /// If [onBatch] is provided, files are reported progressively as each
  /// directory is scanned, allowing the UI to show results immediately.
  Future<List<CameraFile>> listAllFiles({void Function(List<CameraFile>)? onBatch}) async {
    try {
      await switchMode('play');
    } catch (e) {
      // Non-fatal: camera may already be in play mode. Log for diagnostics.
      // ignore: avoid_print
      print('switchMode(play) failed (continuing): $e');
    }

    await Future.delayed(const Duration(milliseconds: 500));

    final allFiles = await listImages('/DCIM', onBatch: onBatch);

    // Sort newest first
    allFiles.sort((a, b) => b.date.compareTo(a.date));
    return allFiles;
  }

  /// Delete a single file. Returns `true` only on HTTP 200.
  Future<bool> deleteFile(CameraFile file) async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/exec_erase.cgi?DIR=${file.fullPath}'),
              headers: _headers)
          .timeout(timeout);
      // Olympus returns 200 on success; 403/500 etc on failure.
      if (resp.statusCode != 200) return false;
      // Some firmware responds with a body containing error text — treat as failure.
      final body = resp.body.toLowerCase();
      if (body.contains('error') || body.contains('fail')) return false;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete multiple files with progress callback
  Future<({int success, int failed})> deleteFiles(
    List<CameraFile> files, {
    void Function(int done, int total, String filename)? onProgress,
  }) async {
    int success = 0;
    int failed = 0;
    for (int i = 0; i < files.length; i++) {
      onProgress?.call(i + 1, files.length, files[i].filename);
      final ok = await deleteFile(files[i]);
      if (ok) {
        success++;
      } else {
        failed++;
      }
      if (i < files.length - 1) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
    return (success: success, failed: failed);
  }

  /// Download file bytes
  Future<List<int>> downloadFile(CameraFile file) async {
    final resp = await _client
        .get(Uri.parse(file.downloadUrl), headers: _headers)
        .timeout(downloadTimeout);
    return resp.bodyBytes;
  }

  /// Download multiple files with progress callback
  /// Returns (success, failed, savedPaths)
  Future<({int success, int failed, List<String> savedPaths})> downloadFiles(
    List<CameraFile> files,
    String saveDirPath, {
    void Function(int done, int total, String filename)? onProgress,
  }) async {
    int success = 0;
    int failed = 0;
    final savedPaths = <String>[];
    for (int i = 0; i < files.length; i++) {
      onProgress?.call(i + 1, files.length, files[i].filename);
      try {
        final bytes = await downloadFile(files[i]);
        final safeName = sanitizeFilename(files[i].filename);
        final savedPath = await file_saver.saveFileToDevice(
          safeName, bytes, saveDirPath);
        savedPaths.add(savedPath);
        success++;
      } catch (_) {
        failed++;
      }
    }
    return (success: success, failed: failed, savedPaths: savedPaths);
  }

  /// Get unique date strings from files
  static List<String> getUniqueDates(List<CameraFile> files) {
    final dates = <String>{};
    for (final f in files) {
      dates.add(f.dateStr);
    }
    final sorted = dates.toList()..sort();
    return sorted.reversed.toList();
  }

  /// Filter files by date string "YYYY-MM-DD"
  static List<CameraFile> filterByDate(List<CameraFile> files, String date) {
    return files.where((f) => f.dateStr == date).toList();
  }

  /// Filter files by date range
  static List<CameraFile> filterByDateRange(
    List<CameraFile> files,
    DateTime? from,
    DateTime? to,
  ) {
    return files.where((f) {
      final fd = DateTime(f.date.year, f.date.month, f.date.day);
      if (from != null) {
        final fromDay = DateTime(from.year, from.month, from.day);
        if (fd.isBefore(fromDay)) return false;
      }
      if (to != null) {
        final toDay = DateTime(to.year, to.month, to.day);
        if (fd.isAfter(toDay)) return false;
      }
      return true;
    }).toList();
  }

  void dispose() {
    _client.close();
  }
}
