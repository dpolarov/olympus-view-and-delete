import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_logger.dart';
import 'camera_api.dart';
import 'download_history.dart';
import 'file_saver.dart' as file_saver;

/// App-scoped FIFO queue for downloads started from the full-screen preview.
///
/// A download must outlive PhotoPreviewScreen: paging away or closing the
/// screen must not dispose the HTTP client or drop pending transfers.
class PreviewDownloadQueue extends ChangeNotifier {
  PreviewDownloadQueue({
    Future<void> Function(CameraFile)? downloadAndSave,
    Future<void> Function()? onQueueFinished,
  })  : _downloadAndSave = downloadAndSave ?? _saveCameraFile,
        _onQueueFinished = onQueueFinished ?? _playCompletionSound;

  static final PreviewDownloadQueue instance = PreviewDownloadQueue();

  final Future<void> Function(CameraFile) _downloadAndSave;
  final Future<void> Function() _onQueueFinished;
  final List<CameraFile> _pending = <CameraFile>[];
  final Set<String> _queuedKeys = <String>{};
  final Set<String> _completedKeys = <String>{};
  final Map<String, String> _failures = <String, String>{};
  Completer<void>? _idleCompleter;
  bool _processing = false;
  int _totalCount = 0;
  int _finishedCount = 0;
  int _failedCount = 0;
  String? _activeFilename;

  bool get isBusy => _queuedKeys.isNotEmpty;
  int get queuedCount => _queuedKeys.length;
  int get totalCount => _totalCount;
  int get finishedCount => _finishedCount;
  int get failedCount => _failedCount;
  int get successCount => _finishedCount - _failedCount;
  String? get activeFilename => _activeFilename;
  double get progress =>
      _totalCount == 0 ? 0 : _finishedCount / _totalCount;
  Set<String> get completedKeys => Set.unmodifiable(_completedKeys);

  bool isQueued(CameraFile file) =>
      _queuedKeys.contains(file.downloadHistoryKey);

  String? errorFor(CameraFile file) => _failures[file.downloadHistoryKey];

  /// Returns false for duplicate taps while this file is already queued.
  bool enqueue(CameraFile file) {
    final key = file.downloadHistoryKey;
    if (!_queuedKeys.add(key)) return false;
    if (!_processing) {
      _totalCount = 0;
      _finishedCount = 0;
      _failedCount = 0;
    }
    _totalCount++;
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
      _activeFilename = file.filename;
      notifyListeners();
      try {
        await _downloadAndSave(file);
        await DownloadHistory.mark(key);
        _completedKeys.add(key);
      } catch (error, stackTrace) {
        _failedCount++;
        _failures[key] = error.toString();
        AppLogger.warning(
          'queued download failed for ${file.fullPath}',
          name: 'preview_download_queue',
          error: error,
          stackTrace: stackTrace,
        );
      } finally {
        _finishedCount++;
        _activeFilename = null;
        _queuedKeys.remove(key);
        notifyListeners();
      }
    }
    _processing = false;
    final idle = _idleCompleter;
    _idleCompleter = null;
    try {
      await _onQueueFinished();
    } catch (error) {
      AppLogger.debug(
        'download completion sound unavailable: $error',
        name: 'preview_download_queue',
      );
    } finally {
      idle?.complete();
    }
  }

  static const MethodChannel _soundChannel =
      MethodChannel('com.flynew.photomanager/background_download');

  static Future<void> _playCompletionSound() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _soundChannel.invokeMethod<void>('playCompletionSound');
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
