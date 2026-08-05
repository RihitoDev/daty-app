import 'dart:async';
import 'dart:math';
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
    mapHeight = (widget.totalNodes * 155.0) + 350;
    
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
    
    final List<double> possibleSizes = [210.0, 225.0, 235.0, 220.0, 230.0];

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
        if (_adventurePath.isEmpty) return;
        
        int targetIndex = _adventurePath.length - 1;
        if (activeAdventureNumber != null) {
          int activeIdx = _adventurePath.indexOf(activeAdventureNumber!);
          if (activeIdx != -1) targetIndex = activeIdx;
        }

        targetIndex = targetIndex.clamp(0, widget.totalNodes - 1);

        final double mapWidth = MediaQuery.of(context).size.width;
        final pathPoints = _generatePathPoints(mapWidth);
        
        if (targetIndex >= pathPoints.length) return;

        double targetNodeY = pathPoints[targetIndex].dy;
        double viewportHeight = MediaQuery.of(context).size.height;
        
        double targetScrollOffset = targetNodeY - (viewportHeight / 2);
        
        double maxScroll = _scrollController.position.maxScrollExtent;
        double minScroll = _scrollController.position.minScrollExtent;
        targetScrollOffset = targetScrollOffset.clamp(minScroll, maxScroll);
        
        _scrollController.animateTo(
          targetScrollOffset, 
          duration: const Duration(milliseconds: 900), 
          curve: Curves.easeOutCubic,
        );
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
      }
    } catch (e) {
      debugPrint('Error fetching ratings: $e');
    } finally {
      _isFetchingRatings = false;
    }
  }

  List<Offset> _generatePathPoints(double mapWidth) {
    List<Offset> points = [];
    double startY = mapHeight - 140;
    
    double waveFreq = 1.20 / 110.0;
    double amp = mapWidth * 0.33;
    double centerX = mapWidth * 0.50;

    Offset currentPos = Offset(centerX + amp * sin(0), startY);
    points.add(currentPos);

    const double targetDistance = 155.0; 
    const double yStep = 1.0; 
    double currentY = startY;

    for (int i = 1; i < widget.totalNodes; i++) {
      double accumulatedDist = 0.0;
      while (accumulatedDist < targetDistance && currentY > 50) {
        currentY -= yStep;
        double t = startY - currentY;
        double nextX = centerX + amp * sin(t * waveFreq);
        Offset nextPos = Offset(nextX, currentY);
        accumulatedDist += (nextPos - currentPos).distance;
        currentPos = nextPos;
      }
      points.add(currentPos);
    }
    return points;
  }

  List<Offset> _generateDecorationPoints(List<Offset> pathPoints, double mapWidth) {
    List<Offset> points = [];
    double startY = mapHeight - 140;
    double waveFreq = 1.20 / 110.0;

    int k = 0;
    while (true) {
      double t = ((0.5 + k) * pi) / waveFreq;
      double decoY = startY - t;
      if (decoY < 150) break;
      
      double decoX = (k % 2 == 0) ? mapWidth * 0.16 : mapWidth * 0.84;
      points.add(Offset(decoX, decoY));
      k++;
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: widget.themeColor.withOpacity(0.4), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.lightbulb_outline_rounded, color: widget.themeColor, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Consejos para tu Cita',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      adventure['title'] ?? 'Cita Especial',
                      style: TextStyle(
                        color: widget.themeColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      adventure['tips'] != null && (adventure['tips'] as String).isNotEmpty
                          ? adventure['tips']
                          : 'Prepárense para disfrutar un momento único juntos. Mantengan la mente abierta y diviértanse al máximo.',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 4,
                      ),
                      onPressed: () async {
                        Navigator.pop(dialogContext);
                        final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
                        bool success = await MapDataService.setAdventureStatus(
                          mode: widget.mode,
                          myUid: myUid,
                          coupleDocId: _coupleDocId,
                          adventureNumber: adventure['number'],
                          isActive: true,
                        ); 
                        if (success && mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => widget.onNavigateToProgress(adventure, availableIds)));
                        } else if (mounted) {
                          CustomSnackBar.showError(context, 'Error de conexión al iniciar.');
                        }
                      },
                      child: const Text(
                        'Entendido, ¡Comenzar!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
    double fogBottom;
    if (_adventurePath.isEmpty) {
      fogBottom = 0; 
    } else {
      int safeIdx = (_adventurePath.length - 1).clamp(0, pathPoints.length - 1);
      double fogTopY = pathPoints[safeIdx].dy - 100; 
      fogBottom = (mapHeight - (fogTopY + 50)).clamp(0.0, mapHeight); 
    }

    final List<Color> bgGradient = widget.mode == 'solo' 
        ? [const Color(0xFF050A18), const Color(0xFF0B1A3E), const Color(0xFF0F2744)]
        : [const Color(0xFF1A0515), const Color(0xFF3B0A30), const Color(0xFF2A0D3F)];

    final Color neonPathColor = widget.mode == 'solo' ? const Color(0xFF00E5FF) : const Color(0xFFFF4081);
    final int percentVal = (mapProgress * 100).clamp(0, 100).toInt();

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
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            right: 12,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: widget.themeColor.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.themeColor.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55), 
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: widget.themeColor.withOpacity(0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: widget.themeColor.withOpacity(0.15),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.headerTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: widget.themeColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: widget.themeColor.withOpacity(0.5),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '$percentVal%',
                                    style: TextStyle(
                                      color: widget.themeColor,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: mapProgress),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, animValue, child) {
                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final double totalWidth = constraints.maxWidth;
                                    final double currentWidth = totalWidth * animValue.clamp(0.0, 1.0);
                                    return Container(
                                      height: 10,
                                      width: totalWidth,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Stack(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(milliseconds: 300),
                                            width: currentWidth,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              gradient: LinearGradient(
                                                colors: [
                                                  widget.themeColor.withOpacity(0.8),
                                                  widget.themeColor,
                                                  Colors.white.withOpacity(0.9),
                                                ],
                                                stops: const [0.0, 0.7, 1.0],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: widget.themeColor.withOpacity(0.7),
                                                  blurRadius: 8,
                                                  spreadRadius: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
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

    bool isUser1 = _partnerId != null && myUid.compareTo(_partnerId!) < 0;
    
    bool iReviewed = false;
    bool partnerReviewed = false;
    bool isWaitingForPartner = false;

    if (widget.mode == 'couple' && isInProgress) {
      iReviewed = isUser1 ? _reviewCompletedUser1 : _reviewCompletedUser2;
      partnerReviewed = isUser1 ? _reviewCompletedUser2 : _reviewCompletedUser1;
      isWaitingForPartner = iReviewed && !partnerReviewed;
    }

    bool isCompleted = isUnlocked && !isInProgress && (_adventureRatings.containsKey(adventureId) || (activeAdventureNumber != null && arrayIndex < _adventurePath.indexOf(activeAdventureNumber!)));
    bool isNextStep = isUnlocked && !isCompleted && !isInProgress && !isWaitingForPartner;
    bool isMilestone = displayNumber % 5 == 0;

    Color startColor; Color endColor; Widget iconChild;
    
    if (isWaitingForPartner) {
      startColor = const Color(0xFFFFCA28); endColor = const Color(0xFFFFA000); 
      iconChild = const Icon(Icons.hourglass_top, color: Colors.white, size: 28);
    } else if (isInProgress) {
      startColor = const Color(0xFFFFA000); endColor = const Color(0xFFFF6F00); 
      iconChild = const Icon(Icons.adjust, color: Colors.white, size: 30);
    } else if (isCompleted) { 
      startColor = isMilestone ? const Color(0xFFFFD54F) : const Color(0xFF00E676); 
      endColor = isMilestone ? const Color(0xFFFF8F00) : const Color(0xFF00C853); 
      iconChild = Icon(
        isMilestone ? Icons.emoji_events_rounded : Icons.check_circle,
        color: Colors.white,
        size: isMilestone ? 32 : 28,
      );
    } else if (isNextStep) { 
      startColor = isMilestone ? const Color(0xFFFFB300) : widget.themeColor; 
      endColor = isMilestone ? const Color(0xFFFF6F00) : widget.themeColor.withOpacity(0.8);
      iconChild = Text(
        displayNumber.toString(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: isMilestone ? 22 : 20,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1))],
        ),
      );
    } else { 
      startColor = const Color(0xFF1E1E1E); endColor = const Color(0xFF2A2A2A); 
      iconChild = Icon(
        isMilestone ? Icons.military_tech_rounded : Icons.lock,
        color: isMilestone ? Colors.amber.withOpacity(0.4) : Colors.white38,
        size: isMilestone ? 30 : 24,
      );
    }

    double circleSize = isMilestone ? 68.0 : 58.0;

    Widget nodeCircle = Container(
      width: circleSize,
      height: circleSize, 
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [startColor, endColor], center: Alignment.center, radius: 0.5),
        border: Border.all(
          color: isMilestone ? Colors.amberAccent : Colors.white.withOpacity(0.85),
          width: (isInProgress || isNextStep || isMilestone) ? 3.5 : 2.5,
        ), 
        boxShadow: [
          BoxShadow(
            color: (isMilestone ? Colors.amber : startColor).withOpacity((isInProgress || isNextStep) ? 0.7 : 0.4),
            blurRadius: (isInProgress || isNextStep || isMilestone) ? 14 : 6,
            spreadRadius: 1.5,
            offset: Offset.zero,
          )
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

    double? ratingVal = _adventureRatings[adventureId];

    Widget finalNodeContent = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        nodeCircle,
        if (isCompleted)
          Positioned(
            bottom: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF101828),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMilestone ? const Color(0xFFFFD700) : const Color(0xFF00E676),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    color: isMilestone ? const Color(0xFFFFD700) : const Color(0xFF00E676),
                    size: 13,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    ratingVal != null ? ratingVal.toStringAsFixed(1) : '-',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return Positioned(
      left: x - (circleSize / 2), 
      top: y - (circleSize / 2), 
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
        child: finalNodeContent,
      ),
    );
  }
}
