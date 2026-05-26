import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'adventure_review_screen.dart';
import '../../solo/screens/solo_adventure_review_screen.dart'; // NUEVO IMPORT

class AdventureInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> adventureData; 
  final List<int> availableAdventuresIds; 
  final bool isSoloMode; // NUEVO: Para saber si es modo pareja o solitario

  const AdventureInProgressScreen({
    super.key, 
    required this.adventureData, 
    required this.availableAdventuresIds, 
    this.isSoloMode = false, // Por defecto es modo pareja
  });

  @override
  State<AdventureInProgressScreen> createState() => _AdventureInProgressScreenState();
}

class _AdventureInProgressScreenState extends State<AdventureInProgressScreen> {
  final List<String> _dateTips = [
    "Deja el celular boca abajo, disfruta el momento.",
    "Considera dividir las cuentas, es un gesto de igualdad.",
    "Hazle una pregunta abierta y escucha con atención la respuesta.",
    "Camina a su ritmo, no te adelantes.",
    "Si hace frío, ofrécele tu chaqueta.",
    "No temas al silencio, a veces una mirada dice más que mil palabras.",
    "Sonríele, la positividad es contagiosa.",
    "Sé tú mismo, la autenticidad es el mejor encanto.",
    "Evita mirar a otras personas, enfócate en tu cita.",
    "Paga un detalle inesperado: un chocolate, una flor.",
  ];

  int _currentTipIndex = 0;
  Timer? _tipTimer;
  StreamSubscription? _partnerReviewListener;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _startTipTimer();
    // Solo escuchamos a la pareja si NO es modo solitario
    if (!widget.isSoloMode) {
      _listenForPartnerReview();
    }
  }

  void _startTipTimer() {
    _tipTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _dateTips.length;
        });
      }
    });
  }

  void _listenForPartnerReview() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProvider.user!.uid;
    final partnerId = authProvider.userData!['partnerId'];
    String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
    bool isUser1 = myUid.compareTo(partnerId) < 0;
    String partnerReviewField = isUser1 ? 'reviewCompletedUser2' : 'reviewCompletedUser1';

    _partnerReviewListener = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).snapshots().listen((snapshot) {
      if (snapshot.exists && mounted && !_hasNavigated) {
        final data = snapshot.data() as Map<String, dynamic>;
        bool partnerReviewed = data[partnerReviewField] ?? false;

        if (partnerReviewed) {
          _hasNavigated = true;
          _tipTimer?.cancel();
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (_) => AdventureReviewScreen(adventureData: widget.adventureData, availableAdventuresIds: widget.availableAdventuresIds))
          );
        }
      }
    });
  }

  void _goToReviewScreen() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    _tipTimer?.cancel();
    _partnerReviewListener?.cancel(); 
    
    // NAVEGACIÓN CONDICIONAL
    if (widget.isSoloMode) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => SoloAdventureReviewScreen(adventureData: widget.adventureData, availableAdventuresIds: widget.availableAdventuresIds))
      );
    } else {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => AdventureReviewScreen(adventureData: widget.adventureData, availableAdventuresIds: widget.availableAdventuresIds))
      );
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _partnerReviewListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String adventureTitle = (widget.adventureData['title'] ?? 'CITA').toUpperCase();
    final String adventureEmoji = widget.adventureData['emoji'] ?? '📍';
    final Color themeColor = widget.isSoloMode ? const Color(0xFF1976D2) : const Color(0xFFC2185B); // Azul si es solo, Rosa si es pareja

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: FittedBox(fit: BoxFit.scaleDown, child: Text(adventureTitle, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.close, color: Colors.white38), onPressed: () => Navigator.pop(context)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(adventureEmoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 40),
            
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: Container(
                key: ValueKey<int>(_currentTipIndex),
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white12)),
                child: Column(
                  children: [
                    const Icon(Icons.priority_high, color: Colors.amber, size: 30),
                    const SizedBox(height: 15),
                    Text(_dateTips[_currentTipIndex], textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
            
            const Spacer(),

            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton.icon(
                onPressed: _goToReviewScreen,
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                label: const Text('Finalizar Cita', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}