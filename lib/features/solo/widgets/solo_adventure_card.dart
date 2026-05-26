import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../screens/solo_map.dart';
import 'solo_contract_dialog.dart';

class SoloAdventureCard extends StatelessWidget {
  const SoloAdventureCard({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final myUid = authProvider.user!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('solo_progress').doc(myUid).snapshots(),
      builder: (context, snapshot) {
        // Si está cargando, mostramos la tarjeta en gris
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildCard(
            title: 'Aventura en solitario', 
            subtitle: 'Cargando...', 
            gradientColors: [Colors.grey, Colors.grey.shade700],
            icon: Icons.hourglass_empty, 
            onTap: null
          );
        }

        bool contractAccepted = false;
        
        if (snapshot.hasData && snapshot.data!.exists) {
          contractAccepted = snapshot.data!['contractAccepted'] ?? false;
        }

        if (!contractAccepted) {
          return _buildCard(
            title: 'Aventura en solitario', 
            subtitle: 'Firma tu compromiso', 
            gradientColors: const [Color(0xFF64B5F6), Color(0xFF1976D2)],
            icon: Icons.backpack_outlined, 
            onTap: () => showDialog(context: context, builder: (_) => const SoloContractDialog())
          );
        }

        // Si ya firmó, va directo al mapa
        return _buildCard(
          title: 'Aventura en solitario', 
          subtitle: 'Mi camino personal', 
          gradientColors: const [Color(0xFF64B5F6), Color(0xFF1976D2)],
          icon: Icons.backpack_rounded, 
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SoloMap()))
        );
      },
    );
  }

  Widget _buildCard({required String title, required String subtitle, required List<Color> gradientColors, required IconData icon, required VoidCallback? onTap}) {
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