import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) =>
          SettingsProvider(Provider.of<AuthProvider>(context, listen: false)),
      child: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, _) {
          final authProvider = Provider.of<AuthProvider>(context);
          final themeProvider = context.watch<ThemeProvider>();
          final customTheme = themeProvider.currentTheme;
          // Solo mostramos las opciones de pareja si el usuario tiene un vínculo activo
          final bool hasPartner = authProvider.userData != null &&
              authProvider.userData!['partnerId'] != null;

          return Scaffold(
            backgroundColor: customTheme.bg,
            appBar: AppBar(
              title: Text(
                'Ajustes',
                style: TextStyle(
                  color: customTheme.text,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: customTheme.card,
              iconTheme: IconThemeData(color: customTheme.text),
              elevation: 0,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Apariencia', customTheme),
                  _buildThemeSelector(themeProvider, customTheme),
                  const SizedBox(height: 25),
                  _buildSectionTitle('Cuenta', customTheme),
                  _buildSettingsCard([
                    ListTile(
                      leading: Icon(
                        Icons.person_outline,
                        color: customTheme.primary,
                      ),
                      title: Text(
                        'Mi Perfil',
                        style: TextStyle(color: customTheme.text),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: customTheme.muted,
                      ),
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ProfileScreen()));
                      },
                    ),
                  ], customTheme),
                  if (hasPartner) ...[
                    const SizedBox(height: 25),
                    _buildSectionTitle('Pareja', customTheme),
                    _buildSettingsCard([
                      ListTile(
                        leading:
                            const Icon(Icons.link_off, color: Colors.redAccent),
                        title: const Text('Desvincular Pareja',
                            style: TextStyle(color: Colors.redAccent)),
                        subtitle: const Text(
                            'Se eliminará el progreso, mapa y recuerdos compartidos'),
                        // Mostramos una rueda de carga si la acción está en proceso
                        trailing: settingsProvider.isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right,
                                color: Colors.grey),
                        // Bloqueamos el tap si ya se está procesando para evitar dobles clics
                        onTap: settingsProvider.isProcessing
                            ? null
                            : () => _showUnlinkConfirmation(
                                context, settingsProvider),
                      ),
                    ], customTheme),
                  ],
                  const SizedBox(height: 25),
                  _buildSectionTitle('Aventura en Solitario', customTheme),
                  _buildSettingsCard([
                    ListTile(
                      leading:
                          const Icon(Icons.refresh, color: Color(0xFF1976D2)),
                      title: const Text('Reiniciar Progreso Solo',
                          style: TextStyle(color: Color(0xFF1976D2))),
                      subtitle:
                          const Text('Borra tu mapa y recuerdos individuales'),
                      trailing: settingsProvider.isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right, color: Colors.grey),
                      onTap: settingsProvider.isProcessing
                          ? null
                          : () async {
                              // Pedimos confirmación porque borrar el progreso no tiene vuelta atrás
                              final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                        scrollable: true,
                                        insetPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 20, vertical: 24),
                                        title:
                                            const Text('¿Reiniciar progreso?'),
                                        content: const Text(
                                            'Se borrarán todas tus aventuras y fotos en solitario. Esta acción no se puede deshacer.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(
                                                  dialogContext, false),
                                              child: const Text('Cancelar')),
                                          ElevatedButton(
                                              onPressed: () => Navigator.pop(
                                                  dialogContext, true),
                                              child: const Text('Borrar')),
                                        ],
                                      ));
                              if (confirm == true) {
                                final error =
                                    await settingsProvider.resetSoloProgress();
                                // Nos aseguramos de que la pantalla siga montada antes de mostrar el mensaje
                                if (context.mounted) {
                                  if (error != null) {
                                    CustomSnackBar.showError(context, error);
                                  } else {
                                    CustomSnackBar.showSuccess(
                                        context, 'Progreso reiniciado');
                                  }
                                }
                              }
                            },
                    ),
                  ], customTheme),
                  const SizedBox(height: 25),
                  _buildSectionTitle('Sesión', customTheme),
                  _buildSettingsCard([
                    ListTile(
                      leading: Icon(Icons.logout, color: customTheme.text2),
                      title: Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          color: customTheme.text,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: customTheme.muted,
                      ),
                      onTap: () => _showLogoutConfirmation(context),
                    ),
                  ], customTheme),
                  const SizedBox(height: 50),
                  Center(
                    child: Text(
                      'Daty v1.0.0',
                      style: TextStyle(color: customTheme.muted, fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppCustomTheme customTheme) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: customTheme.primary,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    List<Widget> children,
    AppCustomTheme customTheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: customTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: customTheme.muted.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: customTheme.primary.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Usamos Material transparente para mantener el efecto de ripple (la onda al tocar) en las opciones
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildThemeSelector(
    ThemeProvider themeProvider,
    AppCustomTheme customTheme,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: AppThemeType.values.map((themeType) {
            final selected = themeProvider.currentThemeType == themeType;
            final colors = themeProvider.previewColorsFor(themeType);

            return Semantics(
              button: true,
              selected: selected,
              label: 'Tema ${themeProvider.labelFor(themeType)}',
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => themeProvider.setTheme(themeType),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: cardWidth,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: customTheme.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? customTheme.primary
                          : customTheme.muted.withValues(alpha: 0.18),
                      width: selected ? 2 : 1,
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color:
                                  customTheme.primary.withValues(alpha: 0.16),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            themeProvider.emojiFor(themeType),
                            style: const TextStyle(fontSize: 20),
                          ),
                          const Spacer(),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: customTheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: colors
                            .map(
                              (color) => Container(
                                width: 24,
                                height: 24,
                                margin: const EdgeInsets.only(right: 6),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        themeProvider.labelFor(themeType),
                        style: TextStyle(
                          color: customTheme.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        themeProvider.descriptionFor(themeType),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: customTheme.text2,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que quieres salir de tu cuenta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15))),
            onPressed: () async {
              Navigator.pop(dialogContext);

              await Provider.of<AuthProvider>(
                context,
                listen: false,
              ).signOut();

              if (!context.mounted) return;

              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showUnlinkConfirmation(
      BuildContext context, SettingsProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('💔 Romper Vínculo',
            style: TextStyle(color: Colors.redAccent)),
        content: const Text(
            'Esta acción es irreversible. Se eliminará todo el progreso de su mapa de pareja y recuerdos compartidos. ¿Están seguros?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15))),
            onPressed: () async {
              Navigator.pop(dialogContext);
              final error = await provider.unlinkPartner();

              // Verificamos que el contexto siga vivo después del await
              if (context.mounted) {
                if (error != null) {
                  CustomSnackBar.showError(context, error);
                } else {
                  CustomSnackBar.showSuccess(
                      context, 'Se ha roto el vínculo exitosamente');
                }
              }
            },
            child: const Text('Desvincular',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
