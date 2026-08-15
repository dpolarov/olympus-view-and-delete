import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:olympus_tg6_manager/screens/photo_preview_screen.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/image_cache.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_helpers.dart';

class _FakeApi extends CameraApi {
  bool shouldSucceed = true;
  final List<String> deletedPaths = [];

  @override
  Future<bool> testConnection(
          {Duration timeout = const Duration(seconds: 5)}) async =>
      true;

  @override
  Future<bool> deleteFile(CameraFile file) async {
    deletedPaths.add(file.fullPath);
    return shouldSucceed;
  }

  @override
  Future<List<int>> downloadFile(CameraFile file) async => const <int>[];

  @override
  void dispose() {}
}

http.Client _makeMockClient() => fixedResponseClient(status: 204);

CameraFile _file(String name) => CameraFile(
      directory: '/DCIM/100OLYMP',
      filename: name,
      size: 1024,
      attributes: 0,
      dateRaw: 0,
      timeRaw: 0,
      date: DateTime(2024, 6, 1, 12, 0),
    );

Future<void> _pumpPreview(
  WidgetTester tester, {
  required List<CameraFile> files,
  required int initialIndex,
  required CameraApi api,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: PhotoPreviewScreen(
      file: files[initialIndex],
      files: files,
      initialIndex: initialIndex,
      api: api,
      httpClient: _makeMockClient(),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump();
}

Future<void> _settle(WidgetTester tester, {int frames = 8}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('olympus_preview_test_');
    PathProviderPlatform.instance = FakePathProvider(tmp.path);
    SharedPreferences.setMockInitialValues({});
    await ImageDiskCache.instance.resetForTests();
  });

  tearDown(() async {
    await ImageDiskCache.instance.resetForTests();
    if (await tmp.exists()) {
      try {
        await tmp.delete(recursive: true);
      } catch (_) {}
    }
  });

  testWidgets('initially shows the requested file in the header',
      (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    await _pumpPreview(
      tester,
      files: files,
      initialIndex: 1,
      api: _FakeApi(),
    );
    expect(find.text('B.JPG'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('does not mutate caller-supplied file list', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    final api = _FakeApi();
    await _pumpPreview(tester, files: files, initialIndex: 1, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(files.map((f) => f.filename), ['A.JPG', 'B.JPG', 'C.JPG']);
    expect(api.deletedPaths, ['/DCIM/100OLYMP/B.JPG']);
  });

  testWidgets(
      'after deleting the middle file, header shows the file now at that index',
      (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    final api = _FakeApi();
    await _pumpPreview(tester, files: files, initialIndex: 1, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(find.text('C.JPG'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('B.JPG'), findsNothing);
  });

  testWidgets('deleting the last file moves selection to the new last element',
      (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    final api = _FakeApi();
    await _pumpPreview(tester, files: files, initialIndex: 2, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(find.text('B.JPG'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets('deleting the only file pops with true', (tester) async {
    final files = [_file('ONLY.JPG')];
    final api = _FakeApi();
    bool? popResult;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        return Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                popResult = await Navigator.of(ctx).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => PhotoPreviewScreen(
                      file: files[0],
                      files: files,
                      initialIndex: 0,
                      api: api,
                      httpClient: _makeMockClient(),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        );
      }),
    ));
    await tester.tap(find.text('open'));
    await _settle(tester);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(popResult, isTrue);
    expect(api.deletedPaths, ['/DCIM/100OLYMP/ONLY.JPG']);
  });

  testWidgets('failed delete keeps file in the list', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    final api = _FakeApi()..shouldSucceed = false;
    await _pumpPreview(tester, files: files, initialIndex: 1, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('DELETE'));
    await _settle(tester);

    expect(find.text('B.JPG'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('swiping forward updates the header', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG'), _file('C.JPG')];
    await _pumpPreview(
      tester,
      files: files,
      initialIndex: 0,
      api: _FakeApi(),
    );
    expect(find.text('A.JPG'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await _settle(tester);

    expect(find.text('B.JPG'), findsOneWidget);
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('swipe back returns to the previous file', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG')];
    await _pumpPreview(
      tester,
      files: files,
      initialIndex: 1,
      api: _FakeApi(),
    );
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await _settle(tester);
    expect(find.text('A.JPG'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });

  testWidgets('cancelling the delete dialog keeps the file', (tester) async {
    final files = [_file('A.JPG'), _file('B.JPG')];
    final api = _FakeApi();
    await _pumpPreview(tester, files: files, initialIndex: 0, api: api);

    await tester.tap(find.byTooltip('Delete'));
    await _settle(tester);
    await tester.tap(find.text('Cancel'));
    await _settle(tester);

    expect(api.deletedPaths, isEmpty);
    expect(find.text('A.JPG'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
  });
}
