import 'package:flutter/material.dart';

enum AppThemeType {
  system,
  light,
  dark,
  ocean,
  forest,
  sunset,
  love,
}

class AppCustomTheme {
  const AppCustomTheme({
    required this.name,
    required this.description,
    required this.emoji,
    required this.mapThemeName,
    required this.brightness,
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

  final String name;
  final String description;
  final String emoji;
  final String mapThemeName;
  final Brightness brightness;
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

  List<Color> get previewColors => [primaryDark, primary, accent];

  static AppCustomTheme lerp(
    AppCustomTheme from,
    AppCustomTheme to,
    double progress,
  ) {
    Color blend(Color start, Color end) =>
        Color.lerp(start, end, progress) ?? end;

    return AppCustomTheme(
      name: to.name,
      description: to.description,
      emoji: to.emoji,
      mapThemeName: to.mapThemeName,
      brightness: progress < 0.5 ? from.brightness : to.brightness,
      bg: blend(from.bg, to.bg),
      card: blend(from.card, to.card),
      primary: blend(from.primary, to.primary),
      primaryLight: blend(from.primaryLight, to.primaryLight),
      primaryDark: blend(from.primaryDark, to.primaryDark),
      accent: blend(from.accent, to.accent),
      text: blend(from.text, to.text),
      text2: blend(from.text2, to.text2),
      muted: blend(from.muted, to.muted),
      mapBg1: blend(from.mapBg1, to.mapBg1),
      mapBg2: blend(from.mapBg2, to.mapBg2),
      mapPath: blend(from.mapPath, to.mapPath),
    );
  }

  bool get isDark => brightness == Brightness.dark;

  Color get elevatedSurface => isDark
      ? Color.alphaBlend(Colors.white.withValues(alpha: 0.045), card)
      : card;

  Color get softSurface => Color.alphaBlend(
        primary.withValues(alpha: isDark ? 0.09 : 0.045),
        card,
      );

  Color get outline => isDark
      ? Colors.white.withValues(alpha: 0.11)
      : muted.withValues(alpha: 0.2);

  Color get shadow => isDark
      ? Colors.black.withValues(alpha: 0.38)
      : primary.withValues(alpha: 0.1);

  List<Color> adventureGradient(Color adventureColor) => [
        Color.alphaBlend(
          adventureColor.withValues(alpha: isDark ? 0.22 : 0.16),
          elevatedSurface,
        ),
        Color.alphaBlend(
          adventureColor.withValues(alpha: isDark ? 0.09 : 0.06),
          elevatedSurface,
        ),
        elevatedSurface,
      ];

  static const light = AppCustomTheme(
    name: 'Claro',
    description: 'Limpio y luminoso',
    emoji: '☀️',
    mapThemeName: 'Sendero luminoso',
    brightness: Brightness.light,
    bg: Color(0xFFF8F7FF),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFF7653D6),
    primaryLight: Color(0xFFE5DEFA),
    primaryDark: Color(0xFF5133A5),
    accent: Color(0xFFF2A65A),
    text: Color(0xFF211936),
    text2: Color(0xFF685E7B),
    muted: Color(0xFFA59DB2),
    mapBg1: Color(0xFFF1EDFF),
    mapBg2: Color(0xFFE4DCFA),
    mapPath: Color(0xFFF2A65A),
  );

  static const dark = AppCustomTheme(
    name: 'Noche',
    description: 'Elegante y cómodo',
    emoji: '🌙',
    mapThemeName: 'Sendero cósmico',
    brightness: Brightness.dark,
    bg: Color(0xFF0F0B18),
    card: Color(0xFF1B1528),
    primary: Color(0xFF9B7AF0),
    primaryLight: Color(0xFF302348),
    primaryDark: Color(0xFF7653D6),
    accent: Color(0xFFFFC56E),
    text: Color(0xFFF5F1FF),
    text2: Color(0xFFC1B6D5),
    muted: Color(0xFF80758F),
    mapBg1: Color(0xFF08050F),
    mapBg2: Color(0xFF171024),
    mapPath: Color(0xFFFFC56E),
  );

  static const ocean = AppCustomTheme(
    name: 'Océano',
    description: 'Tecnológico y fresco',
    emoji: '💙',
    mapThemeName: 'Fondo marino',
    brightness: Brightness.dark,
    bg: Color(0xFF061923),
    card: Color(0xFF0D2935),
    primary: Color(0xFF23A9F2),
    primaryLight: Color(0xFF123D50),
    primaryDark: Color(0xFF0875B7),
    accent: Color(0xFF78D8FF),
    text: Color(0xFFF1FAFF),
    text2: Color(0xFFB1D4E3),
    muted: Color(0xFF658B9C),
    mapBg1: Color(0xFF03131B),
    mapBg2: Color(0xFF082E40),
    mapPath: Color(0xFF47C6FF),
  );

  static const forest = AppCustomTheme(
    name: 'Bosque',
    description: 'Natural y aventurero',
    emoji: '💚',
    mapThemeName: 'Bosque encantado',
    brightness: Brightness.dark,
    bg: Color(0xFF10251E),
    card: Color(0xFF1B352B),
    primary: Color(0xFF69A77E),
    primaryLight: Color(0xFF294C3D),
    primaryDark: Color(0xFF3F7654),
    accent: Color(0xFFB9E5C8),
    text: Color(0xFFF1FAF3),
    text2: Color(0xFFBDD3C4),
    muted: Color(0xFF789486),
    mapBg1: Color(0xFF091A14),
    mapBg2: Color(0xFF183527),
    mapPath: Color(0xFFA5DBB5),
  );

  static const sunset = AppCustomTheme(
    name: 'Atardecer',
    description: 'Cálido y optimista',
    emoji: '🧡',
    mapThemeName: 'Ruta dorada',
    brightness: Brightness.light,
    bg: Color(0xFFFFF5EC),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFFE06F45),
    primaryLight: Color(0xFFFFDCCB),
    primaryDark: Color(0xFFB64C2D),
    accent: Color(0xFFF2C66D),
    text: Color(0xFF392019),
    text2: Color(0xFF805F54),
    muted: Color(0xFFB39A90),
    mapBg1: Color(0xFF351714),
    mapBg2: Color(0xFF5A2820),
    mapPath: Color(0xFFF5C96B),
  );

  static const love = AppCustomTheme(
    name: 'Amor',
    description: 'Romántico y especial',
    emoji: '❤️',
    mapThemeName: 'Jardín de corazones',
    brightness: Brightness.light,
    bg: Color(0xFFFFF4F8),
    card: Color(0xFFFFFFFF),
    primary: Color(0xFFD64D75),
    primaryLight: Color(0xFFF7D4E0),
    primaryDark: Color(0xFF9F294E),
    accent: Color(0xFFB88AE5),
    text: Color(0xFF351927),
    text2: Color(0xFF7D5969),
    muted: Color(0xFFB398A4),
    mapBg1: Color(0xFF321020),
    mapBg2: Color(0xFF571B36),
    mapPath: Color(0xFFEAA0C0),
  );

  ThemeData get flutterTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: brightness,
      primary: primary,
      secondary: accent,
      surface: card,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      cardColor: card,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: card,
        foregroundColor: text,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: primaryLight,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(color: text, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: primaryLight.withValues(alpha: 0.35),
        hintStyle: TextStyle(color: muted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: muted.withValues(alpha: 0.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: primary, width: 2),
        ),
      ),
      textTheme: TextTheme(
        headlineSmall: TextStyle(color: text, fontWeight: FontWeight.w800),
        titleLarge: TextStyle(color: text, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: text, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: text),
        bodyMedium: TextStyle(color: text2),
      ),
      dividerColor: muted.withValues(alpha: 0.2),
    );
  }
}
