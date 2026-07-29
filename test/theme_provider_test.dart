import 'package:flutter_test/flutter_test.dart';
import 'package:magic_dates/core/providers/theme_provider.dart';
import 'package:magic_dates/core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recupera el tema guardado al iniciar', () async {
    SharedPreferences.setMockInitialValues({'daty_theme': 'forest'});
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(preferences);

    expect(provider.currentThemeType, AppThemeType.forest);
    expect(provider.currentTheme.name, 'Bosque');

    provider.dispose();
  });

  test('guarda una nueva selección', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(preferences);

    await provider.setTheme(AppThemeType.sunset);

    expect(provider.currentThemeType, AppThemeType.sunset);
    expect(preferences.getString('daty_theme'), 'sunset');

    provider.dispose();
  });

  test('todas las paletas ofrecen tres colores de vista previa', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(preferences);

    for (final themeType in AppThemeType.values) {
      expect(provider.previewColorsFor(themeType), hasLength(3));
      expect(provider.labelFor(themeType), isNotEmpty);
      expect(provider.descriptionFor(themeType), isNotEmpty);
    }

    provider.dispose();
  });
}
