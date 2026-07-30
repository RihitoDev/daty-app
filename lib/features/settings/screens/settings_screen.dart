import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import 'appearance_screen.dart';
import 'delete_account_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';
import 'security_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(context.read<AuthProvider>()),
      child: const _SettingsBody(),
    );
  }
}

class _SettingsBody extends StatelessWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final profile = context.watch<ProfileProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final colors = themeProvider.currentTheme;
    final hasPartner = auth.userData?['partnerId'] != null;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Ajustes',
          style: TextStyle(color: colors.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _profileHeader(context, profile, auth, colors),
          const SizedBox(height: 28),
          _section('Cuenta', colors),
          _card(colors, [
            _tile(
              context,
              colors,
              Icons.shield_outlined,
              'Privacidad',
              'Visibilidad y permisos de datos',
              const PrivacyScreen(),
            ),
            _divider(colors),
            _tile(
              context,
              colors,
              Icons.security_outlined,
              'Seguridad',
              'Contraseña, autenticación y sesiones',
              const SecurityScreen(),
            ),
          ]),
          const SizedBox(height: 28),
          _section('Personalización', colors),
          _card(colors, [
            _appearanceTile(context, themeProvider, colors),
            _divider(colors),
            _tile(
              context,
              colors,
              Icons.notifications_none_rounded,
              'Notificaciones',
              'Elige qué avisos quieres recibir',
              const NotificationsScreen(),
            ),
          ]),
          const SizedBox(height: 28),
          _section('Pareja y aventuras', colors),
          _card(colors, [
            if (hasPartner) ...[
              ListTile(
                leading: const Icon(Icons.link_off, color: Colors.redAccent),
                title: const Text(
                  'Desvincular pareja',
                  style: TextStyle(color: Colors.redAccent),
                ),
                subtitle: Text(
                  'Elimina el progreso y recuerdos compartidos',
                  style: TextStyle(color: colors.text2),
                ),
                trailing: settings.isProcessing
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.chevron_right, color: colors.muted),
                onTap: settings.isProcessing
                    ? null
                    : () => _confirmUnlink(context, settings),
              ),
              _divider(colors),
            ],
            ListTile(
              leading: Icon(Icons.restart_alt_rounded, color: colors.primary),
              title: Text(
                'Reiniciar progreso individual',
                style: TextStyle(color: colors.text),
              ),
              subtitle: Text(
                'Borra tu mapa y recuerdos en solitario',
                style: TextStyle(color: colors.text2),
              ),
              trailing: settings.isProcessing
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.chevron_right, color: colors.muted),
              onTap: settings.isProcessing
                  ? null
                  : () => _confirmReset(context, settings),
            ),
          ]),
          const SizedBox(height: 28),
          _section('Sesión', colors),
          _card(colors, [
            ListTile(
              leading: Icon(Icons.logout_rounded, color: colors.text2),
              title: Text(
                'Cerrar sesión',
                style:
                    TextStyle(color: colors.text, fontWeight: FontWeight.w700),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.muted),
              onTap: () => _confirmLogout(context),
            ),
          ]),
          const SizedBox(height: 28),
          _section('Zona de peligro', colors, color: Colors.redAccent),
          _card(colors, [
            _tile(
              context,
              colors,
              Icons.delete_forever_outlined,
              'Eliminar cuenta',
              'Elimina permanentemente tu información',
              const DeleteAccountScreen(),
              color: Colors.redAccent,
            ),
          ]),
          const SizedBox(height: 34),
          Center(
            child: Text(
              'Daty v1.0.0',
              style: TextStyle(color: colors.muted, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileHeader(
    BuildContext context,
    ProfileProvider profile,
    AuthProvider auth,
    AppCustomTheme colors,
  ) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditProfileScreen()),
      ),
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colors.primary, colors.primary.withValues(alpha: .72)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Colors.white.withValues(alpha: .2),
              backgroundImage: profile.photoUrl == null
                  ? null
                  : CachedNetworkImageProvider(profile.photoUrl!),
              child: profile.photoUrl == null
                  ? Text(
                      profile.initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    auth.user?.email ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Editar perfil',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _appearanceTile(
    BuildContext context,
    ThemeProvider provider,
    AppCustomTheme colors,
  ) {
    final preview = provider.currentTheme.previewColors;
    final selection = provider.currentPalette == AppPaletteType.daty
        ? provider.modeLabel(provider.currentMode)
        : provider.paletteLabel(provider.currentPalette);
    return ListTile(
      leading: Icon(Icons.palette_outlined, color: colors.primary),
      title:
          Text('Tema de la aplicación', style: TextStyle(color: colors.text)),
      subtitle: Text(selection, style: TextStyle(color: colors.text2)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...preview.map(
            (color) => Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, color: colors.muted),
        ],
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AppearanceScreen()),
      ),
    );
  }

  Widget _tile(
    BuildContext context,
    AppCustomTheme colors,
    IconData icon,
    String title,
    String subtitle,
    Widget destination, {
    Color? color,
  }) {
    final accent = color ?? colors.primary;
    return ListTile(
      leading: Icon(icon, color: accent),
      title: Text(title, style: TextStyle(color: color ?? colors.text)),
      subtitle: Text(subtitle, style: TextStyle(color: colors.text2)),
      trailing: Icon(Icons.chevron_right, color: colors.muted),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      ),
    );
  }

  Widget _card(AppCustomTheme colors, List<Widget> children) {
    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _divider(AppCustomTheme colors) => Divider(
        height: 1,
        indent: 56,
        color: colors.muted.withValues(alpha: .15),
      );

  Widget _section(
    String title,
    AppCustomTheme colors, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          color: color ?? colors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Future<void> _confirmReset(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Reiniciar progreso?'),
        content: const Text(
          'Se borrarán tus aventuras y fotos individuales. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await settings.resetSoloProgress();
    if (!context.mounted) return;
    error == null
        ? CustomSnackBar.showSuccess(context, 'Progreso reiniciado')
        : CustomSnackBar.showError(context, error);
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'Romper vínculo',
          style: TextStyle(color: Colors.redAccent),
        ),
        content: const Text(
          'Se eliminarán el progreso y los recuerdos compartidos. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Desvincular'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await settings.unlinkPartner();
    if (!context.mounted) return;
    error == null
        ? CustomSnackBar.showSuccess(context, 'Vínculo eliminado')
        : CustomSnackBar.showError(context, error);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().signOut();
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}
