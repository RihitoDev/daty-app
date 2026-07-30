import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeProvider(this._preferences) {
    WidgetsBinding.instance.addObserver(this);
    _restoreSelection();
    _normalizeSelection();
    _displayTheme = previewTheme(_currentMode, _currentPalette);
  }

  static const _modeKey = 'daty_theme_mode';
  static const _paletteKey = 'daty_theme_palette';
  static const _legacyKey = 'daty_theme';
  static const _transitionDuration = Duration(milliseconds: 380);

  final SharedPreferences _preferences;

  AppBrightnessMode _currentMode = AppBrightnessMode.system;
  AppPaletteType _currentPalette = AppPaletteType.daty;
  late AppCustomTheme _displayTheme;
  Timer? _transitionTimer;

  AppBrightnessMode get currentMode => _currentMode;
  AppPaletteType get currentPalette => _currentPalette;
  AppCustomTheme get currentTheme => _displayTheme;

  Brightness get _systemBrightness =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness;

  void _restoreSelection() {
    final savedMode = _preferences.getString(_modeKey);
    final savedPalette = _preferences.getString(_paletteKey);

    if (savedMode != null || savedPalette != null) {
      _currentMode = AppBrightnessMode.values.firstWhere(
        (mode) => mode.name == savedMode,
        orElse: () => AppBrightnessMode.system,
      );
      _currentPalette = AppPaletteType.values.firstWhere(
        (palette) => palette.name == savedPalette,
        orElse: () => AppPaletteType.daty,
      );
      return;
    }

    switch (_preferences.getString(_legacyKey)) {
      case 'light':
        _currentMode = AppBrightnessMode.light;
      case 'dark':
        _currentMode = AppBrightnessMode.dark;
      case 'ocean':
        _currentMode = AppBrightnessMode.dark;
        _currentPalette = AppPaletteType.ocean;
      case 'forest':
        _currentMode = AppBrightnessMode.dark;
        _currentPalette = AppPaletteType.forest;
      case 'sunset':
        _currentMode = AppBrightnessMode.light;
        _currentPalette = AppPaletteType.sunset;
      case 'love':
        _currentMode = AppBrightnessMode.light;
        _currentPalette = AppPaletteType.love;
      default:
        _currentMode = AppBrightnessMode.system;
        _currentPalette = AppPaletteType.daty;
    }
  }

  AppCustomTheme previewTheme(
    AppBrightnessMode mode,
    AppPaletteType palette,
  ) {
    final brightness = switch (mode) {
      AppBrightnessMode.system => _systemBrightness,
      AppBrightnessMode.light => Brightness.light,
      AppBrightnessMode.dark => Brightness.dark,
    };

    return switch ((palette, brightness)) {
      (AppPaletteType.daty, Brightness.light) => AppCustomTheme.light,
      (AppPaletteType.daty, Brightness.dark) => AppCustomTheme.dark,
      (AppPaletteType.ocean, Brightness.light) => AppCustomTheme.oceanLight,
      (AppPaletteType.ocean, Brightness.dark) => AppCustomTheme.ocean,
      (AppPaletteType.forest, Brightness.light) => AppCustomTheme.forestLight,
      (AppPaletteType.forest, Brightness.dark) => AppCustomTheme.forest,
      (AppPaletteType.sunset, Brightness.light) => AppCustomTheme.sunset,
      (AppPaletteType.sunset, Brightness.dark) => AppCustomTheme.sunsetDark,
      (AppPaletteType.love, Brightness.light) => AppCustomTheme.love,
      (AppPaletteType.love, Brightness.dark) => AppCustomTheme.loveDark,
    };
  }

  String modeLabel(AppBrightnessMode mode) => switch (mode) {
        AppBrightnessMode.system => 'Sistema',
        AppBrightnessMode.light => 'Claro',
        AppBrightnessMode.dark => 'Oscuro',
      };

  String paletteLabel(AppPaletteType palette) =>
      previewTheme(AppBrightnessMode.light, palette).name;

  String paletteDescription(AppPaletteType palette) =>
      previewTheme(AppBrightnessMode.light, palette).description;

  String paletteEmoji(AppPaletteType palette) =>
      previewTheme(AppBrightnessMode.light, palette).emoji;

  AppBrightnessMode modeForPalette(AppPaletteType palette) => switch (palette) {
        AppPaletteType.daty => AppBrightnessMode.system,
        AppPaletteType.ocean => AppBrightnessMode.dark,
        AppPaletteType.forest => AppBrightnessMode.dark,
        AppPaletteType.sunset => AppBrightnessMode.light,
        AppPaletteType.love => AppBrightnessMode.light,
      };

  Future<void> setAppearance(
    AppBrightnessMode mode,
    AppPaletteType palette,
  ) async {
    if (palette != AppPaletteType.daty) {
      mode = modeForPalette(palette);
    }

    if (_currentMode == mode && _currentPalette == palette) return;

    _currentMode = mode;
    _currentPalette = palette;
    _animateTo(previewTheme(mode, palette));

    await Future.wait([
      _preferences.setString(_modeKey, mode.name),
      _preferences.setString(_paletteKey, palette.name),
      _preferences.remove(_legacyKey),
    ]);
  }

  void _normalizeSelection() {
    if (_currentPalette != AppPaletteType.daty) {
      _currentMode = modeForPalette(_currentPalette);
    }
  }

  void _animateTo(AppCustomTheme targetTheme) {
    _transitionTimer?.cancel();
    final initialTheme = _displayTheme;
    final stopwatch = Stopwatch()..start();

    _transitionTimer = Timer.periodic(
      const Duration(milliseconds: 16),
      (timer) {
        final rawProgress =
            stopwatch.elapsedMilliseconds / _transitionDuration.inMilliseconds;
        final progress = rawProgress.clamp(0.0, 1.0).toDouble();
        final curvedProgress = Curves.easeInOutCubic.transform(progress);

        _displayTheme = AppCustomTheme.lerp(
          initialTheme,
          targetTheme,
          curvedProgress,
        );
        notifyListeners();

        if (progress >= 1) {
          timer.cancel();
          stopwatch.stop();
          _displayTheme = targetTheme;
          notifyListeners();
        }
      },
    );
  }

  @override
  void didChangePlatformBrightness() {
    if (_currentMode == AppBrightnessMode.system) {
      _animateTo(previewTheme(_currentMode, _currentPalette));
    }
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
