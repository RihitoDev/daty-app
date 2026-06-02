import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
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
    "La comunicación es clave, escúchense mutuamente.",
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
      // Necesitamos el UID del usuario actual para darle su propia XP
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
      
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupCode);
      String memoryDocId = '${widget.groupCode}_${widget.adventureData['number']}';
      DocumentReference memoryRef = FirebaseFirestore.instance.collection('group_memories').doc(memoryDocId);
      DocumentReference myUserRef = FirebaseFirestore.instance.collection('users').doc(myUid);

      int expEarned = widget.adventureData['xpBase'] ?? 50;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupSnap = await transaction.get(groupRef);
        
        if (!groupSnap.exists) return; // El grupo fue eliminado

        List<dynamic> completedBy = [];
        if (groupSnap.data()!.containsKey('completedBy')) {
          completedBy = List<dynamic>.from(groupSnap.data()!['completedBy']);
        }

        // 1. Cada quien se da su PROPIA XP (Firebase lo permite sin problemas)
        if (!completedBy.contains(myUid)) {
          transaction.update(myUserRef, {
            'exp': FieldValue.increment(expEarned), 
            'groupOutingsCompleted': FieldValue.increment(1)
          });
          
          // Me agrego a la lista para no volver a cobrar la XP
          completedBy.add(myUid);
          transaction.update(groupRef, {
            'status': 'completed',
            'completedBy': completedBy
          });
        }

        // 2. Crear documento de memoria grupal fusionando los datos (merge: true)
        transaction.set(memoryRef, {
          'adventure_title': widget.adventureData['title'],
          'emoji': widget.adventureData['emoji'] ?? '👥',
          'id_adventure': widget.adventureData['number'].toString(),
          'members': widget.members,
          'timestamp': FieldValue.serverTimestamp(),
          // No sobreescribimos 'photos' para no borrar las fotos de quienes ya subieron
        }, SetOptions(merge: true)); 

      });

      // 3. TODOS navegan a la pantalla de fotos, sin importar quién le dio primero
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupPhotoUploadScreen(
          groupCode: widget.groupCode, 
          adventureData: widget.adventureData, 
          members: widget.members,
        )));
      }
    } catch (e) {
      if(mounted) {
        debugPrint('Error en completeAdventure: $e');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al finalizar la expedición'), backgroundColor: Colors.redAccent));
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