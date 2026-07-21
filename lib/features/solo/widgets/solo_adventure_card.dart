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

class SoloAdventureCard extends StatelessWidget {
  const SoloAdventureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final myUid = authProvider.user!.uid;

    // Revisamos en tiempo real si el usuario ya aceptó el contrato de la aventura
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('solo_progress').doc(myUid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCard(title: 'Aventura en solitario', subtitle: 'Cargando...', gradientColors: [Colors.grey, Colors.grey.shade700], icon: Icons.hourglass_empty, onTap: null);
        }

        bool contractAccepted = false;
        if (snapshot.hasData && snapshot.data!.exists) {
          contractAccepted = snapshot.data!['contractAccepted'] ?? false;
        }

        // Si no ha firmado el compromiso, al tocar le abrimos el diálogo
        if (!contractAccepted) {
          return _buildCard(
            title: 'Aventura en solitario', 
            subtitle: 'Firma tu compromiso', 
            gradientColors: const [Color(0xFF64B5F6), Color(0xFF1976D2)],
            icon: Icons.backpack_outlined, 
            onTap: () => showDialog(context: context, builder: (_) => const SoloContractDialog())
          );
        }

        // Si ya firmó, lo mandamos al mapa de aventuras configurando qué hacer en cada paso
        return _buildCard(
          title: 'Aventura en solitario', 
          subtitle: 'Mi camino personal', 
          gradientColors: const [Color(0xFF64B5F6), Color(0xFF1976D2)],
          icon: Icons.backpack_rounded, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdventureMap(
            mode: 'solo',
            themeColor: const Color(0xFF1976D2),
            pathColor: const Color(0xFF64B5F6),
            totalNodes: 30,
            headerTitle: 'Mi Camino',
            onNavigateToProgress: (adventureData, availableIds) => AdventureInProgressScreen(
              adventureData: adventureData, 
              availableAdventuresIds: availableIds, 
              onSoloFinish: (ctx) { 
                // Al terminar, lo mandamos a calificar reemplazando la pantalla, así no puede devolverse a la aventura con el botón de atrás
                Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => SoloAdventureReviewScreen(adventureData: adventureData, availableAdventuresIds: availableIds)));
              },
            ),
            onNavigateToMemory: (adventureId, adventureData) => SoloAdventureMemoryScreen(
              myUid: myUid, 
              adventureId: adventureId, 
              adventureData: adventureData
            ),
          )))
        );
      },
    );
  }

  Widget _buildCard({required String title, required String subtitle, required List<Color> gradientColors, required IconData icon, required VoidCallback? onTap}) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final customTheme = themeProvider.currentTheme;
        final enabled = onTap != null;
        final accent = gradientColors.last;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                colors: [accent.withValues(alpha: 0.27), accent.withValues(alpha: 0.13), customTheme.card],
                stops: const [0, 0.7, 1],
              ),
              border: Border.all(color: accent.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.1), blurRadius: 18, offset: const Offset(0, 7))],
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: accent.withValues(alpha: enabled ? 0.16 : 0.08), borderRadius: BorderRadius.circular(18)),
                child: Icon(icon, size: 30, color: enabled ? accent : customTheme.muted),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(color: customTheme.text, fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle, style: TextStyle(color: customTheme.text2, fontSize: 13, fontWeight: FontWeight.w600)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: enabled ? accent : customTheme.muted, size: 18),
            ]),
          ),
        );
      },
    );
  }
}
