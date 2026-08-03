import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/providers/profile_provider.dart';
import '../providers/settings_provider.dart';
import '../../couple/widgets/reconciliation_contract_dialog.dart';
import 'appearance_screen.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'notifications_screen.dart';
import 'privacy_screen.dart';
import 'security_screen.dart';
import '../widgets/social_media_sheet.dart';

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
          if (!hasPartner && auth.user != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              stream: settings.getPausedCoupleStream(auth.user!.uid),
              builder: (context, snapshot) {
                final doc = snapshot.data;
                if (doc == null || !doc.exists) return const SizedBox.shrink();
                final data = doc.data()!;
                final recoveryEnd =
                    (data['recoveryWindowEnd'] as Timestamp?)?.toDate();
                final preservationEnd =
                    (data['preservationWindowEnd'] as Timestamp?)?.toDate();
                final now = DateTime.now();

                final canRecover =
                    recoveryEnd != null && now.isBefore(recoveryEnd);
                final canPreserve =
                    preservationEnd != null && now.isBefore(preservationEnd);

                if (!canRecover && !canPreserve) return const SizedBox.shrink();

                final remainingHrs =
                    canRecover ? recoveryEnd.difference(now).inHours : 0;
                final remainingMins = canRecover
                    ? (recoveryEnd.difference(now).inMinutes % 60)
                    : 0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _section('Vínculo y recuerdos', colors),
                    _RecoveryAccordion(
                      title: canRecover
                          ? 'Recuperación de Vínculo Activa'
                          : 'Ventana de Resguardo de Fotos',
                      canRecover: canRecover,
                      canPreserve: canPreserve,
                      remainingHrs: remainingHrs,
                      remainingMins: remainingMins,
                      doc: doc,
                      colors: colors,
                      auth: auth,
                      settings: settings,
                    ),
                  ],
                );
              },
            ),
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
          _section('Soporte y comunidad', colors),
          _card(colors, [
            _tile(
              context,
              colors,
              Icons.help_outline_rounded,
              'Centro de ayuda',
              'Preguntas frecuentes y soporte técnico',
              const HelpCenterScreen(),
            ),
            _divider(colors),
            ListTile(
              leading: Icon(Icons.share_outlined, color: colors.primary),
              title: Text('Redes sociales', style: TextStyle(color: colors.text)),
              subtitle: Text(
                'Síguenos e inspírate en nuestras comunidades',
                style: TextStyle(color: colors.text2),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.muted),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (_) => const SocialMediaSheet(),
                );
              },
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
    final t = Provider.of<ThemeProvider>(context, listen: false).currentTheme;

    final modeChoice = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: t.elevatedSurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: t.outline),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reiniciar Progreso Solitario',
                style: TextStyle(
                  color: t.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecciona el modo de reinicio que deseas:',
                style: TextStyle(color: t.muted, fontSize: 13),
              ),
              const SizedBox(height: 18),

              // Tarjeta Opción 1: Solo Mapa
              GestureDetector(
                onTap: () => Navigator.pop(ctx, 'map_only'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.softSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: t.primary.withValues(alpha: 0.5), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: t.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.map_rounded, color: t.primary, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Solo Mapa',
                                  style: TextStyle(
                                    color: t.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: t.primary.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'New Game+',
                                    style: TextStyle(
                                        color: t.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Conserva tu Álbum de recuerdos. Vuelve a jugar los 30 niveles con 50% XP.',
                              style: TextStyle(
                                  color: t.text2, fontSize: 12, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Tarjeta Opción 2: Reset Completo
              GestureDetector(
                onTap: () => Navigator.pop(ctx, 'factory'),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: t.softSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: t.outline),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_forever_rounded,
                            color: Colors.redAccent, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reset Completo',
                              style: TextStyle(
                                color: t.text,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Borra tu mapa, fotos solitarias del Álbum y restablece tu nivel a 0.',
                              style: TextStyle(
                                  color: t.text2, fontSize: 12, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx, null),
                  child: Text('Cancelar', style: TextStyle(color: t.muted)),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (modeChoice == null || !context.mounted) return;

    final textController = TextEditingController();
    bool canConfirm = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: t.elevatedSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modeChoice == 'map_only'
                      ? 'Confirmar Reinicio del Mapa'
                      : 'Confirmar Reset Completo',
                  style: TextStyle(
                    color: t.text,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  modeChoice == 'map_only'
                      ? 'Tu Álbum se conservará intacto. Escribe REINICIAR:'
                      : 'Esta acción borrará tu Álbum y XP. Escribe REINICIAR:',
                  style: TextStyle(color: t.text2, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: TextStyle(color: t.text, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'REINICIAR',
                    hintStyle: TextStyle(color: t.muted),
                    filled: true,
                    fillColor: t.softSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: t.outline),
                    ),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      canConfirm = val.trim() == 'REINICIAR';
                    });
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancelar', style: TextStyle(color: t.muted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canConfirm
                            ? t.primary
                            : t.muted.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed:
                          canConfirm ? () => Navigator.pop(ctx, true) : null,
                      child: const Text('Confirmar',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final error = modeChoice == 'map_only'
        ? await settings.resetSoloMapOnly()
        : await settings.resetSoloFactory();

    if (!context.mounted) return;
    error == null
        ? CustomSnackBar.showSuccess(context, 'Progreso solitario reiniciado')
        : CustomSnackBar.showError(context, error);
  }

  Future<void> _confirmUnlink(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final t = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    final textController = TextEditingController();
    bool canConfirm = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: t.elevatedSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: t.outline),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Desvincular Pareja',
                  style: TextStyle(
                    color: t.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: t.softSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t.outline),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              size: 16, color: t.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '72h para recuperar el vínculo',
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.folder_special_outlined,
                              size: 16, color: t.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '7 días para guardar fotos en Personal',
                              style: TextStyle(
                                  color: t.text,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Escribe DESVINCULAR para confirmar:',
                  style: TextStyle(color: t.text2, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: textController,
                  autofocus: true,
                  style: TextStyle(color: t.text, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: 'DESVINCULAR',
                    hintStyle: TextStyle(color: t.muted),
                    filled: true,
                    fillColor: t.softSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: t.outline),
                    ),
                  ),
                  onChanged: (val) {
                    setDialogState(() {
                      canConfirm = val.trim() == 'DESVINCULAR';
                    });
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancelar', style: TextStyle(color: t.muted)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canConfirm
                            ? t.primary
                            : t.muted.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed:
                          canConfirm ? () => Navigator.pop(ctx, true) : null,
                      child: const Text('Desvincular',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final error = await settings.unlinkPartnerWithGracePeriod();
    if (!context.mounted) return;
    error == null
        ? CustomSnackBar.showSuccess(
            context, 'Proceso de desvinculación iniciado')
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

class _RecoveryAccordion extends StatefulWidget {
  final String title;
  final bool canRecover;
  final bool canPreserve;
  final int remainingHrs;
  final int remainingMins;
  final DocumentSnapshot<Map<String, dynamic>> doc;
  final AppCustomTheme colors;
  final AuthProvider auth;
  final SettingsProvider settings;

  const _RecoveryAccordion({
    required this.title,
    required this.canRecover,
    required this.canPreserve,
    required this.remainingHrs,
    required this.remainingMins,
    required this.doc,
    required this.colors,
    required this.auth,
    required this.settings,
  });

  @override
  State<_RecoveryAccordion> createState() => _RecoveryAccordionState();
}

class _RecoveryAccordionState extends State<_RecoveryAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final data = widget.doc.data() ?? {};
    final myUid = widget.auth.user?.uid;
    final reconStatus = data['reconciliationStatus'];
    final reconBy = data['reconciliationRequestedBy'];

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colors.softSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (expanded) =>
              setState(() => _isExpanded = expanded),
          tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          leading: Icon(
            Icons.history_toggle_off_rounded,
            color: colors.primary,
            size: 22,
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: widget.canRecover
              ? Text(
                  'Quedan ${widget.remainingHrs}h ${widget.remainingMins}m para arrepentirte',
                  style: TextStyle(color: colors.text2, fontSize: 12),
                )
              : null,
          trailing: Icon(
            _isExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: colors.primary,
          ),
          children: [
            if (widget.canRecover) ...[
              Text(
                'Puedes retomar la relación con tu pareja anterior dentro del periodo de gracia de 72 horas.',
                style: TextStyle(
                  color: colors.text2,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Builder(
                builder: (context) {
                  if (reconStatus == 'pending' && reconBy == myUid) {
                    return Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                color: colors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Propuesta enviada. Esperando a que tu pareja la revise y firme...',
                                  style: TextStyle(
                                    color: colors.text,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                            ),
                            icon: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: colors.text2,
                            ),
                            label: Text(
                              'Cancelar propuesta',
                              style: TextStyle(
                                color: colors.text2,
                                fontSize: 12,
                              ),
                            ),
                            onPressed: widget.settings.isProcessing
                                ? null
                                : () => widget.settings.cancelReconciliation(
                                      widget.doc.id,
                                    ),
                          ),
                        ),
                      ],
                    );
                  } else if (reconStatus == 'pending' && reconBy != myUid) {
                    return SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE91E63),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(
                          Icons.volunteer_activism_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          'Ver y Firmar Contrato de Reconstrucción',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => ReconciliationContractDialog(
                              coupleDocId: widget.doc.id,
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(
                        Icons.restore_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Proponer Reconciliación',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      onPressed: widget.settings.isProcessing
                          ? null
                          : () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) => ReconciliationContractDialog(
                                  coupleDocId: widget.doc.id,
                                  isProposing: true,
                                ),
                              );
                            },
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),
            ],
            if (widget.canPreserve)
              Row(
                children: [
                  Icon(
                    Icons.shield_moon_outlined,
                    color: colors.muted,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Recuerda mover tus fotos de pareja a Personal en el Álbum antes de que venza la ventana.',
                      style: TextStyle(color: colors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
