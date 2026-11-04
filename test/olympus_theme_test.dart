import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/theme/olympus_theme.dart';

void main() {
  test('camera-shell theme uses graphite surfaces instead of purple', () {
    final theme = OlympusTheme.dark;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, OlympusPalette.background);
    expect(theme.colorScheme.surface, OlympusPalette.surface);
    expect(theme.colorScheme.primary, OlympusPalette.coral);
    expect(theme.colorScheme.tertiary, OlympusPalette.success);
    expect(theme.colorScheme.error, OlympusPalette.danger);
    expect(theme.appBarTheme.backgroundColor, OlympusPalette.surface);
    expect(theme.cardTheme.color, OlympusPalette.card);
    expect(theme.useMaterial3, isTrue);
  });

  test('buttons use clear contrast roles without blue or purple', () {
    final theme = OlympusTheme.dark;
    final button = theme.filledButtonTheme.style;
    final outlined = theme.outlinedButtonTheme.style;

    expect(button?.backgroundColor?.resolve({}), OlympusPalette.coral);
    expect(button?.foregroundColor?.resolve({}), OlympusPalette.onCoral);
    expect(outlined?.foregroundColor?.resolve({}), OlympusPalette.text);
  });

  testWidgets('theme is inherited by nested screens', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: OlympusTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: const Text('Olympus View')),
          body: Text(
            'Camera connected',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
        ),
      ),
    ));

    expect(find.text('Olympus View'), findsOneWidget);
    expect(find.text('Camera connected'), findsOneWidget);
  });
}
