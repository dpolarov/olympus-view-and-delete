import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/widgets/four_finger_debug_trigger.dart';

void main() {
  testWidgets('four simultaneous pointers trigger diagnostics once', (tester) async {
    var triggerCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FourFingerDebugTrigger(
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
    await tester.pump();
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
    await tester.pump();
    expect(triggerCount, 0);

    for (final gesture in gestures) {
      await gesture.up();
    }
  });
  testWidgets('four quick downs trigger even if one pointer was cancelled',
      (tester) async {
    var triggerCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: FourFingerDebugTrigger(
          onTriggered: () => triggerCount++,
          child: const SizedBox.expand(),
        ),
      ),
    );

    final first = await tester.startGesture(const Offset(30, 80), pointer: 1);
    final second = await tester.startGesture(const Offset(60, 80), pointer: 2);
    final third = await tester.startGesture(const Offset(90, 80), pointer: 3);
    await first.cancel();
    final fourth = await tester.startGesture(const Offset(120, 80), pointer: 4);
    await tester.pump();

    expect(triggerCount, 1);
    await second.up();
    await third.up();
    await fourth.up();
  });

}
