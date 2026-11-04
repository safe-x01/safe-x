import 'package:flutter/material.dart';

/// Colors from the SafeAlert Figma screens.
class SA {
  SA._();
  static const navy = Color(0xFF0B2545);
  static const teal = Color(0xFF0E8C7F);
  static const tealLight = Color(0xFFE6F5F3);
  static const red = Color(0xFFE5484D);
  static const redLight = Color(0xFFFDECEC);
  static const redDark = Color(0xFFB42318);
  static const amber = Color(0xFFF59E0B);
  static const amberLight = Color(0xFFFEF3C7);
  static const amberDark = Color(0xFFB45309);
  static const blue = Color(0xFF2F6FED);
  static const blueLight = Color(0xFFE8F0FE);
  static const green = Color(0xFF16A34A);
  static const greenLight = Color(0xFFDCFCE7);
  static const purple = Color(0xFF7C3AED);
  static const purpleLight = Color(0xFFF3E8FF);
  static const text = Color(0xFF0F172A);
  static const text2 = Color(0xFF475569);
  static const muted = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const bg = Color(0xFFF4F6FA);
  static const card = Color(0xFFFFFFFF);
}

/// White card with the thin border used on every screen.
BoxDecoration saCard({Color color = SA.card, Color border = SA.border}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border),
    );

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: SA.navy, primary: SA.navy, secondary: SA.teal, error: SA.red),
    scaffoldBackgroundColor: SA.bg,
    fontFamily: 'Sarabun', // add the font in pubspec when the team has the files; falls back to system Thai font
  );
  return base.copyWith(
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
  );
}
