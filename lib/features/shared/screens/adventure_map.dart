import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../couple/widgets/candy_path_painter.dart';

class AdventureMap extends StatefulWidget {
  final String mode;
  final Color themeColor;
  final Color pathColor;
  final int totalNodes;
  final String headerTitle;
  
  // Callbacks para desacoplar la navegación
  final Widget Function(Map<String, dynamic> adventureData, List<int> availableIds) onNavigateToProgress;
  final Widget Function(int adventureId, Map<String, dynamic> adventureData) onNavigateToMemory;

  const AdventureMap({
    super.key,
    required this.mode,
    required this.themeColor,
    required this.pathColor,
    required this.totalNodes,
    required this.headerTitle,
    required this.onNavigateToProgress,
    required this.onNavigateToMemory,
  });

  @override
  State<AdventureMap> createState() => _AdventureMapState();
}

class _AdventureMapState extends State<AdventureMap> with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  late double mapHeight;

  List<int> _adventurePath = []; 
  int? activeAdventureNumber; 
  String? _partnerId;
  String? _coupleDocId;

  bool _reviewCompletedUser1 = false;
  bool _reviewCompletedUser2 = false;

  final Map<int, Map<String, dynamic>> _adventuresCache = {};
  Map<int, double> _adventureRatings = {}; 
  bool _isLoadingData = true;
  StreamSubscription? _progressSubscription;
  bool _isFetchingRatings = false; 

  late AnimationController _pulseController;

  // Variables para decoraciones aleatorias
  late List<String> _shuffledDecorationImages;
  late List<double> _shuffledDecorationSizes;

  @override
  void initState() {
    super.initState();
    mapHeight = (widget.totalNodes * 100.0) + 300;
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      lowerBound: 0.9,
      upperBound: 1.1,
    )..repeat(reverse: true);

    final List<String> allDecoImages = [
      'assets/images/deco_cristo.png',
      'assets/images/deco_palacio.png',
      'assets/images/deco_teleferico.png',
      'assets/images/deco_catedral.png',
      'assets/images/deco_cancha.png',
      'assets/images/deco_laguna.png',
      'assets/images/deco_espana.png',
      'assets/images/deco_turquesa.png',
      'assets/images/deco_recoleta.png',
    ];
    
    final List<double> possibleSizes = [200.0, 210.0, 230.0, 220.0, 205.0];

    _shuffledDecorationImages = List.from(allDecoImages)..shuffle();
    _shuffledDecorationSizes = List.from(possibleSizes)..shuffle();

    _fetchAdventures();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _progressSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _scrollToCurrentNode() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      
      try {
        int targetIndex = _adventurePath.isEmpty ? 0 : _adventurePath.length - 1;
        
        if (activeAdventureNumber != null) {
          int activeIdx = _adventurePath.indexOf(activeAdventureNumber!);
          if (activeIdx != -1) targetIndex = activeIdx; 
        } else {
          for (int i = 0; i < _adventurePath.length; i++) {
            if (!_adventureRatings.containsKey(_adventurePath[i])) {
              targetIndex = i;
              break;
            }
          }
        }

        if (targetIndex < 0) return;
        
        double targetY = mapHeight - 150 - (100.0 * targetIndex);
        double viewportHeight = MediaQuery.of(context).size.height;
        double targetScrollOffset = targetY - viewportHeight + 150; 
        
        double maxScroll = _scrollController.position.maxScrollExtent;
        double minScroll = _scrollController.position.minScrollExtent;
        targetScrollOffset = targetScrollOffset.clamp(minScroll, maxScroll);
        
        _scrollController.animateTo(targetScrollOffset, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      } catch (e) {
        debugPrint("Error seguro al hacer scroll: $e");
      }
    });
  }

  Future<void> _fetchAdventures() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final myUid = authProvider.user!.uid;
      final partnerId = authProvider.userData?['partnerId'] as String?;
      _partnerId = partnerId;

      if (widget.mode == 'couple' && partnerId != null) {
        _coupleDocId = myUid.compareTo(partnerId) < 0 ? '${myUid}_$partnerId' : '${partnerId}_$myUid';
      }

      if (widget.mode == 'solo') {
        _progressSubscription = FirebaseFirestore.instance.collection('solo_progress').doc(myUid).snapshots().listen(
          (snapshot) async {
            if (snapshot.exists && mounted) {
              final data = snapshot.data() as Map<String, dynamic>;
              final rawActive = data['activeAdventureNumber'];
              setState(() {
                activeAdventureNumber = rawActive is int ? rawActive : (rawActive != null ? int.tryParse(rawActive.toString()) : null); 
                _adventurePath = List<int>.from(data['adventurePath'] ?? []);
              });
              await _fetchRatings(myUid: myUid);
              _scrollToCurrentNode();
            }
          },
          onError: (error) => debugPrint("Error en Stream Solo: $error"),
          cancelOnError: false, 
        );
      } else if (_coupleDocId != null) {
        _progressSubscription = FirebaseFirestore.instance.collection('couples_progress').doc(_coupleDocId!).snapshots().listen(
          (snapshot) async {
            if (snapshot.exists && mounted) {
              final data = snapshot.data() as Map<String, dynamic>;
              final rawActive = data['activeAdventureNumber'];
              setState(() {
                activeAdventureNumber = rawActive is int ? rawActive : (rawActive != null ? int.tryParse(rawActive.toString()) : null); 
                _adventurePath = List<int>.from(data['adventurePath'] ?? []);
                _reviewCompletedUser1 = data['reviewCompletedUser1'] ?? false;
                _reviewCompletedUser2 = data['reviewCompletedUser2'] ?? false;
              });
              await _fetchRatings(coupleDocId: _coupleDocId);
              _scrollToCurrentNode();
            }
          },
          onError: (error) => debugPrint("Error en Stream Pareja: $error"),
          cancelOnError: false,
        );
      }

      final snapshot = await FirebaseFirestore.instance 
          .collection('adventures')
          .where('type', isEqualTo: widget.mode == 'solo' ? 'solo' : 'pareja')
          .get()
          .timeout(const Duration(seconds: 10));
          
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data.containsKey('number')) {
          _adventuresCache[data['number']] = data;
        }
      }

    } catch (e) {
      debugPrint('Error cargando aventuras iniciales: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
        if (_adventurePath.isEmpty && _adventuresCache.isNotEmpty) {
          final authProvider = Provider.of<AuthProvider>(context, listen: false);
          final myUid = authProvider.user!.uid;
          await _generateNextNode(myUid: myUid, coupleDocId: _coupleDocId);
        }
      }
    }
  }

  Future<void> _fetchRatings({String? myUid, String? coupleDocId}) async {
    if (_adventurePath.isEmpty || _isFetchingRatings) return; 
    _isFetchingRatings = true;

    Map<int, double> tempRatings = {};
    
    try {
      List<List<int>> chunks = [];
      for (var i = 0; i < _adventurePath.length; i += 30) {
        chunks.add(_adventurePath.sublist(i, i + 30 > _adventurePath.length ? _adventurePath.length : i + 30));
      }
      
      for (var chunk in chunks) {
        if (widget.mode == 'solo' && myUid != null) {
          List<String> docIds = chunk.map((id) => '${myUid}_$id').toList();
          var snapshot = await FirebaseFirestore.instance.collection('solo_memories').where(FieldPath.documentId, whereIn: docIds).get();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            int advId = data['id_adventure'] is int ? data['id_adventure'] : int.parse(data['id_adventure'].toString());
            int r1 = data['rating'] ?? 0;
            if (r1 > 0) tempRatings[advId] = r1.toDouble();
          }
        } else if (widget.mode == 'couple' && coupleDocId != null) {
          List<String> docIds = chunk.map((id) => '${coupleDocId}_$id').toList();
          var snapshot = await FirebaseFirestore.instance.collection('memories').where(FieldPath.documentId, whereIn: docIds).get();
          for (var doc in snapshot.docs) {
            final data = doc.data();
            int advId = data['id_adventure'] is int ? data['id_adventure'] : int.parse(data['id_adventure'].toString());
            int r1 = data['user1_rating'] ?? 0;
            int r2 = data['user2_rating'] ?? 0;
            if (r1 > 0 && r2 > 0) {
              tempRatings[advId] = (r1 + r2) / 2.0;
            } else if (r1 > 0){ tempRatings[advId] = r1.toDouble();}
            else if (r2 > 0){tempRatings[advId] = r2.toDouble();} 
          }
        }
      }
      
      if (mounted) {
        setState(() => _adventureRatings = tempRatings);
        
        if (_adventurePath.isNotEmpty && activeAdventureNumber == null && _adventurePath.length < widget.totalNodes) {
          int lastAdventureId = _adventurePath.last;
          if (tempRatings.containsKey(lastAdventureId)) {
            await _generateNextNode(myUid: myUid, coupleDocId: coupleDocId);
          }
        }
      }
    } catch (e) {
      debugPrint("Error seguro obteniendo ratings: $e");
    } finally {
      _isFetchingRatings = false;
    }
  }

  Future<void> _generateNextNode({String? myUid, String? coupleDocId}) async {
    if (_adventuresCache.isEmpty) return;
    List<int> allIds = _adventuresCache.keys.toList();
    List<int> availableIds = allIds.where((id) => !_adventurePath.contains(id)).toList();
    if (availableIds.isEmpty) return; 
    final random = Random();
    int nextAdventureId = availableIds[random.nextInt(availableIds.length)];
    
    try {
      if (widget.mode == 'solo' && myUid != null) {
        await FirebaseFirestore.instance.collection('solo_progress').doc(myUid).set({
          'adventurePath': FieldValue.arrayUnion([nextAdventureId])
        }, SetOptions(merge: true));
      } else if (widget.mode == 'couple' && coupleDocId != null) {
        await FirebaseFirestore.instance.collection('couples_progress').doc(coupleDocId).set({
          'adventurePath': FieldValue.arrayUnion([nextAdventureId])
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint("Error generando nodo: $e");
    }
  }

  List<Offset> _generatePathPoints(double mapWidth) {
    List<Offset> points = [];
    double y = mapHeight - 150; double stepY = -100.0; 
    for (int i = 0; i < widget.totalNodes; i++) {
      double x;
      if (i % 4 == 0) { x = mapWidth * 0.15; }
      else if (i % 4 == 1){ x = mapWidth * 0.5;}  
      else if (i % 4 == 2){ x = mapWidth * 0.85;} 
      else {x = mapWidth * 0.5; }
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
    return List.generate(widget.mode == 'solo' ? 30 : 40, (i) => Offset(mapWidth * (0.05 + (i * 0.23) % 0.9), mapHeight - (i * 187) % mapHeight));
  }

  void _showAdventureDetail(Map<String, dynamic> adventure, int nodeIndex) {
    List<int> availableIds = _adventuresCache.keys.where((id) => !_adventurePath.contains(id)).toList();

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
                      Center(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Container(height: 180, width: double.infinity, color: Colors.grey.shade200, child: Image.asset('assets/images/adventures/${adventure['number']}.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image_not_supported_outlined, size: 50, color: Colors.grey))))),
                      const SizedBox(height: 15),
                      Center(child: Text(adventure['title'] ?? '', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: widget.themeColor))),
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
                        padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: widget.themeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('🏆 Reto', style: TextStyle(fontWeight: FontWeight.bold, color: widget.themeColor)),
                          const SizedBox(height: 5),
                          Text(adventure['challenge'] ?? '', style: TextStyle(color: widget.themeColor)),
                        ]),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity, height: 55,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(bottomSheetContext); 
                            _showTipsBeforeStart(adventure, nodeIndex, availableIds);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
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

  void _showTipsBeforeStart(Map<String, dynamic> adventure, int nodeIndex, List<int> availableIds) {
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
                Icon(Icons.lightbulb_outline, color: widget.themeColor, size: 50),
                const SizedBox(height: 15),
                const Text('Consejos antes de salir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Text(adventure['tips'] ?? 'Disfruta el momento.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                const SizedBox(height: 25),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar'))),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(dialogContext); 
                        bool success = await _setAdventureStatus(adventure['number'], true); 
                        if (success && mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => widget.onNavigateToProgress(adventure, availableIds)));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
                      child: const Text('Iniciar', style: TextStyle(color: Colors.white)),
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

  Future<bool> _setAdventureStatus(int adventureNumber, bool isActive) async {
    try {
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
      
      if (widget.mode == 'solo') {
        DocumentReference docRef = FirebaseFirestore.instance.collection('solo_progress').doc(myUid);
        if (isActive) {
          await docRef.set({'activeAdventureNumber': adventureNumber}, SetOptions(merge: true));
        } else {
          await docRef.update({'activeAdventureNumber': FieldValue.delete()}).catchError((e) => null);
        }
      } else if (_coupleDocId != null) {
        DocumentReference docRef = FirebaseFirestore.instance.collection('couples_progress').doc(_coupleDocId!);
        if (isActive) {
          await docRef.set({
            'activeAdventureNumber': adventureNumber,
            'reviewCompletedUser1': false, 
            'reviewCompletedUser2': false,
          }, SetOptions(merge: true));
        } else {
          await docRef.update({
            'activeAdventureNumber': FieldValue.delete(),
            'reviewCompletedUser1': false, 
            'reviewCompletedUser2': false,
          }).catchError((e) => null);
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error guardando estado: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error de conexión al iniciar.')));
      return false;
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
    
    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;

    double mapProgress = _adventurePath.isEmpty ? 0.0 : _adventurePath.length / widget.totalNodes;
    int completedDates = _adventurePath.length;

    double fogBottom;
    if (_adventurePath.isEmpty) {
      fogBottom = 0; 
    } else {
      double fogTopY = pathPoints[_adventurePath.length - 1].dy - 100; 
      fogBottom = (mapHeight - (fogTopY + 50)).clamp(0.0, mapHeight); 
    }

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [widget.pathColor.withValues(alpha: 0.3), Colors.white, const Color(0xFFAED581), const Color(0xFF66BB6A)], stops: const [0.0, 0.3, 0.6, 1.0])),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SizedBox(
                width: mapWidth, height: mapHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    ...ambientPoints.map((pos) => Positioned(left: pos.dx, top: pos.dy, child: Icon(Icons.local_florist, color: widget.pathColor.withValues(alpha: 0.3), size: 30))),
                    CustomPaint(size: Size(mapWidth, mapHeight), painter: CandyPathPainter(points: pathPoints, pathColor: widget.pathColor)),
                    ...decoPoints.asMap().entries.map((entry) => _buildStaticDecoration(entry.value.dx, entry.value.dy, entry.key)),
                    ...pathPoints.asMap().entries.map((entry) {
                      int nodeIndex = entry.key; 
                      int adventureId = nodeIndex < _adventurePath.length ? _adventurePath[nodeIndex] : -1;
                      Map<String, dynamic>? adventureData = _adventuresCache[adventureId];
                      bool isUnlocked = nodeIndex < _adventurePath.length;
                      return _buildGameNode(entry.value.dx, entry.value.dy, nodeIndex + 1, adventureId, adventureData, isUnlocked, myUid);
                    }),
                    if (_adventurePath.length < widget.totalNodes)
                      Positioned(top: 0, left: 0, right: 0, bottom: fogBottom,
                        child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.transparent, Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.98), const Color(0xFFE0E0E0)], stops: const [0.0, 0.15, 0.4, 1.0])))),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, left: 10, right: 10,
            child: Row(
              children: [
                Material(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(30), child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(widget.headerTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('$completedDates/${widget.totalNodes}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: mapProgress,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
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

  Widget _buildStaticDecoration(double x, double y, int index) {
    final String imagePath = _shuffledDecorationImages[index % _shuffledDecorationImages.length];
    final double size = _shuffledDecorationSizes[index % _shuffledDecorationSizes.length];

    return Positioned(
      left: x - (size / 2), 
      top: y - (size / 2), 
      child: SizedBox(
        width: size, 
        height: size, 
        child: Image.asset(
          imagePath, 
          fit: BoxFit.contain, // Contain respeta la forma original del PNG
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.location_city, 
            color: const Color(0xFF9C27B0), 
            size: size * 0.5
          )
        )
      )
    );
  }

  Widget _buildGameNode(double x, double y, int displayNumber, int adventureId, Map<String, dynamic>? adventureData, bool isUnlocked, String myUid) {
    int arrayIndex = displayNumber - 1; 
    bool isLocked = !isUnlocked; 
    bool isInProgress = activeAdventureNumber == adventureId;
    bool isCompleted = isUnlocked && _adventureRatings.containsKey(adventureId) && !isInProgress;
    bool isNextStep = isUnlocked && !isCompleted && !isInProgress;

    bool isUser1 = _partnerId != null && myUid.compareTo(_partnerId!) < 0;
    
    bool iReviewed = false;
    bool partnerReviewed = false;
    bool isWaitingForPartner = false;

    if (widget.mode == 'couple' && isInProgress) {
      iReviewed = isUser1 ? _reviewCompletedUser1 : _reviewCompletedUser2;
      partnerReviewed = isUser1 ? _reviewCompletedUser2 : _reviewCompletedUser1;
      isWaitingForPartner = iReviewed && !partnerReviewed;
    }

    Color startColor; Color endColor; Widget iconChild;
    
    if (isWaitingForPartner) {
      startColor = const Color(0xFFFFCA28); endColor = const Color(0xFFFFA000); 
      iconChild = const Icon(Icons.hourglass_top, color: Colors.white, size: 28);
    } else if (isInProgress) {
      startColor = const Color(0xFFFFA000); endColor = const Color(0xFFFF6F00); 
      iconChild = const Icon(Icons.adjust, color: Colors.white, size: 28);
    } else if (isCompleted) { 
      startColor = const Color(0xFF66BB6A); endColor = const Color(0xFF2E7D32); 
      iconChild = const Icon(Icons.check_circle, color: Colors.white, size: 28);
    } else if (isNextStep) { 
      startColor = widget.themeColor; endColor = widget.themeColor.withValues(alpha: 0.8);
      iconChild = Text(displayNumber.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1))]));
    } else { 
      startColor = Colors.grey.shade400; endColor = Colors.grey.shade600; 
      iconChild = const Icon(Icons.lock, color: Colors.white70, size: 24);
    }

    double? rating = _adventureRatings[adventureId];
    bool showRating = isCompleted && rating != null && rating > 0;

    Widget nodeCircle = Container(
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
    );

    if (isNextStep || isInProgress || isWaitingForPartner) {
      nodeCircle = ScaleTransition(scale: _pulseController, child: nodeCircle);
    }

    return Positioned(
      left: x - 30, 
      top: y - (showRating ? 42 : 30), 
      child: GestureDetector(
        onTap: isLocked || adventureData == null ? null : () {
          if (isWaitingForPartner) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ya calificaste. ¡Esperando a tu pareja!')));
          } else if (isInProgress) {
            List<int> availableIds = _adventuresCache.keys.where((id) => !_adventurePath.contains(id)).toList();
            Navigator.push(context, MaterialPageRoute(builder: (_) => widget.onNavigateToProgress(adventureData, availableIds)));
          } else if (isCompleted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => widget.onNavigateToMemory(adventureId, adventureData)));
          } else if (isNextStep) {
            _showAdventureDetail(adventureData, arrayIndex);
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            nodeCircle,
            if (showRating)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 2))]),
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
}