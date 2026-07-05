import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../services/map_data_service.dart';
import '../widgets/candy_path_painter.dart';
import '../widgets/custom_snackbar.dart';
import '../widgets/adventure_detail_sheet.dart';

class AdventureMap extends StatefulWidget {
  final String mode;
  final Color themeColor;
  final Color pathColor;
  final int totalNodes;
  final String headerTitle;
  
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
    
    final List<double> possibleSizes = [210.0, 220.0, 240.0, 230.0, 215.0];

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
      } catch (e, st) {
        debugPrint('Error scrolling to node: $e\n$st');
      }
    });
  }

  Future<void> _fetchAdventures() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final myUid = authProvider.user!.uid;
      _partnerId = authProvider.userData?['partnerId'] as String?;
      _coupleDocId = MapDataService.buildCoupleDocId(myUid, _partnerId);

      // Escuchamos en tiempo real los cambios del progreso (unificado para solo y pareja)
      DocumentReference? progressRef = MapDataService.getProgressDocRef(
        mode: widget.mode, myUid: myUid, coupleDocId: _coupleDocId,
      );

      if (progressRef != null) {
        _progressSubscription = progressRef.snapshots().listen(
          (snapshot) async {
            if (snapshot.exists && mounted) {
              final data = snapshot.data() as Map<String, dynamic>;
              final rawActive = data['activeAdventureNumber'];
              setState(() {
                activeAdventureNumber = rawActive is int ? rawActive : (rawActive != null ? int.tryParse(rawActive.toString()) : null); 
                _adventurePath = List<int>.from(data['adventurePath'] ?? []);
                if (widget.mode == 'couple') {
                  _reviewCompletedUser1 = data['reviewCompletedUser1'] ?? false;
                  _reviewCompletedUser2 = data['reviewCompletedUser2'] ?? false;
                }
              });
              await _fetchRatings();
              _scrollToCurrentNode();
            }
          },
          onError: (error) => debugPrint('${widget.mode} progress snapshot error: $error'),
          cancelOnError: false, 
        );
      }

      // Descargamos todas las aventuras para la caché local
      _adventuresCache.addAll(await MapDataService.fetchAdventureCache(widget.mode));

    } catch (e, st) {
      debugPrint('Error loading map data: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _isLoadingData = false);
        if (_adventurePath.isEmpty && _adventuresCache.isNotEmpty) {
          final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
          await MapDataService.generateNextNode(
            mode: widget.mode, myUid: myUid, coupleDocId: _coupleDocId,
            adventuresCache: _adventuresCache, adventurePath: _adventurePath,
          );
        }
      }
    }
  }

  Future<void> _fetchRatings() async {
    if (_adventurePath.isEmpty || _isFetchingRatings) return; 
    _isFetchingRatings = true;

    try {
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
      final tempRatings = await MapDataService.fetchRatings(
        mode: widget.mode, adventurePath: _adventurePath,
        myUid: myUid, coupleDocId: _coupleDocId,
      );
      
      if (mounted) {
        setState(() => _adventureRatings = tempRatings);
        
        // Si ya se calificó la última aventura, generamos la siguiente
        if (_adventurePath.isNotEmpty && activeAdventureNumber == null && _adventurePath.length < widget.totalNodes) {
          int lastAdventureId = _adventurePath.last;
          if (tempRatings.containsKey(lastAdventureId)) {
            await MapDataService.generateNextNode(
              mode: widget.mode, myUid: myUid, coupleDocId: _coupleDocId,
              adventuresCache: _adventuresCache, adventurePath: _adventurePath,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching ratings: $e');
    } finally {
      _isFetchingRatings = false;
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

  void _showAdventureDetail(int nodeIndex) {
    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
    DocumentReference? docRef = MapDataService.getProgressDocRef(
      mode: widget.mode, myUid: myUid, coupleDocId: _coupleDocId,
    );
    if (docRef == null) return;

    int currentAdventureId = (nodeIndex < _adventurePath.length) ? _adventurePath[nodeIndex] : -1;
    Map<String, dynamic>? adventure = _adventuresCache[currentAdventureId];
    if (adventure == null) return;

    AdventureDetailSheet.show(
      context: context,
      adventure: adventure,
      themeColor: widget.themeColor,
      mode: widget.mode,
      progressDocRef: docRef,
      adventuresCache: _adventuresCache,
      onReroll: () => MapDataService.rerollAdventure(
        mode: widget.mode, myUid: myUid, coupleDocId: _coupleDocId,
        adventuresCache: _adventuresCache,
        nodeIndex: nodeIndex, currentAdventureId: currentAdventureId,
      ),
      onStart: (adv, availableIds) => _showTipsBeforeStart(adv, nodeIndex, availableIds),
    );
  }

  void _showTipsBeforeStart(Map<String, dynamic> adventure, int nodeIndex, List<int> availableIds) {
    showDialog(
      context: context,
      builder: (dialogContext) { 
        return Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(20.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E).withOpacity(0.9),
                  border: Border.all(color: widget.themeColor.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lightbulb_outline, color: widget.themeColor, size: 50),
                    const SizedBox(height: 15),
                    const Text('Consejos antes de salir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 15),
                    Text(adventure['tips'] ?? 'Disfruta el momento.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7))),
                    const SizedBox(height: 25),
                    Row(children: [
                      Expanded(child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext), 
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Colors.white24)),
                        child: const Text('Cancelar')
                      )),
                      const SizedBox(width: 15),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogContext); 
                            bool success = await MapDataService.setAdventureStatus(
                              mode: widget.mode, myUid: Provider.of<AuthProvider>(context, listen: false).user!.uid,
                              coupleDocId: _coupleDocId, adventureNumber: adventure['number'], isActive: true,
                            ); 
                            if (success && mounted) {
                              Navigator.push(context, MaterialPageRoute(builder: (_) => widget.onNavigateToProgress(adventure, availableIds)));
                            } else if (mounted) {
                              CustomSnackBar.showError(context, 'Error de conexión al iniciar.');
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: widget.themeColor, elevation: 5, shadowColor: widget.themeColor),
                          child: const Text('Iniciar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ])
                  ],
                ),
              ),
            ),
          ),
        ); 
      },
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

    final List<Color> bgGradient = widget.mode == 'solo' 
        ? [const Color(0xFF050A18), const Color(0xFF0B1A3E), const Color(0xFF0F2744)]
        : [const Color(0xFF1A0515), const Color(0xFF3B0A30), const Color(0xFF2A0D3F)];

    final Color neonPathColor = widget.mode == 'solo' ? const Color(0xFF00E5FF) : const Color(0xFFFF4081);

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: bgGradient)),
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SizedBox(
                width: mapWidth, height: mapHeight,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    ...ambientPoints.map((pos) => Positioned(left: pos.dx, top: pos.dy, child: Icon(Icons.auto_awesome, color: Colors.white.withOpacity(0.15), size: 25))),
                    CustomPaint(size: Size(mapWidth, mapHeight), painter: CandyPathPainter(points: pathPoints, pathColor: neonPathColor)),
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
                        child: Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.transparent, bgGradient[0].withOpacity(0.85), bgGradient[0].withOpacity(0.98), bgGradient[0]], stops: const [0.0, 0.15, 0.4, 1.0])))),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, left: 10, right: 10,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      color: Colors.black.withOpacity(0.4),
                      child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), onPressed: () => Navigator.pop(context)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5), 
                          border: Border.all(color: Colors.white24, width: 1)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(widget.headerTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('$completedDates/${widget.totalNodes}', style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.bold, fontSize: 12)),
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
          fit: BoxFit.contain, 
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.location_city, 
            color: widget.themeColor.withOpacity(0.8), 
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
      startColor = const Color(0xFF00E676); endColor = const Color(0xFF00C853); 
      iconChild = const Icon(Icons.check_circle, color: Colors.white, size: 28);
    } else if (isNextStep) { 
      startColor = widget.themeColor; endColor = widget.themeColor.withOpacity(0.8);
      iconChild = Text(displayNumber.toString(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, shadows: [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1))]));
    } else { 
      startColor = const Color(0xFF1E1E1E); endColor = const Color(0xFF2A2A2A); 
      iconChild = const Icon(Icons.lock, color: Colors.white38, size: 24);
    }

    double? rating = _adventureRatings[adventureId];
    bool showRating = isCompleted && rating != null && rating > 0;

    Widget nodeCircle = Container(
      width: 60, height: 60, 
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [startColor, endColor], center: Alignment.center, radius: 0.5),
        border: Border.all(color: Colors.white.withOpacity(0.8), width: isInProgress ? 4 : 3), 
        boxShadow: [
          BoxShadow(color: startColor.withOpacity(0.8), blurRadius: isInProgress ? 18 : 10, spreadRadius: 2, offset: Offset.zero)
        ], 
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
            CustomSnackBar.showInfo(context, 'Ya calificaste. Esperando a tu pareja.');
          } else if (isInProgress) {
            List<int> availableIds = _adventuresCache.keys.where((id) => !_adventurePath.contains(id)).toList();
            Navigator.push(context, MaterialPageRoute(builder: (_) => widget.onNavigateToProgress(adventureData, availableIds)));
          } else if (isCompleted) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => widget.onNavigateToMemory(adventureId, adventureData)));
          } else if (isNextStep) {
            _showAdventureDetail(arrayIndex);
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
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amberAccent.shade200.withOpacity(0.5)), boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 2))]),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amberAccent, size: 14),
                    const SizedBox(width: 2),
                    Text(rating.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}