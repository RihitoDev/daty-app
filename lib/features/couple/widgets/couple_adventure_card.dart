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

    // Si aún no se vincula con nadie, mostramos siempre la tarjeta estándar para invitar o ingresar código
    if (!coupleProvider.hasPartner) {
      return _buildPremiumCard(
        title: 'Aventura en pareja',
        subtitle: 'Vinculate con alguien',
        gradientColors: const [Color(0xFFF48FB1), Color(0xFFD81B60)],
        icon: Icons.favorite_border_rounded,
        onTap: () async {
          final result = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            constraints: const BoxConstraints(maxWidth: 680),
            builder: (_) => const PairingDialog(),
          );
          if (result == true && context.mounted) {
            final latestCouple = context.read<CoupleProvider>();
            _showContractDialog(context, latestCouple);
          }
        },
      );
    }

    // Mientras se sincronizan los datos de la pareja en la base de datos
    if (coupleProvider.isLoading || coupleProvider.coupleData == null) {
      return _buildPremiumCard(
        title: 'Sincronizando...',
        subtitle: 'Conectando con ${coupleProvider.partnerName}',
        gradientColors: const [Color(0xFFFFB74D), Color(0xFFF57C00)],
        icon: Icons.sync_rounded,
        onTap: null,
      );
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

  Future<void> _showContractDialog(
      BuildContext context, CoupleProvider coupleProvider) async {
    for (var attempt = 0; attempt < 20; attempt += 1) {
      if (!context.mounted) return;
      final provider = context.read<CoupleProvider>();
      if (provider.hasPartner &&
          !provider.isLoading &&
          provider.partnerId != null &&
          provider.coupleDocId != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ContractDialog(
            myUid: provider.myUid,
            partnerUid: provider.partnerId!,
            coupleDocId: provider.coupleDocId!,
          ),
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
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
