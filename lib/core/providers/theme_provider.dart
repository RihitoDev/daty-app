import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AppThemeType _currentThemeType = AppThemeType.midnightViolet;

  AppThemeType get currentThemeType => _currentThemeType;

  AppCustomTheme get currentTheme {
    switch (_currentThemeType) {
      case AppThemeType.deepOcean:
        return AppCustomTheme.deepOcean;
      case AppThemeType.roseMinimal:
        return AppCustomTheme.roseMinimal;
      case AppThemeType.neonExplorer:
        return AppCustomTheme.neonExplorer;
      case AppThemeType.sageTerracotta:
        return AppCustomTheme.sageTerracotta;
      default:
        return AppCustomTheme.midnightViolet;
    }
  }

  void setTheme(AppThemeType themeType) {
    _currentThemeType = themeType;
    notifyListeners();
  }
}