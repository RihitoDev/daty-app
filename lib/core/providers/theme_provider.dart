import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  ThemeProvider(this._preferences) {
    WidgetsBinding.instance.addObserver(this);
    final savedValue = _preferences.getString(_preferenceKey);
    _currentThemeType = AppThemeType.values.firstWhere(
      (theme) => theme.name == savedValue,
      orElse: () => AppThemeType.system,
    );
    _displayTheme = _resolvedTheme(_currentThemeType);
  }

  static const _preferenceKey = 'daty_theme';
  static const _transitionDuration = Duration(milliseconds: 380);
  final SharedPreferences _preferences;

  AppThemeType _currentThemeType = AppThemeType.system;
  late AppCustomTheme _displayTheme;
  Timer? _transitionTimer;

  AppThemeType get currentThemeType => _currentThemeType;

  AppCustomTheme get currentTheme => _displayTheme;

  AppThemeType get _systemThemeType =>
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark
          ? AppThemeType.dark
          : AppThemeType.light;

  AppCustomTheme themeFor(AppThemeType type) {
    switch (type) {
      case AppThemeType.system:
        return themeFor(_systemThemeType);
      case AppThemeType.light:
        return AppCustomTheme.light;
      case AppThemeType.dark:
        return AppCustomTheme.dark;
      case AppThemeType.ocean:
        return AppCustomTheme.ocean;
      case AppThemeType.forest:
        return AppCustomTheme.forest;
      case AppThemeType.sunset:
        return AppCustomTheme.sunset;
      case AppThemeType.love:
        return AppCustomTheme.love;
    }
  }

  AppCustomTheme _resolvedTheme(AppThemeType type) {
    final resolvedType = type == AppThemeType.system ? _systemThemeType : type;
    return themeFor(resolvedType);
  }

  String labelFor(AppThemeType type) =>
      type == AppThemeType.system ? 'Sistema' : themeFor(type).name;

  String emojiFor(AppThemeType type) =>
      type == AppThemeType.system ? '📱' : themeFor(type).emoji;

  String descriptionFor(AppThemeType type) => type == AppThemeType.system
      ? 'Claro u oscuro según tu celular'
      : themeFor(type).description;

  List<Color> previewColorsFor(AppThemeType type) => type == AppThemeType.system
      ? [
          AppCustomTheme.light.primary,
          AppCustomTheme.dark.card,
          AppCustomTheme.dark.accent,
        ]
      : themeFor(type).previewColors;

  Future<void> setTheme(AppThemeType themeType) async {
    if (_currentThemeType == themeType) return;
    _currentThemeType = themeType;
    _animateTo(_resolvedTheme(themeType));

    await _preferences.setString(_preferenceKey, themeType.name);
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
    if (_currentThemeType == AppThemeType.system) {
      _animateTo(_resolvedTheme(AppThemeType.system));
    }
  }

  @override
  void dispose() {
    _transitionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
