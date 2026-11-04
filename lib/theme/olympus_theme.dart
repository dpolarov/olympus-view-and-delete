import 'package:flutter/material.dart';

/// Colors shared by the Android, Windows and Web interfaces.
///
/// Inspired by the matte camera-shell design used by the Olympus View website.
/// Keep image previews dark and let photos carry their own color.
abstract final class OlympusPalette {
  static const background = Color(0xFF141719);
  static const surface = Color(0xFF191D1E);
  static const card = Color(0xFF202425);
  static const raised = Color(0xFF292E30);
  static const border = Color(0xFF3A4041);
  static const text = Color(0xFFF2F1ED);
  static const secondaryText = Color(0xFFB4BABB);
  static const mutedText = Color(0xFF929D9E);
  static const coral = Color(0xFFEB7780);
  static const onCoral = Color(0xFF171819);
  static const success = Color(0xFF79C6A0);
  static const danger = Color(0xFFE58D85);
  static const photoBackground = Color(0xFF0F1213);
}

abstract final class OlympusTheme {
  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: OlympusPalette.coral,
      onPrimary: OlympusPalette.onCoral,
      primaryContainer: OlympusPalette.raised,
      onPrimaryContainer: OlympusPalette.text,
      secondary: OlympusPalette.secondaryText,
      onSecondary: OlympusPalette.background,
      secondaryContainer: OlympusPalette.raised,
      onSecondaryContainer: OlympusPalette.text,
      tertiary: OlympusPalette.success,
      onTertiary: OlympusPalette.background,
      surface: OlympusPalette.surface,
      surfaceDim: OlympusPalette.background,
      surfaceBright: OlympusPalette.raised,
      surfaceContainerLowest: OlympusPalette.background,
      surfaceContainerLow: OlympusPalette.surface,
      surfaceContainer: OlympusPalette.card,
      surfaceContainerHigh: OlympusPalette.raised,
      surfaceContainerHighest: OlympusPalette.raised,
      surfaceTint: Colors.transparent,
      inverseSurface: OlympusPalette.text,
      onInverseSurface: OlympusPalette.background,
      inversePrimary: OlympusPalette.coral,
      onSurface: OlympusPalette.text,
      onSurfaceVariant: OlympusPalette.secondaryText,
      outline: OlympusPalette.border,
      outlineVariant: OlympusPalette.border,
      error: OlympusPalette.danger,
      onError: OlympusPalette.background,
    ),
    scaffoldBackgroundColor: OlympusPalette.background,
    canvasColor: OlympusPalette.background,
    dividerColor: OlympusPalette.border,
    iconTheme: const IconThemeData(color: OlympusPalette.secondaryText),
    appBarTheme: const AppBarTheme(
      backgroundColor: OlympusPalette.surface,
      foregroundColor: OlympusPalette.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: OlympusPalette.text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      iconTheme: IconThemeData(color: OlympusPalette.text),
    ),
    cardTheme: CardThemeData(
      color: OlympusPalette.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: OlympusPalette.border, width: 0.6),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: OlympusPalette.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: OlympusPalette.card,
      modalBackgroundColor: OlympusPalette.card,
      showDragHandle: false,
      dragHandleColor: OlympusPalette.mutedText,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: OlympusPalette.raised,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: OlympusPalette.raised,
      contentTextStyle: const TextStyle(color: OlympusPalette.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: OlympusPalette.coral,
        foregroundColor: OlympusPalette.onCoral,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: OlympusPalette.coral,
        foregroundColor: OlympusPalette.onCoral,
        elevation: 0,
        minimumSize: const Size(0, 44),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: OlympusPalette.text,
        minimumSize: const Size(0, 44),
        side: const BorderSide(color: OlympusPalette.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: OlympusPalette.coral),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OlympusPalette.raised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: OlympusPalette.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: OlympusPalette.border),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: OlympusPalette.border,
      thickness: 0.7,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: OlympusPalette.coral,
    ),
  );
}
