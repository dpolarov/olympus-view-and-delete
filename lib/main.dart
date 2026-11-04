import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'l10n/l10n.dart';
import 'screens/debug_info_screen.dart';
import 'screens/home_screen.dart';
import 'services/locale_controller.dart';
import 'theme/olympus_theme.dart';
import 'widgets/camera_wifi_lifecycle_guard.dart';
import 'widgets/four_finger_debug_trigger.dart';

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
bool _debugRouteOpen = false;
bool _debugRouteScheduled = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final localeController = LocaleController();
  await localeController.load();
  runApp(OlympusApp(localeController: localeController));
}

class OlympusApp extends StatelessWidget {
  const OlympusApp({super.key, required this.localeController});

  final LocaleController localeController;

  void _openDebugInfo() {
    if (_debugRouteOpen || _debugRouteScheduled) return;
    _debugRouteScheduled = true;

    // Raw pointer callbacks can arrive while Flutter is still dispatching the
    // current input frame. Push diagnostics on the next frame so navigation is
    // never attempted from inside pointer dispatch/gesture resolution.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _debugRouteScheduled = false;
      if (_debugRouteOpen) return;
      final navigator = _navigatorKey.currentState;
      if (navigator == null || !navigator.mounted) return;

      _debugRouteOpen = true;
      unawaited(
        navigator
            .push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const DebugInfoScreen(),
                settings: const RouteSettings(name: '/debug-info'),
              ),
            )
            .whenComplete(() => _debugRouteOpen = false),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: localeController,
      builder: (context, locale, _) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: OlympusTheme.dark,
          localizationsDelegates: localizationsDelegates,
          supportedLocales: L10n.all,
          locale: locale,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          builder: (context, child) => FourFingerDebugTrigger(
            onTriggered: _openDebugInfo,
            child: child ?? const SizedBox.shrink(),
          ),
          home: CameraWifiLifecycleGuard(
            child: HomeScreen(
              localeController: localeController,
              onOpenDiagnostics: _openDebugInfo,
            ),
          ),
        );
      },
    );
  }
}
