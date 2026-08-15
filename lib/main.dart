import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'services/locale_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController();
  await localeController.load();
  runApp(OlympusApp(localeController: localeController));
}

class OlympusApp extends StatelessWidget {
  const OlympusApp({super.key, required this.localeController});

  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeController,
      builder: (context, locale, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE94560),
              secondary: Color(0xFF0F3460),
              surface: Color(0xFF1A1A2E),
              error: Color(0xFFE74C3C),
            ),
            scaffoldBackgroundColor: const Color(0xFF0F0F1A),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A1A2E),
              elevation: 0,
            ),
            cardTheme: const CardThemeData(
              color: Color(0xFF1A1A2E),
              elevation: 0,
            ),
            useMaterial3: true,
          ),
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L10n.all,
          locale: locale,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          home: HomeScreen(localeController: localeController),
        );
      },
    );
  }
}
