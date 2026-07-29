import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/daty_contract_header.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/contract_rule_tile.dart';

class ContractDialog extends StatefulWidget {
  final String myUid;
  final String partnerUid;
  final String coupleDocId;

  const ContractDialog({
    super.key, 
    required this.myUid, 
    required this.partnerUid, 
    required this.coupleDocId,
  });

  @override
  State<ContractDialog> createState() => _ContractDialogState();
}

class _ContractDialogState extends State<ContractDialog> {
  bool _rule1Checked = false;
  bool _rule2Checked = false;
  bool _rule3Checked = false;
  bool _isProcessing = false;

  bool get _allChecked => _rule1Checked && _rule2Checked && _rule3Checked;

  Future<void> _signContract() async {
    setState(() => _isProcessing = true);
    
    // Mantenemos la regla del orden alfabético para saber exactamente qué campo del contrato nos toca actualizar
    String fieldToUpdate = widget.myUid.compareTo(widget.partnerUid) < 0 
        ? 'contractSignedUser1' 
        : 'contractSignedUser2';

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final coupleRef = FirebaseFirestore.instance.collection('couples_progress').doc(widget.coupleDocId);
        transaction.update(coupleRef, {fieldToUpdate: true});
      });
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al firmar el contrato');
      }
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _rejectAndUnlink() async {
    setState(() => _isProcessing = true);
    try {
      // Usamos WriteBatch porque si falla la desvinculación a la mitad, dejaría la base de datos inconsistente. Es todo o nada.
      WriteBatch batch = FirebaseFirestore.instance.batch();
      
      batch.update(FirebaseFirestore.instance.collection('users').doc(widget.myUid), {'partnerId': null});
      batch.update(FirebaseFirestore.instance.collection('users').doc(widget.partnerUid), {'partnerId': null});
      batch.delete(FirebaseFirestore.instance.collection('couples_progress').doc(widget.coupleDocId));
      
      await batch.commit();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al cancelar el vínculo');
      }
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    // PopScope bloquea el botón físico de "Atrás" en Android para forzar que el usuario tome una decisión explícita en el diálogo
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
                  title: 'Nuestro pacto',
                  icon: Icons.favorite_rounded,
                  accent: const Color(0xFFC2185B),
                  customTheme: customTheme,
                  isComplete: _allChecked,
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ContractRuleTile(
                        value: _rule1Checked,
                        text: 'Guardar el celular y estar presentes.',
                        accent: const Color(0xFFC2185B),
                        textColor: customTheme.text,
                        onChanged: (value) => setState(() => _rule1Checked = value),
                      ),
                      ContractRuleTile(
                        value: _rule2Checked,
                        text: 'Probar algo nuevo con la mente abierta.',
                        accent: const Color(0xFFC2185B),
                        textColor: customTheme.text,
                        onChanged: (value) => setState(() => _rule2Checked = value),
                      ),
                      ContractRuleTile(
                        value: _rule3Checked,
                        text: 'Disfrutar juntos sin buscar que todo sea perfecto.',
                        accent: const Color(0xFFC2185B),
                        textColor: customTheme.text,
                        onChanged: (value) => setState(() => _rule3Checked = value),
                      ),
                    ],
                  ),
                  onClose: () => Navigator.pop(context),
                  actions: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _allChecked ? const Color(0xFFC2185B) : Colors.grey.shade300,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: _allChecked && !_isProcessing ? _signContract : null,
                          icon: _isProcessing
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_circle_outline, color: Colors.white),
                          label: const Text('Firmo y acepto', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      TextButton(
                        onPressed: _isProcessing ? null : _rejectAndUnlink,
                        child: const Text('No estoy de acuerdo', style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
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
