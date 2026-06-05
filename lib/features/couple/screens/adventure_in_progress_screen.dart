import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'adventure_review_screen.dart';

class AdventureInProgressScreen extends StatefulWidget {
  final Map<String, dynamic> adventureData;
  final List<int> availableAdventuresIds;
  final void Function(BuildContext)? onSoloFinish;

  const AdventureInProgressScreen({
    super.key,
    required this.adventureData,
    required this.availableAdventuresIds,
    this.onSoloFinish,
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
  bool _isDetailExpanded = false;

  @override
  void initState() {
    super.initState();
    _startTipTimer();
    // Si onSoloFinish es nulo, asumimos que es una cita de pareja y nos ponemos a escuchar al otro usuario
    if (widget.onSoloFinish == null) {
      _listenForPartnerReview();
    }
  }

  // Va rotando los tips automáticamente para darle vida a la pantalla mientras están en la cita
  void _startTipTimer() {
    _tipTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (mounted) {
        setState(() => _currentTipIndex = (_currentTipIndex + 1) % _dateTips.length);
      }
    });
  }

  void _listenForPartnerReview() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.user;
    final userData = authProvider.userData;
    
    if (user == null || userData == null) return;
    final partnerId = userData['partnerId'] as String?;
    if (partnerId == null) return;

    final myUid = user.uid;
    
    // Mantenemos la regla alfabética para asegurar que leemos el mismo documento
    final String coupleDocId = myUid.compareTo(partnerId) < 0 
        ? '${myUid}_$partnerId' 
        : '${partnerId}_$myUid';
    final bool isUser1 = myUid.compareTo(partnerId) < 0;
    
    // Escuchamos el campo del OTRO usuario para saber si ya terminó
    final String partnerReviewField = isUser1 ? 'reviewCompletedUser2' : 'reviewCompletedUser1';

    _partnerReviewListener = FirebaseFirestore.instance
        .collection('couples_progress')
        .doc(coupleDocId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && mounted && !_hasNavigated) {
        final data = snapshot.data() as Map<String, dynamic>;
        final bool partnerReviewed = data[partnerReviewField] ?? false;

        // Si la pareja ya terminó su parte, forzamos la navegación a la pantalla de review
        if (partnerReviewed) {
          _hasNavigated = true;
          _tipTimer?.cancel();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdventureReviewScreen(
                adventureData: widget.adventureData,
                availableAdventuresIds: widget.availableAdventuresIds,
              ),
            ),
          );
        }
      }
    });
  }

  void _goToReviewScreen() {
    if (_hasNavigated) return;
    _hasNavigated = true;
    
    // Es vital matar estos procesos antes de saltar de pantalla para evitar memory leaks
    _tipTimer?.cancel();
    _partnerReviewListener?.cancel();

    if (widget.onSoloFinish != null) {
      widget.onSoloFinish!(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AdventureReviewScreen(
            adventureData: widget.adventureData,
            availableAdventuresIds: widget.availableAdventuresIds,
          ),
        ),
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
    final String adventureTitle = (widget.adventureData['title'] ?? 'AVENTURA').toUpperCase();
    final String adventureEmoji = widget.adventureData['emoji'] ?? '✨';
    final String challenge = widget.adventureData['challenge'] ?? '';
    final String description = widget.adventureData['description'] ?? '';
    final String location = widget.adventureData['location'] ?? ''; 
    
    final bool isSolo = widget.onSoloFinish != null;
    
    final Color primaryColor = isSolo ? const Color(0xFF1976D2) : const Color(0xFFC2185B);
    final Color darkBgColor = isSolo ? const Color(0xFF0A1124) : const Color(0xFF240618);
    final Color midBgColor = isSolo ? const Color(0xFF0F2744) : const Color(0xFF3E0C24);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: darkBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              darkBgColor,
              midBgColor,
              darkBgColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + kToolbarHeight,
            left: 30.0,
            right: 30.0,
            bottom: MediaQuery.of(context).padding.bottom + 40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryColor.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PulsingDot(color: primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      isSolo ? 'AVENTURA EN CURSO' : 'CITA EN CURSO',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 30),
              Text(adventureEmoji, style: const TextStyle(fontSize: 80)),
              const SizedBox(height: 15),
              Text(
                adventureTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2
                ),
                textAlign: TextAlign.center
              ),
              
              const SizedBox(height: 30),
              
              GestureDetector(
                onTap: () => setState(() => _isDetailExpanded = !_isDetailExpanded),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _isDetailExpanded ? primaryColor.withOpacity(0.8) : Colors.white.withOpacity(0.15)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.menu_book_outlined, color: primaryColor, size: 20),
                                  const SizedBox(width: 10),
                                  const Text(
                                    "Detalles y Reto",
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
                                  ),
                                ],
                              ),
                              AnimatedRotation(
                                duration: const Duration(milliseconds: 300),
                                turns: _isDetailExpanded ? 0.5 : 0,
                                child: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            child: _isDetailExpanded 
                                ? Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (location.isNotEmpty) ...[
                                          _DetailRow(icon: Icons.location_on_outlined, text: location, color: primaryColor),
                                          const SizedBox(height: 15),
                                        ],
                                        if (challenge.isNotEmpty) ...[
                                          _DetailRow(icon: Icons.flag_outlined, text: "Reto: $challenge", color: primaryColor),
                                          const SizedBox(height: 15),
                                        ],
                                        if (description.isNotEmpty)
                                          Text(
                                            description,
                                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.5)
                                          ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: ClipRRect(
                  key: ValueKey<int>(_currentTipIndex),
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor.withOpacity(0.3))
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.lightbulb_outline, color: primaryColor, size: 28),
                          const SizedBox(height: 15),
                          Text(
                            _dateTips[_currentTipIndex],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 17,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 50),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.7)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _goToReviewScreen,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: Text(
                      isSolo ? 'Finalizar Aventura' : 'Finalizar Cita',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _DetailRow({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.6),
              blurRadius: 4,
            )
          ]
        ),
      ),
    );
  }
}