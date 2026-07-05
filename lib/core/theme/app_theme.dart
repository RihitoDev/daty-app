import 'package:flutter/material.dart';

enum AppThemeType {
  deepOcean,
  roseMinimal,
  neonExplorer,
  sageTerracotta,
  midnightViolet,
}

class AppCustomTheme {
  final String name;
  final String mapThemeName;
  final Color bg;
  final Color card;
  final Color primary;
  final Color primaryLight;
  final Color primaryDark;
  final Color accent;
  final Color text;
  final Color text2;
  final Color muted;
  final Color mapBg1;
  final Color mapBg2;
  final Color mapPath;

  AppCustomTheme({
    required this.name,
    required this.mapThemeName,
    required this.bg,
    required this.card,
    required this.primary,
    required this.primaryLight,
    required this.primaryDark,
    required this.accent,
    required this.text,
    required this.text2,
    required this.muted,
    required this.mapBg1,
    required this.mapBg2,
    required this.mapPath,
  });

  static AppCustomTheme get midnightViolet => AppCustomTheme(
    name: 'Midnight Violet',
    mapThemeName: 'Sendero Cósmico',
    bg: const Color(0xFFF8F7FF),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFF8B5CF6),
    primaryLight: const Color(0xFFDDD6FE),
    primaryDark: const Color(0xFF6D28D9),
    accent: const Color(0xFFF59E0B),
    text: const Color(0xFF1E1533),
    text2: const Color(0xFF6B5F80),
    muted: const Color(0xFFA89EC0),
    mapBg1: const Color(0xFF0A0520),
    mapBg2: const Color(0xFF12082E),
    mapPath: const Color(0xFFF59E0B),
  );

  static AppCustomTheme get deepOcean => AppCustomTheme(
    name: 'Deep Ocean',
    mapThemeName: 'Fondo Marino',
    bg: const Color(0xFFF0F7FA),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFF0E7C86),
    primaryLight: const Color(0xFFB8E6EA),
    primaryDark: const Color(0xFF09545B),
    accent: const Color(0xFFF4845F),
    text: const Color(0xFF1A2B33),
    text2: const Color(0xFF5A7A8A),
    muted: const Color(0xFF94AEBB),
    mapBg1: const Color(0xFF071E26),
    mapBg2: const Color(0xFF0A2A35),
    mapPath: const Color(0xFF00D4AA),
  );

  static AppCustomTheme get roseMinimal => AppCustomTheme(
    name: 'Rose Minimal',
    mapThemeName: 'Jardín Twilight',
    bg: const Color(0xFFFFF7F7),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFFD4577A),
    primaryLight: const Color(0xFFF2D5DE),
    primaryDark: const Color(0xFFA13D5A),
    accent: const Color(0xFFE8A87C),
    text: const Color(0xFF2D2D2D),
    text2: const Color(0xFF6B6B6B),
    muted: const Color(0xFFA0A0A0),
    mapBg1: const Color(0xFF2D1525),
    mapBg2: const Color(0xFF1A0F1A),
    mapPath: const Color(0xFFE8A87C),
  );

  static AppCustomTheme get neonExplorer => AppCustomTheme(
    name: 'Neon Explorer',
    mapThemeName: 'Cyberpunk Grid',
    bg: const Color(0xFF0F0A1A),
    card: const Color(0xFF1A1230),
    primary: const Color(0xFF7C3AED),
    primaryLight: const Color(0xFFA78BFA),
    primaryDark: const Color(0xFF5B21B6),
    accent: const Color(0xFF00F5D4),
    text: const Color(0xFFF0EAFF),
    text2: const Color(0xFFA89CC8),
    muted: const Color(0xFF6B5E8A),
    mapBg1: const Color(0xFF080412),
    mapBg2: const Color(0xFF0F0825),
    mapPath: const Color(0xFF00F5D4),
  );

  static AppCustomTheme get sageTerracotta => AppCustomTheme(
    name: 'Sage & Terracotta',
    mapThemeName: 'Sendero Terroso',
    bg: const Color(0xFFFAF6F1),
    card: const Color(0xFFFFFFFF),
    primary: const Color(0xFFC4704B),
    primaryLight: const Color(0xFFF0D5C4),
    primaryDark: const Color(0xFF8B4D30),
    accent: const Color(0xFF7A9E7E),
    text: const Color(0xFF3D3029),
    text2: const Color(0xFF7A6E64),
    muted: const Color(0xFFAEA298),
    mapBg1: const Color(0xFF1A1208),
    mapBg2: const Color(0xFF2D1F0E),
    mapPath: const Color(0xFFC49A3C),
  );

  ThemeData get flutterTheme {
    return ThemeData(
      scaffoldBackgroundColor: bg,
      cardColor: card,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: accent,
        background: bg,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text2),
      ),
      useMaterial3: true,
    );
  }
}