// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:olympus_tg6_manager/main.dart';
import 'package:olympus_tg6_manager/services/locale_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await tester.pumpWidget(OlympusApp(localeController: LocaleController()));
    });
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
