import 'package:flutter/material.dart';

import '../constants.dart';

/// Shared camera-shell styling for Olympus View.
/// Calm graphite surfaces, warm off-white text and restrained coral actions.
/// Green is reserved for transfer success / downloaded indicators.
abstract final class OlympusTheme {
  static const canvas = Color(0xFF141719);
  static const surface = Color(0xFF191D1E);
  static const raised = Color(0xFF202425);
  static const elevated = Color(0xFF292E30);
  static const ink = Color(0xFFF2F1ED);
  static const inkSecondary = Color(0xFFB4BABB);
  static const inkMuted = Color(0xFF90999B);

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: kPrimaryColor,
      onPrimary: canvas,
      primaryContainer: Color(0xFF483236),
      onPrimaryContainer: ink,
      secondary: kAccentColor,
      onSecondary: canvas,
      secondaryContainer: Color(0xFF293B34),
      onSecondaryContainer: ink,
      surface: surface,
      onSurface: ink,
      surfaceContainerLowest: canvas,
      surfaceContainerLow: surface,
      surfaceContainer: raised,
      surfaceContainerHigh: elevated,
      surfaceContainerHighest: Color(0xFF333839),
      outline: Color(0xFF666D6C),
      outlineVariant: kBorderColor,
      error: kErrorColor,
      onError: canvas,
    ),
    scaffoldBackgroundColor: canvas,
    canvasColor: canvas,
    dividerColor: kBorderColor,
    splashFactory: InkRipple.splashFactory,
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.3,
        color: ink,
      ),
      iconTheme: IconThemeData(color: ink),
      actionsIconTheme: IconThemeData(color: inkSecondary),
    ),
    cardTheme: const CardThemeData(
      color: raised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        side: BorderSide(color: kBorderColor, width: 0.7),
      ),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: ink, fontSize: 30, fontWeight: FontWeight.w500),
      titleLarge: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w500),
      titleMedium: TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: ink, fontSize: 16),
      bodyMedium: TextStyle(color: inkSecondary, fontSize: 14),
      bodySmall: TextStyle(color: inkMuted, fontSize: 12),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
    ),
    iconTheme: const IconThemeData(color: inkSecondary, size: 22),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        foregroundColor: canvas,
        backgroundColor: kButtonColor,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: canvas,
        backgroundColor: kButtonColor,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ink,
        side: const BorderSide(color: kBorderColor),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: kPrimaryColor),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: inkSecondary),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kPrimaryColor,
      linearTrackColor: kBorderColor,
      circularTrackColor: kBorderColor,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: elevated,
      contentTextStyle: TextStyle(color: ink),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: raised,
      modalBackgroundColor: raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    popupMenuTheme: const PopupMenuThemeData(
      color: raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimaryColor, width: 1.5),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: inkSecondary,
      textColor: ink,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    ),
  );
}
