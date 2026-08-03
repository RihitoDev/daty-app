import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/theme_provider.dart';

class SocialMediaSheet extends StatelessWidget {
  const SocialMediaSheet({super.key});

  static const String instagramUrl =
      'https://www.instagram.com/datyapp?igsh=MTQ5czh4dXV6Y3J0dQ==';
  static const String tiktokUrl =
      'https://www.tiktok.com/@datyggs?_r=1&_t=ZS-98Zr3xJ5dpf';
  static const String whatsappCommunityUrl =
      'https://chat.whatsapp.com/LK7919xN8m6Kf5DjuNBRr8';
  static const String whatsappSupportUrl =
      'https://wa.me/59168476178?text=Hola%20equipo%20de%20Daty,%20necesito%20soporte%20personalizado.';

  Future<void> _openUrl(BuildContext context, String urlString) async {
    try {
      final Uri uri = Uri.parse(urlString);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        await launchUrl(uri);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo abrir el enlace.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.muted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Comunidad y Soporte Daty',
            style: TextStyle(
              color: colors.text,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '¡Únete a nuestras redes sociales o contáctanos directamente!',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.text2, fontSize: 13),
          ),
          const SizedBox(height: 24),
          _socialTile(
            colors,
            icon: Icons.support_agent_rounded,
            title: 'Soporte Personal',
            subtitle: 'Atención y ayuda personalizada por WhatsApp',
            onTap: () => _openUrl(context, whatsappSupportUrl),
          ),
          const SizedBox(height: 12),
          _socialTile(
            colors,
            icon: Icons.groups_rounded,
            title: 'Comunidad de WhatsApp',
            subtitle: 'Ideas de citas e inspiración diaria',
            onTap: () => _openUrl(context, whatsappCommunityUrl),
          ),
          const SizedBox(height: 12),
          _socialTile(
            colors,
            icon: Icons.camera_alt_rounded,
            title: 'Instagram',
            subtitle: '@datyapp • Fotos, parejas y novedades',
            onTap: () => _openUrl(context, instagramUrl),
          ),
          const SizedBox(height: 12),
          _socialTile(
            colors,
            icon: Icons.music_note_rounded,
            title: 'TikTok',
            subtitle: '@datyggs • Videos e ideas de salidas',
            onTap: () => _openUrl(context, tiktokUrl),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _socialTile(
    dynamic colors, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.bg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: colors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: colors.text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: colors.text2, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: colors.muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
