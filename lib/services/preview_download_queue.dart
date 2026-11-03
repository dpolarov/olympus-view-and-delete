import 'dart:async';

import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'camera_api.dart';
import 'download_history.dart';
import 'file_saver.dart' as file_saver;

/// App-scoped FIFO queue for downloads started from the full-screen preview.
///
/// A download must outlive PhotoPreviewScreen: paging away or closing the
/// screen must not dispose the HTTP client or drop pending transfers.
class PreviewDownloadQueue extends ChangeNotifier {
  PreviewDownloadQueue({Future<void> Function(CameraFile)? downloadAndSave})
      : _downloadAndSave = downloadAndSave ?? _saveCameraFile;

  static final PreviewDownloadQueue instance = PreviewDownloadQueue();

  final Future<void> Function(CameraFile) _downloadAndSave;
  final List<CameraFile> _pending = <CameraFile>[];
  final Set<String> _queuedKeys = <String>{};
  final Set<String> _completedKeys = <String>{};
  final Map<String, String> _failures = <String, String>{};
  Completer<void>? _idleCompleter;
  bool _processing = false;

  bool get isBusy => _queuedKeys.isNotEmpty;
  int get queuedCount => _queuedKeys.length;
  Set<String> get completedKeys => Set.unmodifiable(_completedKeys);

  bool isQueued(CameraFile file) =>
      _queuedKeys.contains(file.downloadHistoryKey);

  String? errorFor(CameraFile file) => _failures[file.downloadHistoryKey];

  /// Returns false for duplicate taps while this file is already queued.
  bool enqueue(CameraFile file) {
    final key = file.downloadHistoryKey;
    if (!_queuedKeys.add(key)) return false;
    _completedKeys.remove(key);
    _failures.remove(key);
    _idleCompleter ??= Completer<void>();
    _pending.add(file);
    notifyListeners();
    if (!_processing) unawaited(_process());
    return true;
  }

  Future<void> whenIdle() =>
      _idleCompleter?.future ?? Future<void>.value();

  Future<void> _process() async {
    _processing = true;
    while (_pending.isNotEmpty) {
      final file = _pending.removeAt(0);
      final key = file.downloadHistoryKey;
      try {
        await _downloadAndSave(file);
        await DownloadHistory.mark(key);
        _completedKeys.add(key);
      } catch (error, stackTrace) {
        _failures[key] = error.toString();
        AppLogger.warning(
          'queued download failed for ${file.fullPath}',
          name: 'preview_download_queue',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _queuedKeys.remove(key);
        notifyListeners();
      }
    }
    _processing = false;
    final idle = _idleCompleter;
    _idleCompleter = null;
    idle?.complete();
  }

  static Future<void> _saveCameraFile(CameraFile file) async {
    final api = CameraApi();
    try {
      final bytes = await api.downloadFile(file);
      final directory = await file_saver.getSaveDirectory();
      await file_saver.saveFileToDevice(file.filename, bytes, directory);
    } finally {
      api.dispose();
    }
  }
}
