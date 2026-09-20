import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:olympus_tg6_manager/main.dart';
import 'package:olympus_tg6_manager/screens/home_screen.dart';
import 'package:olympus_tg6_manager/screens/photo_preview_screen.dart';
import 'package:olympus_tg6_manager/services/camera_api.dart';
import 'package:olympus_tg6_manager/services/locale_controller.dart';

import 'helpers/fake_camera_server.dart';

/// Set by the test so [waitUntil] can dump camera traffic on timeout.
FakeCameraServer? _camera;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Real-time wait for a finder to match, polling the live widget tree.
  /// The app talks to the fake camera over real sockets, so everything runs
  /// on real async — pump/poll loops, not fake-async settles.
  Future<void> waitUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String? reason,
  }) async {
    await tester.runAsync(() async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        await tester.pump();
        if (finder.evaluate().isNotEmpty) return;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    });
    if (finder.evaluate().isEmpty) {
      final texts = tester
          .allWidgets
          .whereType<Text>()
          .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
          .where((s) => s.isNotEmpty)
          .take(40)
          .toList();
      debugPrint('WAIT-TIMEOUT texts on screen: $texts');
      debugPrint('WAIT-TIMEOUT camera requests: ${_camera?.requests}');
    }
    expect(finder, findsWidgets,
        reason:
            '${reason ?? finder.describeMatch(Plurality.many)} — did not '
            'appear within ${timeout.inSeconds}s');
  }

  testWidgets(
      'app connects to the emulated Olympus camera, loads the gallery and '
      'browses photos in full-screen preview', (tester) async {
    final camera = FakeCameraServer();
    _camera = camera;
    addTearDown(() => _camera = null);
    camera.addPhoto('/DCIM/100OLYMP/P1010001.JPG');
    camera.addPhoto('/DCIM/100OLYMP/P1010002.JPG');
    camera.addPhoto('/DCIM/100OLYMP/P1010003.JPG');
    debugCameraBaseUrlOverride = await camera.start();
    addTearDown(() async {
      debugCameraBaseUrlOverride = null;
      await camera.close();
    });

    final localeController = LocaleController();
    await localeController.load();
    await tester.pumpWidget(OlympusApp(localeController: localeController));

    // 1. Boot: the app probes the camera and lands on the gallery screen.
    expect(find.byType(HomeScreen), findsOneWidget);
    await waitUntil(tester, find.text('P1010003.JPG'),
        reason: 'gallery should list the camera files');

    // 2. The listing really came from the fake camera's protocol.
    expect(camera.requests.any((r) => r.startsWith('/get_caminfo.cgi')), isTrue);
    expect(camera.requests.any((r) => r.startsWith('/get_imglist.cgi')), isTrue);

    // 3. Open full-screen preview of the first photo.
    await tester.tap(find.text('P1010001.JPG'));
    await tester.pump();
    await waitUntil(tester, find.byType(PhotoPreviewScreen));
    await waitUntil(tester, find.text('1/3'),
        reason: 'preview header should show the first of three photos');

    // 4. Swipe to the next photo: real camera request + header update.
    // A 500px drag is wider than the emulator's logical screen (~411px),
    // so the fling would cut off — keep it inside the viewport.
    await tester.fling(find.byType(PageView), const Offset(-300, 0), 800);
    await tester.pumpAndSettle();
    await waitUntil(tester, find.text('2/3'),
        reason: 'paging should advance the preview header');
    expect(find.text('P1010002.JPG'), findsOneWidget);
    expect(
      camera.requests.any((r) => r.startsWith('/get_screennail.cgi')),
      isTrue,
      reason: 'full-screen previews should prefer the screennail endpoint',
    );

    // 5. Close the preview back to the gallery. The preview's AppBar uses a
    // custom leading IconButton, so tap the back icon itself.
    await tester.tap(find.descendant(
      of: find.byType(AppBar),
      matching: find.byIcon(Icons.arrow_back),
    ));
    await tester.pump();
    await waitUntil(tester, find.byType(HomeScreen));
  });
}
