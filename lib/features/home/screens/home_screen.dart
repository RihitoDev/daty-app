import 'dart:async';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../profile/screens/profile_screen.dart';
import '../../solo/widgets/solo_adventure_card.dart'; 
import '../../couple/widgets/couple_adventure_card.dart';
import '../../group/screens/group_loby.dart';
import '../../settings/screens/settings_screen.dart';
import '../../album/screens/album_screen.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF1E5F5),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          boxShadow: [BoxShadow(color: Colors.black12, spreadRadius: 0, blurRadius: 10)],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF9C27B0),
            unselectedItemColor: Colors.grey,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 30), activeIcon: Icon(Icons.home_rounded, size: 30), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.photo_library_outlined, size: 30), activeIcon: Icon(Icons.photo_library_rounded, size: 30), label: 'Album'),
              BottomNavigationBarItem(icon: Icon(Icons.tune_rounded, size: 30), label: 'Ajustes'),
            ],
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
    '¿Qué plan hay hoy?',
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
    _pageController = PageController(initialPage: _currentPage, viewportFraction: 0.6);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _bubbleTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchRandomAdventures() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('adventures').limit(15).get();
      final adventures = snapshot.docs.map((doc) => doc.data()).toList();
      adventures.shuffle();
      return adventures;
    } catch (e) {
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
    
    final String userName = authProvider.userData?['username'] ?? authProvider.user?.displayName ?? 'Aventurero';
    final String? photoUrl = authProvider.userData?['photoUrl'];
    final String initials = getInitials(userName);

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 30, 
            left: 20, 
            right: 20, 
            bottom: 20
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF9C27B0), Color(0xFF7B1FA2)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Fila principal
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Mascota
                  GestureDetector(
                    onTap: _onMascotTapped,
                    child: Container(
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/images/mascot.png', 
                        height: 45, 
                        errorBuilder: (c, e, s) => const Icon(Icons.pets, color: Colors.white, size: 35)
                      ),
                    ),
                  ),
                  
                  // Saludo centrado en el espacio restante
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Bienvenido,', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w400)),
                        Text(userName, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis, maxLines: 1),
                      ],
                    ),
                  ),
                  
                  // Avatar
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))
                        ]
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundColor: const Color(0xFF81D4FA),
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? CachedNetworkImageProvider(photoUrl) : null,
                        child: (photoUrl == null || photoUrl.isEmpty) 
                          ? Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)) 
                          : null,
                      ),
                    ),
                  ),
                ],
              ),

              if (_showBubble)
                Positioned(
                  left: 30, 
                  bottom: 40, 
                  child: _buildSpeechBubble(_currentPhrase),
                ),
            ],
          ),
        ),
   

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 25.0, left: 25.0, right: 25.0, bottom: 25.0),
            child: Column(
              children: [
                const SoloAdventureCard(),
                const CoupleAdventureCard(),
                
                _buildAdventureCard(
                  title: 'Aventura Grupal', 
                  subtitle: 'Expedicion en grupo', 
                  gradientColors: const [Color(0xFFBA68C8), Color(0xFF8E24AA)],
                  icon: Icons.groups_rounded, 
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroupLobby()))
                ),

                const SizedBox(height: 20),
                
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Conoce estos lugares', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF9C27B0))),
                ),
                const SizedBox(height: 10),
                
                _buildAdventureCarousel(),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeechBubble(String text) {
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
              color: Colors.white,
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
              style: const TextStyle(
                color: Color(0xFF9C27B0), 
                fontWeight: FontWeight.bold, 
                fontSize: 13
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdventureCarousel() {
    return SizedBox(
      height: 220,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _randomAdventuresFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0)));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_off_outlined, color: Colors.grey.shade400, size: 40),
                  const SizedBox(height: 10),
                  Text('No hay aventuras disponibles', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
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
            child: PageView.builder(
              controller: _pageController,
              itemCount: _adventuresCount * 10000,
              onPageChanged: (index) {
                _currentPage = index;
              },
              itemBuilder: (context, index) {
                final realIndex = index % _adventuresCount;
                final adv = adventures[realIndex];
                return _buildCarouselCard(adv);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildCarouselCard(Map<String, dynamic> adventure) {
    final String title = adventure['title'] ?? 'Aventura';
    final String description = adventure['description'] ?? '';
    final int number = adventure['number'] ?? 0;

    return GestureDetector(
      onTap: () => _showDescriptionDialog(title, description),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(2, 4))],
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
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFFCE93D8), Color(0xFF9C27B0)], begin: Alignment.topLeft, end: Alignment.bottomRight),
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
                      bottom: 10, left: 10, right: 10,
                      child: Text(
                        title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, shadows: [Shadow(color: Colors.black, blurRadius: 4)]),
                      ),
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

  void _showDescriptionDialog(String title, String description) {
    _stopAutoScroll();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF9C27B0))),
            const SizedBox(height: 15),
            Text(description, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
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
            child: const Text('Cerrar', style: TextStyle(color: Color(0xFF9C27B0)))
          ),
        ],
      ),
    );
  }

  Widget _buildAdventureCard({required String title, required String subtitle, required List<Color> gradientColors, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20), 
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(colors: gradientColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withValues(alpha: 0.4),
              blurRadius: 15, offset: const Offset(0, 8), spreadRadius: 2
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14), 
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle), 
              child: Icon(icon, size: 40, color: Colors.white)
            ),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))])),
                  const SizedBox(height: 6), 
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 15, fontWeight: FontWeight.w600))
                ]
              )
            ),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 28)
          ],
        ),
      ),
    );
  }
}