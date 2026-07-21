import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/screens/adventure_map.dart';
import '../../couple/screens/adventure_in_progress_screen.dart'; 
import '../screens/solo_adventure_review_screen.dart'; 
import '../screens/solo_adventure_memory_screen.dart'; 
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/daty_contract_header.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/contract_rule_tile.dart';

class SoloContractDialog extends StatefulWidget {
  const SoloContractDialog({super.key});

  @override
  State<SoloContractDialog> createState() => _SoloContractDialogState();
}

class _SoloContractDialogState extends State<SoloContractDialog> {
  bool _ruleChecked = false;
  bool _isProcessing = false;

  Future<void> _signContract() async {
    setState(() => _isProcessing = true);
    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;

    try {
      // Guardamos que aceptó el contrato e inicializamos su camino vacío.
      // Usamos merge: true por si el documento ya existía parcialmente, así no borramos lo que tenía antes.
      await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).set({
        'contractAccepted': true,
        'adventurePath': [],
        'activeAdventureNumber': null,
      }, SetOptions(merge: true));
      
      if (mounted) {
        Navigator.pop(context); // Cerramos el diálogo
        
        // Lo mandamos directo al mapa para que vea su primera aventura
        Navigator.push(context, MaterialPageRoute(builder: (_) => AdventureMap(
          mode: 'solo',
          themeColor: const Color(0xFF1976D2),
          pathColor: const Color(0xFF64B5F6),
          totalNodes: 30,
          headerTitle: 'Mi Camino',
          onNavigateToProgress: (adventureData, availableIds) => AdventureInProgressScreen(
            adventureData: adventureData, 
            availableAdventuresIds: availableIds, 
            onSoloFinish: (ctx) {
              Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (_) => SoloAdventureReviewScreen(adventureData: adventureData, availableAdventuresIds: availableIds)));
            },
          ),
          onNavigateToMemory: (adventureId, adventureData) => SoloAdventureMemoryScreen(
            myUid: myUid, 
            adventureId: adventureId, 
            adventureData: adventureData
          ),
        )));
      }
    } catch (e) {
      if(mounted) {
        CustomSnackBar.showError(context, 'Error al firmar el compromiso');
      }
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    // Bloqueamos el botón de atrás para obligar al usuario a aceptar las reglas o quedarse aquí
    return PopScope(
      canPop: true,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DatyContractHeader(
                  title: 'Compromiso personal',
                  icon: Icons.backpack_rounded,
                  accent: const Color(0xFF1976D2),
                  customTheme: customTheme,
                  isComplete: _ruleChecked,
                  content: ContractRuleTile(
                    value: _ruleChecked,
                    accent: const Color(0xFF1976D2),
                    textColor: customTheme.text,
                    text: 'Me comprometo a disfrutar y vivir nuevas experiencias solo y sin excusas.',
                    onChanged: (value) => setState(() => _ruleChecked = value),
                  ),
                  onClose: () => Navigator.pop(context),
                  actions: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ruleChecked ? const Color(0xFF1976D2) : Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _ruleChecked && !_isProcessing ? _signContract : null,
                      icon: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: const Text('Iniciar mi aventura', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}
