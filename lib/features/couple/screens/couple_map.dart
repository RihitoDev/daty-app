import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/candy_path_painter.dart';
import 'adventure_in_progress_screen.dart';
import 'adventure_memory_screen.dart';

class CoupleMap extends StatefulWidget {
  const CoupleMap({super.key});

  @override
  State<CoupleMap> createState() => _CoupleMapState();
}

class _CoupleMapState extends State<CoupleMap> {
  final ScrollController _scrollController = ScrollController();
  final int totalNodes = 50; 
  late double mapHeight;

  List<int> _adventurePath = []; 
  int? activeAdventureNumber; 
  String? _partnerId;

  bool _reviewCompletedUser1 = false;
  bool _reviewCompletedUser2 = false;

  final Map<int, Map<String, dynamic>> _adventuresCache = {};
  Map<int, double> _adventureRatings = {}; 
  bool _isLoadingData = true;
  StreamSubscription? _coupleProgressSubscription;

  @override
  void initState() {
    super.initState();
    mapHeight = (totalNodes * 100.0) + 300;
    _fetchAdventures();
  }

  void _scrollToCurrentNode() {
    if (!_scrollController.hasClients) return;
    
    int targetIndex = _adventurePath.length - 1;
    if (activeAdventureNumber != null) {
      int activeIdx = _adventurePath.indexOf(activeAdventureNumber!);
      if (activeIdx != -1) targetIndex = activeIdx; 
    }
    if (targetIndex < 0) return;
    
    double targetY = mapHeight - 150 - (100.0 * targetIndex);
    double viewportHeight = MediaQuery.of(context).size.height;
    double targetScrollOffset = targetY - viewportHeight + 150; 
    
    double maxScroll = _scrollController.position.maxScrollExtent;
    double minScroll = _scrollController.position.minScrollExtent;
    targetScrollOffset = targetScrollOffset.clamp(minScroll, maxScroll);
    
    _scrollController.animateTo(targetScrollOffset, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
  }

  Future<void> _fetchAdventures() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userData = authProvider.userData;
      if (userData == null) return;

      final myUid = authProvider.user!.uid;
      final partnerId = userData['partnerId'] as String;
      _partnerId = partnerId;
      String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';

      _coupleProgressSubscription = FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).snapshots().listen((snapshot) async {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              activeAdventureNumber = data['activeAdventureNumber']; 
              _adventurePath = List<int>.from(data['adventurePath'] ?? []);
              _reviewCompletedUser1 = data['reviewCompletedUser1'] ?? false;
              _reviewCompletedUser2 = data['reviewCompletedUser2'] ?? false;
            });
            await _fetchRatings(coupleDocId);
            WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrentNode());
          }
        }
      });

      final snapshot = await FirebaseFirestore.instance.collection('adventures').get();
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('number')) {
          _adventuresCache[data['number']] = data;
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
        if (_adventurePath.isEmpty && _adventuresCache.isNotEmpty) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final myUid = authProvider.user!.uid;
          final partnerId = authProvider.userData!['partnerId'];
          String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
          await _generateNextNode(coupleDocId);
        }
      }
    }
  }

  Future<void> _fetchRatings(String coupleDocId) async {
    if (_adventurePath.isEmpty) return;
    Map<int, double> tempRatings = {};
    
    List<List<int>> chunks = [];
    for (var i = 0; i < _adventurePath.length; i += 30) {
      chunks.add(_adventurePath.sublist(i, i + 30 > _adventurePath.length ? _adventurePath.length : i + 30));
    }
    
    for (var chunk in chunks) {
      List<String> docIds = chunk.map((id) => '${coupleDocId}_$id').toList();
      var snapshot = await FirebaseFirestore.instance.collection('memories').where(FieldPath.documentId, whereIn: docIds).get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        int advId = int.parse(data['id_adventure']);
        int r1 = data['user1_rating'] ?? 0;
        int r2 = data['user2_rating'] ?? 0;
        
        if (r1 > 0 && r2 > 0) {
          tempRatings[advId] = (r1 + r2) / 2.0;
        } else if (r1 > 0) {
          tempRatings[advId] = r1.toDouble();
        } else if (r2 > 0) {
          tempRatings[advId] = r2.toDouble();
        }
      }
    }
    
    if (mounted) {
      setState(() {
        _adventureRatings = tempRatings;
      });
    }
  }

  Future<void> _generateNextNode(String coupleDocId) async {
    if (_adventuresCache.isEmpty) return;
    List<int> allIds = _adventuresCache.keys.toList();
    List<int> availableIds = allIds.where((id) => !_adventurePath.contains(id)).toList();
    if (availableIds.isEmpty) return; 
    final random = Random();
    int nextAdventureId = availableIds[random.nextInt(availableIds.length)];
    await FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).update({
      'adventurePath': FieldValue.arrayUnion([nextAdventureId])
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _coupleProgressSubscription?.cancel();
    super.dispose();
  }

  List<Offset> _generatePathPoints(double mapWidth) {
    List<Offset> points = [];
    double y = mapHeight - 150; double stepY = -100.0; 
    for (int i = 0; i < totalNodes; i++) {
      double x;
      if (i % 4 == 0) {
        x = mapWidth * 0.15;
      } else if (i % 4 == 1) x = mapWidth * 0.5;  
      else if (i % 4 == 2) x = mapWidth * 0.85; 
      else x = mapWidth * 0.5;  
      points.add(Offset(x, y));
      y += stepY;
    }
    return points;
  }

  List<Offset> _generateDecorationPoints(List<Offset> pathPoints, double mapWidth) {
    List<Offset> points = [];
    for (int i = 0; i < pathPoints.length; i++) {
      if (i % 2 == 0) {
        Offset p = pathPoints[i];
        double pathXRatio = p.dx / mapWidth;
        double decoX = pathXRatio < 0.35 ? mapWidth * 0.85 : (pathXRatio > 0.65 ? mapWidth * 0.15 : (i % 4 == 0 ? mapWidth * 0.1 : mapWidth * 0.9));
        points.add(Offset(decoX, p.dy + 20));
      }
    }
    return points;
  }

  List<Offset> _generateAmbientDecor(double mapWidth) {
    return List.generate(40, (i) => Offset(mapWidth * (0.05 + (i * 0.23) % 0.9), mapHeight - (i * 187) % mapHeight));
  }

  void _showAdventureDetail(Map<String, dynamic> adventure, int nodeIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (bottomSheetContext) { 
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
          child: Column(
            children: [
              Container(margin: const EdgeInsets.symmetric(vertical: 12), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            height: 180, width: double.infinity, color: Colors.grey.shade200,
                            child: Image.asset('assets/images/adventures/${adventure['number']}.png', fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey.shade400),
                                const SizedBox(height: 8),
                                Text('Imagen no disponible', style: TextStyle(color: Colors.grey.shade500)),
                              ]),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      Center(child: Text(adventure['title'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFC2185B)))),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildInfoChip(Icons.category, adventure['category'] ?? 'General'),
                          const SizedBox(width: 10),
                          _buildInfoChip(Icons.timer, adventure['estimatedTime'] ?? '1 hora'),
                          const SizedBox(width: 10),
                          _buildInfoChip(Icons.attach_money, 'Nivel \$${adventure['costLevel'] ?? 1}'),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text('Descripción', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 5),
                      Text(adventure['description'] ?? '', style: TextStyle(fontSize: 15, color: Colors.grey.shade700)),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFFFCE4EC), borderRadius: BorderRadius.circular(15)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('🏆 Reto de la Cita', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC2185B))),
                          const SizedBox(height: 5),
                          Text(adventure['challenge'] ?? '', style: const TextStyle(color: Color(0xFF880E4F))),
                        ]),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(bottomSheetContext); 
                            _showTipsBeforeStart(adventure, nodeIndex);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC2185B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                          label: const Text('Empezar Aventura', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTipsBeforeStart(Map<String, dynamic> adventure, int nodeIndex) {
    showDialog(
      context: context,
      builder: (dialogContext) { 
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0), size: 50),
                const SizedBox(height: 15),
                const Text('Consejos antes de salir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Text(adventure['tips'] ?? 'Disfruten el momento.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                const SizedBox(height: 25),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar'))),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext); 
                        await _setAdventureStatus(adventure['number'], true); 
                        if (mounted) {
                          List<int> availableIds = _adventuresCache.keys.where((id) => !_adventurePath.contains(id)).toList();
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AdventureInProgressScreen(adventureData: adventure, availableAdventuresIds: availableIds)));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
                      child: const Text('Iniciar Cita', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ])
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setAdventureStatus(int adventureNumber, bool isActive) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final myUid = authProvider.user!.uid;
      final partnerId = authProvider.userData!['partnerId'];
      String coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';

      await FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).update({
        'activeAdventureNumber': isActive ? adventureNumber : FieldValue.delete(),
        'reviewCompletedUser1': false, 
        'reviewCompletedUser2': false,
      });
    } catch (e) {
      debugPrint('Error guardando estado de cita: $e');
    }
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade300)),
      child: Row(children: [
        Icon(icon, size: 16, color: Colors.grey.shade600), const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double mapWidth = MediaQuery.of(context).size.width;
    final pathPoints = _generatePathPoints(mapWidth);
    final decoPoints = _generateDecorationPoints(pathPoints, mapWidth); 
    final ambientPoints = _generateAmbientDecor(mapWidth);
    
    // Cálculo del progreso del mapa
    double mapProgress = _adventurePath.isEmpty ? 0.0 : _adventurePath.length / totalNodes;
    int completedDates = _adventurePath.length;

    double fogBottom;
    if (_adventurePath.isEmpty) {
      fogBottom = 0; 
    } else {
      double fogTopY = pathPoints[_adventurePath.length - 1].dy - 100; 
      fogBottom = mapHeight - (fogTopY + 50);
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF87CEEB), Color(0xFFE0F7FA), Color(0xFFAED581), Color(0xFF66BB6A)], stops: [0.0, 0.3, 0.6, 1.0])),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SizedBox(
                width: mapWidth, height: mapHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    ...ambientPoints.map((pos) => _buildFlower(pos.dx, pos.dy)),
                    CustomPaint(size: Size(mapWidth, mapHeight), painter: CandyPathPainter(points: pathPoints)),
                    ...decoPoints.asMap().entries.map((entry) => _buildStaticDecoration(entry.value.dx, entry.value.dy, entry.key)),
                    ...pathPoints.asMap().entries.map((entry) {
                      int nodeIndex = entry.key; 
                      int adventureId = nodeIndex < _adventurePath.length ? _adventurePath[nodeIndex] : -1;
                      Map<String, dynamic>? adventureData = _adventuresCache[adventureId];
                      bool isInProgress = activeAdventureNumber == adventureId;
                      bool isUnlocked = nodeIndex < _adventurePath.length;
                      return _buildGameNode(entry.value.dx, entry.value.dy, nodeIndex + 1, adventureId, adventureData, isUnlocked, isInProgress);
                    }),
                    if (_adventurePath.length < totalNodes)
                      Positioned(top: 0, left: 0, right: 0, bottom: fogBottom,
                        child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.transparent, Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.98), const Color(0xFFE0E0E0)], stops: const [0.0, 0.15, 0.4, 1.0])))),
                  ],
                ),
              ),
            ),
          ),
          
          // Header con botón atrás y barra de progreso DEL MAPA
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, 
            left: 10,
            right: 10,
            child: Row(
              children: [
                Material(
                  color: Colors.black.withValues(alpha: 0.4), 
                  borderRadius: BorderRadius.circular(30), 
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), 
                    onPressed: () => Navigator.pop(context)
                  )
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Nuestro Viaje', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('$completedDates/$totalNodes', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: mapProgress,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFC2185B)), // Color rosa temático
                            minHeight: 8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlower(double x, double y) => Positioned(left: x, top: y, child: Icon(Icons.local_florist, color: Colors.pinkAccent.withValues(alpha: 0.3), size: 30));

    Widget _buildGameNode(double x, double y, int displayNumber, int adventureId, Map<String, dynamic>? adventureData, bool isUnlocked, bool isInProgress) {
    // ✅ CORRECCIÓN: Calculamos el índice real de la lista (0-49) en vez del número de pantalla (1-50)
    int arrayIndex = displayNumber - 1; 

    bool isLocked = !isUnlocked; 
    bool isCompleted = isUnlocked && arrayIndex < _adventurePath.length - 1 && !isInProgress; // Nodos anteriores al actual
    bool isNextStep = isUnlocked && arrayIndex == _adventurePath.length - 1 && !isInProgress; // Último nodo desbloqueado (Próximo paso)

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProvider.user!.uid;
    final partnerId = authProvider.userData!['partnerId'];
    bool isUser1 = myUid.compareTo(partnerId) < 0;
    bool iReviewed = isInProgress && (isUser1 ? _reviewCompletedUser1 : _reviewCompletedUser2);
    bool partnerReviewed = isInProgress && (isUser1 ? _reviewCompletedUser2 : _reviewCompletedUser1);
    bool isWaitingForPartner = isInProgress && iReviewed && !partnerReviewed;

    Color startColor; Color endColor; Widget iconChild;
    
    if (isWaitingForPartner) {
      startColor = const Color(0xFFFFCA28); endColor = const Color(0xFFFFA000); 
      iconChild = const Icon(Icons.hourglass_top, color: Colors.white, size: 28);
    } else if (isInProgress) {
      startColor = const Color(0xFFFFA000); endColor = const Color(0xFFFF6F00); 
      iconChild = const Icon(Icons.adjust, color: Colors.white, size: 28);
    } else if (isCompleted) { // ✅ ESTILO PARA COMPLETADOS
      startColor = const Color(0xFF66BB6A); endColor = const Color(0xFF2E7D32); 
      iconChild = const Icon(Icons.check_circle, color: Colors.white, size: 28);
    } else if (isNextStep) { 
      startColor = const Color(0xFFFF4081); endColor = const Color(0xFFC2185B); 
      iconChild = Text(displayNumber.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1))]));
    } else { // Locked
      startColor = Colors.grey.shade400; endColor = Colors.grey.shade600; 
      iconChild = const Icon(Icons.lock, color: Colors.white70, size: 24);
    }

    double? rating = _adventureRatings[adventureId];
    bool showRating = !isLocked && !isInProgress && rating != null && rating > 0;

    return Positioned(
      left: x - 30, 
      top: y - (showRating ? 42 : 30), 
      child: GestureDetector(
        // ✅ LÓGICA DE NAVEGACIÓN ACTUALIZADA
        onTap: isLocked || adventureData == null ? null : () {
          if (isWaitingForPartner) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya calificaste. ¡Esperando a tu pareja!')));
          } else if (isInProgress) {
            List<int> availableIds = _adventuresCache.keys.where((id) => !_adventurePath.contains(id)).toList();
            Navigator.push(context, MaterialPageRoute(builder: (_) => AdventureInProgressScreen(adventureData: adventureData, availableAdventuresIds: availableIds)));
          } else if (isCompleted) {
            // Ir a ver el recuerdo de la cita pasada
            final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
            String coupleDocId = myUid.compareTo(_partnerId!) < 0 ? '${myUid}_$partnerId' : '${_partnerId}_$myUid';
            
            Navigator.push(context, MaterialPageRoute(builder: (_) => AdventureMemoryScreen(
              coupleDocId: coupleDocId, 
              adventureId: adventureId, 
              adventureData: adventureData
            )));
          } else if (isNextStep) {
            // Mostrar detalle para empezar la nueva cita (usamos arrayIndex aquí también)
            _showAdventureDetail(adventureData, arrayIndex);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60, 
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [startColor, endColor], center: Alignment.center, radius: 0.5),
                border: Border.all(color: Colors.white, width: isInProgress ? 4 : 3), 
                boxShadow: [BoxShadow(color: startColor.withValues(alpha: 0.6), blurRadius: isInProgress ? 12 : 6, offset: const Offset(2, 4))], 
              ),
              child: Center(
                child: _isLoadingData 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : iconChild,
              ),
            ),
            
            if (showRating)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 14),
                    const SizedBox(width: 2),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticDecoration(double x, double y, int index) {
    List<String> placeholderImages = ['https://cdn-icons-png.flaticon.com/128/2909/2909875.png', 'https://cdn-icons-png.flaticon.com/128/2909/2909878.png', 'https://cdn-icons-png.flaticon.com/128/616/616408.png', 'https://cdn-icons-png.flaticon.com/128/201/201614.png', 'https://cdn-icons-png.flaticon.com/128/2909/2909881.png', 'https://cdn-icons-png.flaticon.com/128/3191/3191118.png'];
    return Positioned(left: x - 35, top: y - 35, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.6), border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(2, 2))]), child: ClipOval(child: Padding(padding: const EdgeInsets.all(8.0), child: Image.network(placeholderImages[index % placeholderImages.length], fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => const Icon(Icons.nature, color: Colors.green, size: 30))))));
  }
}