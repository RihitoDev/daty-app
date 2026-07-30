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

    expect(provider.currentMode, AppBrightnessMode.dark);
    expect(provider.currentPalette, AppPaletteType.forest);
    expect(provider.currentTheme.name, 'Bosque');

    provider.dispose();
  });

  test('guarda una nueva selección', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(preferences);

    await provider.setAppearance(
      AppBrightnessMode.light,
      AppPaletteType.sunset,
    );

    expect(provider.currentMode, AppBrightnessMode.light);
    expect(provider.currentPalette, AppPaletteType.sunset);
    expect(preferences.getString('daty_theme_mode'), 'light');
    expect(preferences.getString('daty_theme_palette'), 'sunset');

    provider.dispose();
  });

  test('todas las paletas ofrecen tres colores de vista previa', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(preferences);

    for (final palette in AppPaletteType.values) {
      expect(
        provider.previewTheme(AppBrightnessMode.light, palette).previewColors,
        hasLength(3),
      );
      expect(provider.paletteLabel(palette), isNotEmpty);
      expect(provider.paletteDescription(palette), isNotEmpty);
    }

    provider.dispose();
  });

  test('un tema de color no se combina con un modo independiente', () async {
    SharedPreferences.setMockInitialValues({
      'daty_theme_mode': 'light',
      'daty_theme_palette': 'ocean',
    });
    final preferences = await SharedPreferences.getInstance();
    final provider = ThemeProvider(preferences);

    expect(provider.currentPalette, AppPaletteType.ocean);
    expect(provider.currentMode, AppBrightnessMode.dark);

    await provider.setAppearance(
      AppBrightnessMode.dark,
      AppPaletteType.love,
    );

    expect(provider.currentPalette, AppPaletteType.love);
    expect(provider.currentMode, AppBrightnessMode.light);

    provider.dispose();
  });
}
