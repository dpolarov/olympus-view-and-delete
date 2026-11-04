import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/constants.dart';
import 'package:olympus_tg6_manager/theme/olympus_theme.dart';

void main() {
  test('camera-shell theme has no blue or purple surfaces', () {
    final theme = OlympusTheme.dark;
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF141719));
    expect(theme.colorScheme.surface, const Color(0xFF191D1E));
    expect(theme.colorScheme.primary, kPrimaryColor);
    expect(theme.colorScheme.secondary, kAccentColor);
    expect(theme.colorScheme.onPrimary, OlympusTheme.canvas);
    expect(theme.colorScheme.onSurface, OlympusTheme.ink);
    expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
  });

  testWidgets('buttons use accessible light foreground on graphite surfaces',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: OlympusTheme.dark,
      home: Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () {},
            child: const Text('Select files'),
          ),
        ),
      ),
    ));
    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull);
    expect(Theme.of(tester.element(find.text('Select files'))).brightness,
        Brightness.dark);
  });
}
