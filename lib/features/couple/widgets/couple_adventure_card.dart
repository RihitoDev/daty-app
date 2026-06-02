import 'package:flutter/material.dart';
import 'package:magic_dates/features/couple/screens/adventure_in_progress_screen.dart';
import 'package:magic_dates/features/couple/screens/adventure_memory_screen.dart';
import 'package:provider/provider.dart';
import '../providers/couple_provider.dart';
import 'pairing_dialog.dart';
import 'contract_dialog.dart';
import '../../shared/screens/adventure_map.dart';
import '../../shared/widgets/custom_snackbar.dart';

class CoupleAdventureCard extends StatelessWidget {
  const CoupleAdventureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final coupleProvider = context.watch<CoupleProvider>();

    if (!coupleProvider.hasPartner) {
      return _buildPremiumCard(
        title: 'Aventura en pareja',
        subtitle: 'Vinculate con alguien',
        gradientColors: const [Color(0xFFF48FB1), Color(0xFFD81B60)],
        icon: Icons.favorite_border_rounded,
        onTap: () => showDialog(context: context, builder: (context) => PairingDialog(myUid: coupleProvider.myUid)),
      );
    }

    if (coupleProvider.isLoading) {
      return _buildPremiumCard(
        title: 'Cargando...',
        subtitle: '',
        gradientColors: [Colors.grey, Colors.grey.shade700],
        icon: Icons.hourglass_empty,
        onTap: null
      );
    }

    if (coupleProvider.coupleData == null) {
      if (!coupleProvider.isLoading) {
        return _buildPremiumCard(
          title: 'Error de Datos',
          subtitle: 'Ve a Ajustes y desvinculate para reiniciar',
          gradientColors: const [Colors.redAccent, Colors.red],
          icon: Icons.error_outline,
          onTap: null
        );
      }
      
      return _buildPremiumCard(
        title: 'Sincronizando...',
        subtitle: 'Conectando con tu pareja',
        gradientColors: const [Colors.orange, Colors.deepOrange],
        icon: Icons.sync,
        onTap: null
      );
    }

    if (!coupleProvider.iSigned) {
      return _buildPremiumCard(
        title: 'Aventura en pareja',
        subtitle: 'Firma el contrato con ${coupleProvider.partnerName}',
        gradientColors: const [Color(0xFFFFB74D), Color(0xFFF57C00)],
        icon: Icons.history_edu,
        onTap: () => _showContractDialog(context, coupleProvider),
      );
    }

    if (coupleProvider.iSigned && !coupleProvider.partnerSigned) {
      return _buildPremiumCard(
        title: 'Aventura en pareja',
        subtitle: 'Esperando firma de ${coupleProvider.partnerName}',
        gradientColors: const [Color(0xFF90A4AE), Color(0xFF546E7A)],
        icon: Icons.hourglass_top,
        onTap: () {
          CustomSnackBar.showInfo(context, 'Esperando que ${coupleProvider.partnerName} firme el contrato...');
        },
      );
    }

    return _buildPremiumCard(
      title: 'Aventura en pareja',
      subtitle: 'Nuestra aventura junto a ${coupleProvider.partnerName}',
      gradientColors: const [Color(0xFFF06292), Color(0xFFC2185B)],
      icon: Icons.favorite,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdventureMap(
        mode: 'couple',
        themeColor: const Color(0xFFC2185B),
        pathColor: const Color(0xFFF48FB1),
        totalNodes: 50,
        headerTitle: 'Nuestro Viaje',
        onNavigateToProgress: (adventureData, availableIds) => AdventureInProgressScreen(
          adventureData: adventureData,
          availableAdventuresIds: availableIds,
          onSoloFinish: null,
        ),
        onNavigateToMemory: (adventureId, adventureData) => AdventureMemoryScreen(
          coupleDocId: coupleProvider.coupleDocId!,
          adventureId: adventureId,
          adventureData: adventureData,
        ),
      )))
    );
  }

  void _showContractDialog(BuildContext context, CoupleProvider coupleProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContractDialog(
        myUid: coupleProvider.myUid,
        partnerUid: coupleProvider.partnerId!,
        coupleDocId: coupleProvider.coupleDocId!
      ),
    );
  }

  Widget _buildPremiumCard({
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: gradientColors.last.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8), spreadRadius: 2)],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: Colors.white)
            ),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))])),
                  const SizedBox(height: 6),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 15, fontWeight: FontWeight.w600))
                ]
              )
            ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 28)
          ],
        ),
      ),
    );
  }
}