import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class AppTheme {
  AppTheme._();

  static const _seedColor = Color(0xFF2563EB); // blue-600

  /// Routes the framework's automatic icons (AppBar back/close/drawer buttons)
  /// through Material Symbols so they render with the same font as the rest of
  /// the app — the built-in MaterialIcons glyphs were showing as tofu boxes.
  static ActionIconThemeData _actionIcons() => ActionIconThemeData(
        backButtonIconBuilder: (_) => const Icon(Symbols.arrow_back),
        closeButtonIconBuilder: (_) => const Icon(Symbols.close),
        drawerButtonIconBuilder: (_) => const Icon(Symbols.menu),
        endDrawerButtonIconBuilder: (_) => const Icon(Symbols.menu),
      );

  static ThemeData light() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
        actionIconTheme: _actionIcons(),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
        ),
      );

  static ThemeData dark() => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        actionIconTheme: _actionIcons(),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade800),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
        ),
      );
}
