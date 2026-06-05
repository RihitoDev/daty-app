import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/screens/adventure_map.dart';
import '../../couple/screens/adventure_in_progress_screen.dart'; 
import '../screens/solo_adventure_review_screen.dart'; 
import '../screens/solo_adventure_memory_screen.dart'; 
import '../../shared/widgets/custom_snackbar.dart';

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
    // Bloqueamos el botón de atrás para obligar al usuario a aceptar las reglas o quedarse aquí
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.backpack, color: Color(0xFF1976D2), size: 50),
                const SizedBox(height: 15),
                const Text('Compromiso Personal', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1976D2))),
                const SizedBox(height: 20),
                
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _ruleChecked,
                  onChanged: (val) => setState(() => _ruleChecked = val ?? false),
                  title: const Row(
                    children: [
                      SizedBox(width: 6),
                      Expanded(child: Text('Me comprometo a disfrutar y vivir nuevas experiencias solo y sin excusas.', style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ),

                const Divider(height: 30),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ruleChecked ? const Color(0xFF1976D2) : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: _ruleChecked && !_isProcessing ? _signContract : null,
                    icon: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Iniciar mi Aventura', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}