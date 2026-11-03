import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/download_history.dart';
import 'package:olympus_tg6_manager/services/preview_download_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

CameraFile _file(String filename) => CameraFile(
      directory: '/DCIM/100OLYMP',
      filename: filename,
      size: 1024,
      attributes: 0,
      dateRaw: 0,
      timeRaw: 0,
      date: DateTime(2024, 6, 1),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('FIFO downloads remain queued and duplicate taps are ignored', () async {
    final first = _file('A.JPG');
    final second = _file('B.JPG');
    final firstGate = Completer<void>();
    final secondStarted = Completer<void>();
    final started = <String>[];
    var sounds = 0;
    final queue = PreviewDownloadQueue(
      onQueueFinished: () async { sounds++; },
      downloadAndSave: (file) async {
      started.add(file.filename);
      if (file.filename == 'A.JPG') {
        await firstGate.future;
      } else {
        secondStarted.complete();
      }
    });

    expect(queue.enqueue(first), isTrue);
    expect(queue.enqueue(second), isTrue);
    expect(queue.enqueue(first), isFalse);
    expect(queue.queuedCount, 2);
    expect(queue.totalCount, 2);
    expect(queue.finishedCount, 0);
    expect(queue.activeFilename, 'A.JPG');
    expect(queue.progress, 0);
    expect(started, ['A.JPG']);

    firstGate.complete();
    await secondStarted.future;
    expect(queue.finishedCount, 1);
    expect(queue.progress, 0.5);
    await queue.whenIdle();

    expect(sounds, 1);
    expect(queue.totalCount, 2);
    expect(queue.finishedCount, 2);
    expect(queue.failedCount, 0);
    expect(queue.progress, 1);
    expect(started, ['A.JPG', 'B.JPG']);
    expect(queue.isBusy, isFalse);
    expect(queue.completedKeys, containsAll([
      first.downloadHistoryKey,
      second.downloadHistoryKey,
    ]));
    expect(await DownloadHistory.load(), containsAll([
      first.downloadHistoryKey,
      second.downloadHistoryKey,
    ]));
  });

  test('failed download does not cancel later items and can be retried', () async {
    final first = _file('FAIL.JPG');
    final second = _file('OK.JPG');
    final started = <String>[];
    var shouldFail = true;
    final queue = PreviewDownloadQueue(downloadAndSave: (file) async {
      started.add(file.filename);
      if (file.filename == 'FAIL.JPG' && shouldFail) {
        throw StateError('camera disconnected');
      }
    });

    expect(queue.enqueue(first), isTrue);
    expect(queue.enqueue(second), isTrue);
    await queue.whenIdle();

    expect(started, ['FAIL.JPG', 'OK.JPG']);
    expect(queue.errorFor(first), contains('camera disconnected'));
    expect(queue.totalCount, 2);
    expect(queue.finishedCount, 2);
    expect(queue.failedCount, 1);
    expect(queue.completedKeys, contains(second.downloadHistoryKey));
    expect(queue.completedKeys, isNot(contains(first.downloadHistoryKey)));

    shouldFail = false;
    expect(queue.enqueue(first), isTrue);
    await queue.whenIdle();
    expect(queue.errorFor(first), isNull);
    expect(queue.totalCount, 1);
    expect(queue.finishedCount, 1);
    expect(queue.failedCount, 0);
    expect(queue.completedKeys, contains(first.downloadHistoryKey));
  });
}
