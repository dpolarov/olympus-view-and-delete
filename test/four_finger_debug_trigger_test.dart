import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/widgets/four_finger_debug_trigger.dart';

void main() {
  testWidgets('four held pointers trigger diagnostics once', (tester) async {
    var triggerCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FourFingerDebugTrigger(
          holdDuration: const Duration(milliseconds: 40),
          onTriggered: () => triggerCount++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final gestures = <TestGesture>[];
    for (var pointer = 1; pointer <= 4; pointer++) {
      gestures.add(
        await tester.startGesture(
          Offset(30.0 * pointer, 80),
          pointer: pointer,
        ),
      );
    }

    await tester.pump(const Duration(milliseconds: 50));
    expect(triggerCount, 1);

    await tester.pump(const Duration(milliseconds: 50));
    expect(triggerCount, 1);

    for (final gesture in gestures) {
      await gesture.up();
    }
  });

  testWidgets('three pointers do not trigger diagnostics', (tester) async {
    var triggerCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FourFingerDebugTrigger(
          holdDuration: const Duration(milliseconds: 20),
          onTriggered: () => triggerCount++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final gestures = <TestGesture>[];
    for (var pointer = 1; pointer <= 3; pointer++) {
      gestures.add(
        await tester.startGesture(
          Offset(30.0 * pointer, 80),
          pointer: pointer,
        ),
      );
    }

    await tester.pump(const Duration(milliseconds: 50));
    expect(triggerCount, 0);

    for (final gesture in gestures) {
      await gesture.up();
    }
  });
}
