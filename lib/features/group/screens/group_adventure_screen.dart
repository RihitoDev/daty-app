import 'dart:async';
import 'dart:ui'; // ¡Importante para el efecto de cristal (ImageFilter)!
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import 'group_photo_upload_screen.dart';
import '../../shared/widgets/custom_snackbar.dart';

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
  bool _isDetailExpanded = false; // Estado para el desplegable

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
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
      
      final groupRef = FirebaseFirestore.instance.collection('groups').doc(widget.groupCode);
      String memoryDocId = '${widget.groupCode}_${widget.adventureData['number']}';
      DocumentReference memoryRef = FirebaseFirestore.instance.collection('group_memories').doc(memoryDocId);
      DocumentReference myUserRef = FirebaseFirestore.instance.collection('users').doc(myUid);

      int expEarned = widget.adventureData['xpBase'] ?? 50;

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final groupSnap = await transaction.get(groupRef);
        
        if (!groupSnap.exists) return; 
        List<dynamic> completedBy = [];
        if (groupSnap.data()!.containsKey('completedBy')) {
          completedBy = List<dynamic>.from(groupSnap.data()!['completedBy']);
        }

        if (!completedBy.contains(myUid)) {
          transaction.update(myUserRef, {
            'exp': FieldValue.increment(expEarned), 
            'groupOutingsCompleted': FieldValue.increment(1)
          });
          
          completedBy.add(myUid);
          transaction.update(groupRef, {
            'status': 'completed',
            'completedBy': completedBy
          });
        }

        transaction.set(memoryRef, {
          'adventure_title': widget.adventureData['title'],
          'emoji': widget.adventureData['emoji'] ?? '👥',
          'id_adventure': widget.adventureData['number'].toString(),
          'members': widget.members,
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)); 
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
        debugPrint('Error en completeAdventure: $e');
        CustomSnackBar.showError(context, 'Error al finalizar la expedición');
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
    final String adventureEmoji = widget.adventureData['emoji'] ?? '👥';
    final String challenge = widget.adventureData['challenge'] ?? '';
    final String description = widget.adventureData['description'] ?? '';
    final String location = widget.adventureData['location'] ?? ''; 
    
    // Paleta de colores para el modo Grupal (Morado)
    final Color primaryColor = const Color(0xFF8E24AA);
    final Color darkBgColor = const Color(0xFF12061E); // Morado ultra oscuro
    final Color midBgColor = const Color(0xFF2A0D3F);  // Morado medio

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: darkBgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: FittedBox(
          fit: BoxFit.scaleDown, 
          child: Text(
            'Código: ${widget.groupCode}', 
            style: const TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 1.5)
          )
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Container(
        width: double.infinity, // Fuerza pantalla completa
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
              // Indicador de "En Vivo"
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
                      'EXPEDICIÓN EN CURSO',
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
              
              // Emoji en lugar del icono genérico para mantener consistencia
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

              // Tarjeta desplegable (Glassmorphism)
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
                                      // Miembros del grupo
                                      _DetailRow(icon: Icons.groups_rounded, text: "Grupo: ${widget.members.length} miembros", color: primaryColor),
                                      const SizedBox(height: 15),
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

              // Tips con efecto cristal
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
                            _groupTips[_currentTipIndex], 
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

              // Botón con gradiente
              SizedBox(
                width: double.infinity, 
                height: 55,
                child: Opacity(
                  opacity: _isSubmitting ? 0.7 : 1.0, // Efecto deshabilitado visual
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
                    child: ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _completeAdventure,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: _isSubmitting 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, color: Colors.white),
                      label: Text(
                        _isSubmitting ? 'Guardando...' : 'Finalizar Expedición', 
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                      ),
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

// Widgets auxiliares (Asegúrate de copiarlos también)
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