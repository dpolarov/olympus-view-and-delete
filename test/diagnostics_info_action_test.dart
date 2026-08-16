import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/widgets/diagnostics_info_action.dart';

void main() {
  testWidgets('tap opens About callback', (tester) async {
    var taps = 0;
    var diagnostics = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DiagnosticsInfoAction(
          onTap: () => taps++,
          onDiagnostics: () => diagnostics++,
        ),
      ),
    ));

    await tester.tap(find.byType(DiagnosticsInfoAction));
    await tester.pump();

    expect(taps, 1);
    expect(diagnostics, 0);
  });

  testWidgets('raw pointer hold opens diagnostics without tap', (tester) async {
    var taps = 0;
    var diagnostics = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DiagnosticsInfoAction(
          holdDuration: const Duration(milliseconds: 300),
          onTap: () => taps++,
          onDiagnostics: () => diagnostics++,
        ),
      ),
    ));

    final center = tester.getCenter(find.byType(DiagnosticsInfoAction));
    final gesture = await tester.startGesture(center, pointer: 41);
    await tester.pump(const Duration(milliseconds: 350));
    expect(diagnostics, 1);

    await gesture.up();
    await tester.pump();
    expect(taps, 0);
    expect(diagnostics, 1);
  });
}
