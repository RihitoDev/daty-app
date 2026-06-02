import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../shared/widgets/custom_snackbar.dart';

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
                const Icon(Icons.handshake_outlined, color: Color(0xFF66BB6A), size: 50),
                const SizedBox(height: 15),
                const Text('Pacto de Pareja', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                const SizedBox(height: 20),
                
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _rule1Checked,
                  onChanged: (val) => setState(() => _rule1Checked = val ?? false),
                  title: Row(
                    children: [
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Nos comprometemos a no usar el celular durante las citas, salvo emergencias o fotos.', style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _rule2Checked,
                  onChanged: (val) => setState(() => _rule2Checked = val ?? false),
                  title: Row(
                    children: [
                      const SizedBox(width: 6),
                      const Expanded(child: Text('Mantenemos la mente abierta para probar nuevas actividades sin juzgar antes.', style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ),
                CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _rule3Checked,
                  onChanged: (val) => setState(() => _rule3Checked = val ?? false),
                  title: Row(
                    children: [
                      const SizedBox(width: 6),
                      const Expanded(child: Text('El objetivo principal es la complicidad y el disfrute juntos, no que todo salga perfecto.', style: TextStyle(fontSize: 13))),
                    ],
                  ),
                ),

                const Divider(height: 30),

                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _allChecked ? const Color(0xFF66BB6A) : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: _allChecked && !_isProcessing ? _signContract : null,
                    icon: _isProcessing 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Firmo y Acepto', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                TextButton(
                  onPressed: _isProcessing ? null : _rejectAndUnlink,
                  child: const Text('No estoy de acuerdo', style: TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}