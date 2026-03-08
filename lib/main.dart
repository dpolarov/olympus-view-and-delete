import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const OlympusApp());
}

class OlympusApp extends StatelessWidget {
  const OlympusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Olympus View',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFE94560),
          secondary: const Color(0xFF0F3460),
          surface: const Color(0xFF1A1A2E),
          error: const Color(0xFFE74C3C),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          elevation: 0,
        ),
        cardTheme: const CardTheme(
          color: Color(0xFF1A1A2E),
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
