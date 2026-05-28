import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'group_photo_upload_screen.dart';

class GroupAdventureScreen extends StatefulWidget {
  final Map<String, dynamic> adventureData;
  final String groupCode;
  final List<String> members;

  const GroupAdventureScreen({super.key, required this.adventureData, required this.groupCode, required this.members});

  @override
  State<GroupAdventureScreen> createState() => _GroupAdventureScreenState();
}

class _GroupAdventureScreenState extends State<GroupAdventureScreen> {
  final List<String> _groupTips = [
    "Asegúrense de que todos participen en las decisiones.",
    "Tomen fotos grupales para el recuerdo.",
    "Si alguien va lento, ajusten el ritmo del grupo.",
    "La comunicación es clave, escóchense mutuamente.",
    "Diviértanse y no se tomen todo demasiado en serio.",
    "Compartan los gastos de manera justa.",
  ];

  int _currentTipIndex = 0;
  Timer? _tipTimer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startTipTimer();
  }

  void _startTipTimer() {
    _tipTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() => _currentTipIndex = (_currentTipIndex + 1) % _groupTips.length);
      }
    });
  }

  Future<void> _completeAdventure() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupCode);
      
      // CAMBIO CRÍTICO: Usamos transacción para evitar dar XP multiple veces
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupSnap = await transaction.get(groupRef);
        
        if (!groupSnap.exists) return; // El grupo ya fue eliminado
        
        final status = groupSnap.data()!['status'];

        // Si el grupo ya fue marcado como completado por otro usuario, solo navegamos
        if (status == 'completed') return;

        int expEarned = widget.adventureData['xpBase'] ?? 50;

        // Dar XP a todos los miembros
        for (String uid in widget.members) {
          DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(uid);
          transaction.update(userRef, {'exp': FieldValue.increment(expEarned), 'groupOutingsCompleted': FieldValue.increment(1)});
        }

        // Crear documento de memoria grupal
        String memoryDocId = '${widget.groupCode}_${widget.adventureData['number']}';
        DocumentReference memoryRef = FirebaseFirestore.instance.collection('group_memories').doc(memoryDocId);
        
        transaction.set(memoryRef, {
          'adventure_title': widget.adventureData['title'],
          'emoji': widget.adventureData['emoji'] ?? '👥',
          'id_adventure': widget.adventureData['number'].toString(),
          'members': widget.members,
          'timestamp': FieldValue.serverTimestamp(),
          'photos': {},
        });

        // Marcar grupo como completado en vez de borrarlo
        transaction.update(groupRef, {'status': 'completed'});
      });

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupPhotoUploadScreen(
          groupCode: widget.groupCode, 
          adventureData: widget.adventureData, 
          members: widget.members,
        )));
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al finalizar'), backgroundColor: Colors.redAccent));
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String adventureTitle = (widget.adventureData['title'] ?? 'AVENTURA').toUpperCase();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: FittedBox(fit: BoxFit.scaleDown, child: Text('Grupo: $adventureTitle', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
        centerTitle: true, 
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.groups_rounded, size: 80, color: Color(0xFF8E24AA)),
            const SizedBox(height: 40),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Container(
                key: ValueKey<int>(_currentTipIndex),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF8E24AA).withValues(alpha: 0.5))),
                child: Column(children: [
                  const Icon(Icons.lightbulb_outline, color: Colors.amber, size: 30),
                  const SizedBox(height: 15),
                  Text(_groupTips[_currentTipIndex], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic)),
                ]),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _completeAdventure,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8E24AA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), disabledBackgroundColor: Colors.grey),
                icon: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Finalizar Expedición', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}