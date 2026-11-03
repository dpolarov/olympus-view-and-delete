import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/preview_download_queue.dart';
import 'package:olympus_tg6_manager/widgets/preview_download_progress.dart';
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

  testWidgets('overall progress updates as files finish', (tester) async {
    final first = Completer<void>();
    final second = Completer<void>();
    var soundCount = 0;
    final queue = PreviewDownloadQueue(
      onQueueFinished: () async { soundCount++; },
      downloadAndSave: (file) =>
          file.filename == 'A.JPG' ? first.future : second.future,
    );

    queue.enqueue(_file('A.JPG'));
    queue.enqueue(_file('B.JPG'));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: PreviewDownloadProgress(queue: queue)),
    ));
    expect(find.text('Downloads: 0 of 2 · 2 remaining'), findsOneWidget);
    expect(find.text('Now: A.JPG'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator)).value, 0);

    first.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('Downloads: 1 of 2 · 1 remaining'), findsOneWidget);
    expect(find.text('Now: B.JPG'), findsOneWidget);
    expect(tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator)).value, 0.5);

    second.complete();
    await tester.pump();
    await queue.whenIdle();
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(soundCount, 1);
  });
}
