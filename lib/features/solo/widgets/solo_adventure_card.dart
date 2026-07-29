import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/screens/adventure_map.dart';
import '../../couple/screens/adventure_in_progress_screen.dart';
import '../screens/solo_adventure_review_screen.dart';
import '../screens/solo_adventure_memory_screen.dart';
import 'solo_contract_dialog.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/adventure_action_card.dart';

class SoloAdventureCard extends StatelessWidget {
  const SoloAdventureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    if (user == null) {
      return _buildCard(
        title: 'Aventura en solitario',
        subtitle: 'Cargando...',
        gradientColors: [Colors.grey, Colors.grey.shade700],
        icon: Icons.hourglass_empty,
        onTap: null,
      );
    }

    final myUid = user.uid;

    // Revisamos en tiempo real si el usuario ya aceptó el contrato de la aventura
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('solo_progress')
          .doc(myUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildCard(
            title: 'Aventura en solitario',
            subtitle: 'Error al conectar',
            gradientColors: const [Colors.redAccent, Colors.red],
            icon: Icons.error_outline,
            onTap: null,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCard(
            title: 'Aventura en solitario',
            subtitle: 'Cargando...',
            gradientColors: [Colors.grey, Colors.grey.shade700],
            icon: Icons.hourglass_empty,
            onTap: null,
          );
        }

        bool contractAccepted = false;
        if (snapshot.hasData &&
            snapshot.data != null &&
            snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          contractAccepted = data?['contractAccepted'] ?? false;
        }

        // Si no ha firmado el compromiso, al tocar le abrimos el diálogo
        if (!contractAccepted) {
          return _buildCard(
              title: 'Aventura en solitario',
              subtitle: 'Firma tu compromiso',
              gradientColors: const [Color(0xFF64B5F6), Color(0xFF1976D2)],
              icon: Icons.backpack_outlined,
              onTap: () => showDialog(
                  context: context,
                  builder: (_) => const SoloContractDialog()));
        }

        // Si ya firmó, lo mandamos al mapa de aventuras configurando qué hacer en cada paso
        return _buildCard(
            title: 'Aventura en solitario',
            subtitle: 'Mi camino personal',
            gradientColors: const [Color(0xFF64B5F6), Color(0xFF1976D2)],
            icon: Icons.backpack_rounded,
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => AdventureMap(
                          mode: 'solo',
                          themeColor: const Color(0xFF1976D2),
                          pathColor: const Color(0xFF64B5F6),
                          totalNodes: 30,
                          headerTitle: 'Mi Camino',
                          onNavigateToProgress: (adventureData, availableIds) =>
                              AdventureInProgressScreen(
                            adventureData: adventureData,
                            availableAdventuresIds: availableIds,
                            onSoloFinish: (ctx) {
                              // Al terminar, lo mandamos a calificar reemplazando la pantalla, así no puede devolverse a la aventura con el botón de atrás
                              Navigator.pushReplacement(
                                  ctx,
                                  MaterialPageRoute(
                                      builder: (_) => SoloAdventureReviewScreen(
                                          adventureData: adventureData,
                                          availableAdventuresIds:
                                              availableIds)));
                            },
                          ),
                          onNavigateToMemory: (adventureId, adventureData) =>
                              SoloAdventureMemoryScreen(
                                  myUid: myUid,
                                  adventureId: adventureId,
                                  adventureData: adventureData),
                        ))));
      },
    );
  }

  Widget _buildCard(
      {required String title,
      required String subtitle,
      required List<Color> gradientColors,
      required IconData icon,
      required VoidCallback? onTap}) {
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
