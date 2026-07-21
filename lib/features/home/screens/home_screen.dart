import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../solo/widgets/solo_adventure_card.dart'; 
import '../../couple/widgets/couple_adventure_card.dart';
import '../../group/screens/group_loby.dart';
import '../../settings/screens/settings_screen.dart';
import '../../album/screens/album_screen.dart';
import '../../../shared/widgets/pressable_scale.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeContent(),
    AlbumScreen(),
    SettingsScreen(), 
  ];

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;

    return Scaffold(
      backgroundColor: customTheme.bg,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 4, 18, 12),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: customTheme.card,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: customTheme.muted.withValues(alpha: 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: customTheme.primary.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildNavigationItem(
                index: 0,
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
                label: 'Inicio',
                customTheme: customTheme,
              ),
              _buildNavigationItem(
                index: 1,
                icon: Icons.auto_stories_outlined,
                activeIcon: Icons.auto_stories_rounded,
                label: 'Álbum',
                customTheme: customTheme,
              ),
              _buildNavigationItem(
                index: 2,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Ajustes',
                customTheme: customTheme,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required AppCustomTheme customTheme,
  }) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: Semantics(
        selected: isSelected,
        button: true,
        label: label,
        child: InkWell(
          onTap: () => setState(() => _currentIndex = index),
          borderRadius: BorderRadius.circular(19),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected
                  ? customTheme.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(19),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.08 : 1,
                  duration: const Duration(milliseconds: 240),
                  child: Icon(
                    isSelected ? activeIcon : icon,
                    size: 24,
                    color: isSelected
                        ? customTheme.primary
                        : customTheme.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? customTheme.primary
                        : customTheme.text2,
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  late Future<List<Map<String, dynamic>>> _randomAdventuresFuture;
  late PageController _pageController;
  Timer? _autoScrollTimer;
  int _currentPage = 1000; 
  int _adventuresCount = 0;

  bool _showBubble = false;
  String _currentPhrase = '';
  Timer? _bubbleTimer;

  final List<String> _mascotPhrases = [
    '¡Vive una aventura!',
    '¿Felices por siempre?',
    '¿Qué vas a hacer hoy?',
    '¡Explora el mundo!',
    '¿Listo para la acción?',
    'El mapa te espera...',
    '¡A romper la rutina!',
    '¿Te animas a salir?',
    '¡Crea un recuerdo hoy!',
    '¡Arriesgate a vivir!'
  ];

  @override
  void initState() {
    super.initState();
    _randomAdventuresFuture = _fetchRandomAdventures();
    _pageController = PageController(initialPage: _currentPage, viewportFraction: 0.84);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _bubbleTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  bool _fetchFailed = false;

  Future<List<Map<String, dynamic>>> _fetchRandomAdventures() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('adventures').limit(15).get();
      final adventures = snapshot.docs.map((doc) => doc.data()).toList();
      adventures.shuffle();
      _fetchFailed = false;
      return adventures;
    } catch (e) {
      _fetchFailed = true;
      debugPrint('Error cargando aventuras del carrusel: $e');
      return [];
    }
  }

  void _startAutoScroll() {
    _stopAutoScroll(); 
    if (_adventuresCount == 0) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients) {
        _currentPage++;
        _pageController.animateToPage(
          _currentPage, 
          duration: const Duration(milliseconds: 800), 
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = null;
  }

  String getInitials(String? name) {
    if (name == null || name.isEmpty) return 'AE';
    List<String> parts = name.split(' ');
    if (parts.length > 1) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, name.length >= 2 ? 2 : 1).toUpperCase();
  }

  void _onMascotTapped() {
    final random = Random();
    _bubbleTimer?.cancel();

    setState(() {
      _currentPhrase = _mascotPhrases[random.nextInt(_mascotPhrases.length)];
      _showBubble = true;
    });

    _bubbleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showBubble = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    
    final String userName = authProvider.userData?['username'] ?? authProvider.user?.displayName ?? 'Aventurero';
    final String? photoUrl = authProvider.userData?['photoUrl'];
    final String initials = getInitials(userName);

    return Stack(
      children: [
        ColoredBox(color: customTheme.bg),
        _buildBackgroundDecorations(customTheme),
        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(customTheme, userName, photoUrl, initials),
                const SizedBox(height: 30),
                Text('Elige tu aventura', style: TextStyle(color: customTheme.text, fontSize: 24, fontWeight: FontWeight.w900, height: 1.12)),
                const SizedBox(height: 7),
                Text('Tres formas de salir de la rutina.', style: TextStyle(color: customTheme.text2, fontSize: 14, height: 1.4)),
                const SizedBox(height: 22),
                const SoloAdventureCard(),
                const CoupleAdventureCard(),
                _buildAdventureCard(
                  customTheme: customTheme,
                  title: 'Aventura grupal',
                  subtitle: 'Una expedición para compartir',
                  icon: Icons.groups_rounded,
                  accent: const Color(0xFF8E24AA),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupLobby())),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: Text('Inspírate', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: customTheme.text))),
                    Text('Conoce estos lugares', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: customTheme.text2)),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAdventureCarousel(customTheme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AppCustomTheme customTheme, String userName, String? photoUrl, String initials) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [customTheme.primary, customTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [BoxShadow(color: customTheme.primary.withValues(alpha: 0.28), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(right: -36, bottom: -50, child: _decorativeCircle(125, Colors.white.withValues(alpha: 0.08))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
                GestureDetector(
                  onTap: _onMascotTapped,
                  child: Container(
                    width: 58,
                    height: 58,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(18)),
                    child: Image.asset('assets/images/mascot.png', fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TU PRÓXIMA HISTORIA', style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(height: 2),
                  Text('Hola, $userName', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                ])),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2)),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? CachedNetworkImageProvider(photoUrl) : null,
                      child: photoUrl == null || photoUrl.isEmpty ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)) : null,
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Hoy puede convertirse en un gran recuerdo.', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
          ]),
          if (_showBubble) Positioned(left: 42, top: 50, child: _buildSpeechBubble(_currentPhrase, customTheme)),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations(AppCustomTheme customTheme) => IgnorePointer(
    child: Stack(children: [
      Positioned(top: 270, right: -45, child: _decorativeCircle(145, customTheme.primary.withValues(alpha: 0.06))),
      Positioned(top: 620, left: -55, child: _decorativeCircle(125, customTheme.accent.withValues(alpha: 0.06))),
    ]),
  );

  Widget _decorativeCircle(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _buildSpeechBubble(String text, AppCustomTheme customTheme) {
    return AnimatedOpacity(
      opacity: _showBubble ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: AnimatedScale(
        scale: _showBubble ? 1.0 : 0.5,
        curve: Curves.elasticOut, 
        duration: const Duration(milliseconds: 400),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.55), // Limitamos al 55% para que no se haga demasiado ancho
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: customTheme.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: customTheme.primary,
                fontWeight: FontWeight.bold, 
                fontSize: 13
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdventureCarousel(AppCustomTheme customTheme) {
    return SizedBox(
      height: 248,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _randomAdventuresFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildCarouselLoading(customTheme);
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_off_outlined, color: customTheme.muted, size: 40),
                  const SizedBox(height: 10),
                  Text(
                    _fetchFailed ? 'Error al cargar aventuras' : 'No hay aventuras disponibles', 
                    style: TextStyle(color: customTheme.text2, fontWeight: FontWeight.w600)
                  ),
                  if (_fetchFailed) ...[
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _randomAdventuresFuture = _fetchRandomAdventures();
                        });
                      },
                      child: Text('Reintentar', style: TextStyle(color: customTheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              )
            );
          }

          final adventures = snapshot.data!;
          _adventuresCount = adventures.length;
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_autoScrollTimer == null || !_autoScrollTimer!.isActive) {
              _startAutoScroll();
            }
          });

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification && notification.dragDetails != null) {
                _stopAutoScroll();
              } else if (notification is ScrollEndNotification) {
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) _startAutoScroll();
                });
              }
              return false;
            },
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _adventuresCount * 10000,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final realIndex = index % _adventuresCount;
                      final adv = adventures[realIndex];
                      return _buildCarouselCard(adv, customTheme);
                    },
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      adventures.length > 5 ? 5 : adventures.length,
                      (index) {
                        final visibleCount = adventures.length > 5 ? 5 : adventures.length;
                        final activeIndex = (_currentPage % adventures.length) % visibleCount;
                        final isActive = activeIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: isActive ? 18 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isActive ? customTheme.primary : customTheme.muted.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarouselLoading(AppCustomTheme customTheme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 5, 48, 25),
      decoration: BoxDecoration(
        color: customTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: customTheme.muted.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: customTheme.primaryLight.withValues(alpha: 0.35),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Container(
              width: 150,
              height: 12,
              decoration: BoxDecoration(
                color: customTheme.muted.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselCard(Map<String, dynamic> adventure, AppCustomTheme customTheme) {
    final String title = adventure['title'] ?? 'Aventura';
    final String description = adventure['description'] ?? '';
    final int number = adventure['number'] ?? 0;

    return PressableScale(
      onTap: () => _showDescriptionDialog(title, description, customTheme),
      semanticsLabel: 'Ver aventura: $title',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: customTheme.card,
          border: Border.all(color: customTheme.muted.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: customTheme.primary.withValues(alpha: 0.1), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/adventures/$number.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [customTheme.primaryLight, customTheme.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          ),
                          child: const Center(child: Icon(Icons.photo_camera_back_outlined, color: Colors.white30, size: 50)),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        height: 80,
                        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])),
                      ),
                    ),
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.42), borderRadius: BorderRadius.circular(20)),
                        child: const Text('IDEA PARA HOY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 9, letterSpacing: 0.8)),
                      ),
                    ),
                    Positioned(
                      bottom: 14, left: 14, right: 14,
                      child: Row(children: [
                        Expanded(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, shadows: [Shadow(color: Colors.black, blurRadius: 4)]))),
                        const SizedBox(width: 8),
                        Container(padding: const EdgeInsets.all(7), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Icon(Icons.arrow_outward_rounded, color: customTheme.primary, size: 17)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDescriptionDialog(String title, String description, AppCustomTheme customTheme) {
    _stopAutoScroll();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: customTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: customTheme.text)),
            const SizedBox(height: 15),
            Text(description, textAlign: TextAlign.center, style: TextStyle(color: customTheme.text2, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) _startAutoScroll();
              });
            }, 
            child: Text('Cerrar', style: TextStyle(color: customTheme.primary))
          ),
        ],
      ),
    );
  }

  Widget _buildAdventureCard({required AppCustomTheme customTheme, required String title, required String subtitle, required IconData icon, required Color accent, required VoidCallback onTap}) {
    return PressableScale(
      onTap: onTap,
      semanticsLabel: title,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.27), accent.withValues(alpha: 0.13), customTheme.card],
            stops: const [0, 0.7, 1],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.1),
              blurRadius: 18, offset: const Offset(0, 7),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14), 
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(18)),
              child: Icon(icon, size: 30, color: accent)
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: TextStyle(color: customTheme.text, fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6), 
                  Text(subtitle, style: TextStyle(color: customTheme.text2, fontSize: 13, fontWeight: FontWeight.w600))
                ]
              )
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: accent, size: 18)
          ],
        ),
      ),
    );
  }
}
