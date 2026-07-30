import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late AppBrightnessMode _draftMode;
  late AppPaletteType _draftPalette;
  bool _initialized = false;
  bool _applying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final provider = context.read<ThemeProvider>();
    _draftMode = provider.currentMode;
    _draftPalette = provider.currentPalette;
    _initialized = true;
  }

  Future<void> _apply() async {
    if (_applying) return;
    setState(() => _applying = true);

    await context.read<ThemeProvider>().setAppearance(
          _draftMode,
          _draftPalette,
        );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final appTheme = provider.currentTheme;
    final previewTheme = provider.previewTheme(_draftMode, _draftPalette);
    final hasChanges = provider.currentMode != _draftMode ||
        provider.currentPalette != _draftPalette;

    return Scaffold(
      backgroundColor: appTheme.bg,
      appBar: AppBar(
        title: Text(
          'Apariencia',
          style: TextStyle(
            color: appTheme.text,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: appTheme.card,
        foregroundColor: appTheme.text,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
        children: [
          _buildPreview(previewTheme),
          const SizedBox(height: 28),
          _sectionTitle('Modo', appTheme),
          const SizedBox(height: 10),
          _buildModeSelector(provider, appTheme),
          const SizedBox(height: 28),
          _sectionTitle('Temas de color', appTheme),
          const SizedBox(height: 10),
          ...AppPaletteType.values
              .where((palette) => palette != AppPaletteType.daty)
              .map(
                (palette) => _buildPaletteOption(
                  provider,
                  appTheme,
                  palette,
                ),
              ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _applying ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: appTheme.text2,
                  side: BorderSide(color: appTheme.outline),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: hasChanges && !_applying ? _apply : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(17),
                  ),
                ),
                child: _applying
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(AppCustomTheme theme) {
    return TweenAnimationBuilder<AppCustomTheme>(
      tween: _AppThemeTween(begin: theme, end: theme),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeInOutCubic,
      builder: (context, animatedTheme, _) {
        return _buildPhonePreview(animatedTheme);
      },
    );
  }

  Widget _buildPhonePreview(AppCustomTheme theme) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 330),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFF29272E),
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              color: theme.bg,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 9, 15, 7),
                    child: Row(
                      children: [
                        Text(
                          '9:41',
                          style: TextStyle(
                            color: theme.text,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.signal_cellular_alt_rounded,
                            color: theme.text, size: 12),
                        const SizedBox(width: 4),
                        Icon(Icons.wifi_rounded, color: theme.text, size: 12),
                        const SizedBox(width: 4),
                        Icon(Icons.battery_full_rounded,
                            color: theme.text, size: 13),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 7, 15, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 29,
                              height: 29,
                              decoration: BoxDecoration(
                                color: theme.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.pets_rounded,
                                color: theme.primary,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Daty',
                              style: TextStyle(
                                color: theme.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Icon(
                              Icons.notifications_none_rounded,
                              color: theme.text2,
                              size: 19,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                theme.primaryDark,
                                theme.primary,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: theme.primary.withValues(alpha: 0.2),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.calendar_month_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TU PRÓXIMA HISTORIA',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 7,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.7,
                                      ),
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Hola, aventurero',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 13),
                        _miniAdventureCard(
                          theme: theme,
                          accent: const Color(0xFFD81B60),
                          icon: Icons.favorite_border_rounded,
                          title: 'Aventura en pareja',
                          subtitle: 'Vincúlate con alguien',
                        ),
                        const SizedBox(height: 9),
                        _miniAdventureCard(
                          theme: theme,
                          accent: const Color(0xFF1976D2),
                          icon: Icons.backpack_outlined,
                          title: 'Aventura en solitario',
                          subtitle: 'Mi camino personal',
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 49,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 11),
                    decoration: BoxDecoration(
                      color: theme.elevatedSurface,
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(color: theme.outline),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _previewNavItem(
                            Icons.explore_rounded, 'Inicio', true, theme),
                        _previewNavItem(
                            Icons.auto_stories_outlined, 'Álbum', false, theme),
                        _previewNavItem(
                            Icons.settings_outlined, 'Ajustes', false, theme),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniAdventureCard({
    required AppCustomTheme theme,
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: theme.adventureGradient(accent)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Container(
            width: 37,
            height: 37,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.text,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.text2, fontSize: 9),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: accent,
            size: 13,
          ),
        ],
      ),
    );
  }

  Widget _previewNavItem(
    IconData icon,
    String label,
    bool selected,
    AppCustomTheme theme,
  ) {
    final color = selected ? theme.primary : theme.muted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildModeSelector(
    ThemeProvider provider,
    AppCustomTheme appTheme,
  ) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: appTheme.softSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: AppBrightnessMode.values.map((mode) {
          final selected =
              _draftPalette == AppPaletteType.daty && mode == _draftMode;
          return Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() {
                _draftMode = mode;
                _draftPalette = AppPaletteType.daty;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected ? appTheme.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: appTheme.shadow,
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  provider.modeLabel(mode),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? appTheme.primary : appTheme.text2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaletteOption(
    ThemeProvider provider,
    AppCustomTheme appTheme,
    AppPaletteType palette,
  ) {
    final selected = palette == _draftPalette;
    final paletteMode = provider.modeForPalette(palette);
    final paletteTheme = provider.previewTheme(paletteMode, palette);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() {
          _draftPalette = palette;
          _draftMode = paletteMode;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: appTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? appTheme.primary : appTheme.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                provider.paletteEmoji(palette),
                style: const TextStyle(fontSize: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.paletteLabel(palette),
                      style: TextStyle(
                        color: appTheme.text,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      provider.paletteDescription(palette),
                      style: TextStyle(color: appTheme.text2, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Row(
                children: paletteTheme.previewColors
                    .map(
                      (color) => Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? appTheme.primary : appTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, AppCustomTheme theme) {
    return Text(
      title,
      style: TextStyle(
        color: theme.text,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AppThemeTween extends Tween<AppCustomTheme> {
  _AppThemeTween({
    required super.begin,
    required super.end,
  });

  @override
  AppCustomTheme lerp(double t) {
    return AppCustomTheme.lerp(begin!, end!, t);
  }
}
