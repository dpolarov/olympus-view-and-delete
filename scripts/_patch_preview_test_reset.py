from pathlib import Path

p = Path('test/photo_preview_screen_test.dart')
s = p.read_text(encoding='utf-8')
old = '''  testWidgets('downloaded file shows download-done marker in preview',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final file = _file('DONE.JPG');
    SharedPreferences.setMockInitialValues({
      'download_history_v1': <String>[file.downloadHistoryKey],
    });

    expect(await DownloadHistory.load(), contains(file.downloadHistoryKey));

    await _pumpPreview(
      tester,
      files: [file],
      initialIndex: 0,
      api: _FakeApi(),
    );
    await _settle(tester);

    expect(find.byIcon(Icons.download_done), findsOneWidget);
  });
'''
new = '''  testWidgets('downloaded file shows download-done marker in preview',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      final file = _file('DONE.JPG');
      SharedPreferences.setMockInitialValues({
        'download_history_v1': <String>[file.downloadHistoryKey],
      });

      expect(await DownloadHistory.load(), contains(file.downloadHistoryKey));

      await _pumpPreview(
        tester,
        files: [file],
        initialIndex: 0,
        api: _FakeApi(),
      );
      await _settle(tester);

      expect(find.byIcon(Icons.download_done), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
'''
if old not in s:
    raise SystemExit('download marker test block not found')
p.write_text(s.replace(old, new, 1), encoding='utf-8')
