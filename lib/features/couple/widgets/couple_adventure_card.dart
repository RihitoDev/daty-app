import 'package:flutter/material.dart';
import 'package:magic_dates/features/couple/screens/adventure_in_progress_screen.dart';
import 'package:magic_dates/features/couple/screens/adventure_memory_screen.dart';
import 'package:provider/provider.dart';
import '../providers/couple_provider.dart';
import 'pairing_dialog.dart';
import 'contract_dialog.dart';
import '../../../shared/screens/adventure_map.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/adventure_action_card.dart';

class CoupleAdventureCard extends StatelessWidget {
  const CoupleAdventureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final coupleProvider = context.watch<CoupleProvider>();

    // Si aún no se vincula con nadie, mostramos el botón para abrir el buscador de usuarios
    if (!coupleProvider.hasPartner) {
      return _buildPremiumCard(
        title: 'Aventura en pareja',
        subtitle: 'Vinculate con alguien',
        gradientColors: const [Color(0xFFF48FB1), Color(0xFFD81B60)],
        icon: Icons.favorite_border_rounded,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const PairingDialog(),
        ),
      );
    }

    // Mientras esperamos respuesta de la base de datos, bloqueamos los toques
    if (coupleProvider.isLoading) {
      return _buildPremiumCard(
          title: 'Cargando...',
          subtitle: '',
          gradientColors: [Colors.grey, Colors.grey.shade700],
          icon: Icons.hourglass_empty,
          onTap: null);
    }

    // Si hubo un fallo raro o se quedaron a medias en la vinculación
    if (coupleProvider.coupleData == null) {
      if (!coupleProvider.isLoading) {
        return _buildPremiumCard(
            title: 'Error de Datos',
            subtitle: 'Ve a Ajustes y desvinculate para reiniciar',
            gradientColors: const [Colors.redAccent, Colors.red],
            icon: Icons.error_outline,
            onTap: null);
      }

      return _buildPremiumCard(
          title: 'Sincronizando...',
          subtitle: 'Conectando con tu pareja',
          gradientColors: const [Colors.orange, Colors.deepOrange],
          icon: Icons.sync,
          onTap: null);
    }

    // El usuario actual todavía no acepta las reglas de la app
    if (!coupleProvider.iSigned) {
      return _buildPremiumCard(
        title: 'Aventura en pareja',
        subtitle:
            'Vinculado con ${coupleProvider.partnerName} · Firma el contrato',
        gradientColors: const [Color(0xFFFFB74D), Color(0xFFF57C00)],
        icon: Icons.history_edu,
        onTap: () => _showContractDialog(context, coupleProvider),
      );
    }

    // Nosotros ya aceptamos, pero toca esperar a que el otro abra la app y firme
    if (coupleProvider.iSigned && !coupleProvider.partnerSigned) {
      return _buildPremiumCard(
        title: 'Aventura en pareja',
        subtitle:
            'Vinculado con ${coupleProvider.partnerName} · Esperando su firma',
        gradientColors: const [Color(0xFF90A4AE), Color(0xFF546E7A)],
        icon: Icons.hourglass_top,
        onTap: () {
          CustomSnackBar.showInfo(context,
              'Esperando que ${coupleProvider.partnerName} firme el contrato...');
        },
      );
    }

    // Todo listo: Ambos están vinculados y firmaron. Abrimos el mapa principal
    return _buildPremiumCard(
        title: 'Aventura en pareja',
        subtitle: 'Vinculado con ${coupleProvider.partnerName}',
        gradientColors: const [Color(0xFFF06292), Color(0xFFC2185B)],
        icon: Icons.favorite,
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AdventureMap(
                      mode: 'couple',
                      themeColor: const Color(0xFFC2185B),
                      pathColor: const Color(0xFFF48FB1),
                      totalNodes: 50,
                      headerTitle: 'Nuestro Viaje',
                      onNavigateToProgress: (adventureData, availableIds) =>
                          AdventureInProgressScreen(
                        adventureData: adventureData,
                        availableAdventuresIds: availableIds,
                        onSoloFinish: null,
                      ),
                      onNavigateToMemory: (adventureId, adventureData) =>
                          AdventureMemoryScreen(
                        coupleDocId: coupleProvider.coupleDocId!,
                        adventureId: adventureId,
                        adventureData: adventureData,
                      ),
                    ))));
  }

  void _showContractDialog(
      BuildContext context, CoupleProvider coupleProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContractDialog(
          myUid: coupleProvider.myUid,
          partnerUid: coupleProvider.partnerId!,
          coupleDocId: coupleProvider.coupleDocId!),
    );
  }

  // Plantilla base para dibujar las tarjetas sin repetir la configuración visual 5 veces
  Widget _buildPremiumCard({
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final customTheme = themeProvider.currentTheme;
        final accent = gradientColors.last;
        return AdventureActionCard(
          theme: customTheme,
          title: title,
          subtitle: subtitle,
          icon: icon,
          accent: accent,
          onTap: onTap,
        );
      },
    );
  }
}
