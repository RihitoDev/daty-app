import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shared/screens/adventure_map.dart';
import '../../couple/screens/adventure_in_progress_screen.dart'; // Import necesario
import '../screens/solo_adventure_review_screen.dart'; // Import necesario
import '../screens/solo_adventure_memory_screen.dart'; // Import necesario

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
      await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).set({
        'contractAccepted': true,
        'adventurePath': [],
        'activeAdventureNumber': null,
      }, SetOptions(merge: true));
      
      if (mounted) {
        Navigator.pop(context); 
        
        // Navegamos al mapa inyectando las rutas de Solo
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
      debugPrint('Error al firmar contrato solitario: $e');
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al firmar el compromiso'), backgroundColor: Colors.redAccent));
      }
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  title: const Text('🧘 Me comprometo a disfrutar mi propia compañía y vivir nuevas experiencias sin excusas.', style: TextStyle(fontSize: 13)),
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
                    label: const Text('¡A volar solo!', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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