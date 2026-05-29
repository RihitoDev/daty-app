import 'dart:async';
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
  // NUEVO: Empezamos en un número alto para que el carrusel sea infinito en ambas direcciones
  int _currentPage = 1000; 

  @override
  void initState() {
    super.initState();
    _randomAdventuresFuture = _fetchRandomAdventures();
    _pageController = PageController(initialPage: _currentPage, viewportFraction: 0.6);
  }

  @override
  void dispose() {
    _stopAutoScroll();
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
      debugPrint('Error cargando aventuras random: $e');
      return [];
    }
  }

  void _startAutoScroll(int itemCount) {
    _stopAutoScroll(); // Limpiamos cualquier timer anterior
    
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && itemCount > 0) {
        _currentPage++; // Siempre avanzamos, nunca volvemos atrás
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    final String userName = authProvider.userData?['username'] ?? authProvider.user?.displayName ?? 'Aventurero';
    final String? photoUrl = authProvider.userData?['photoUrl'];
    final String initials = getInitials(userName);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF9C27B0), Color(0xFFCE93D8), Color(0xFFF1E5F5)], stops: [0.0, 0.7, 1.0]),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset('assets/images/mascot.png', height: 60, errorBuilder: (context, error, stackTrace) => const Icon(Icons.pets, color: Colors.white, size: 50)),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                child: CircleAvatar(
                  radius: 25, 
                  backgroundColor: const Color(0xFF81D4FA),
                  child: photoUrl != null && photoUrl.isNotEmpty
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: photoUrl, 
                          fit: BoxFit.cover, 
                          width: 50, 
                          height: 50, 
                          placeholder: (_, __) => Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                          errorWidget: (_, __, ___) => Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                        )
                      )
                    : Text(initials, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20))
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25.0),
            child: Column(
              children: [
                const Text('Bienvenido!', style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Color(0xFF729BFF), letterSpacing: 1.2)),
                Text('Hola, $userName', style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 30),
                
                const SoloAdventureCard(),
                const CoupleAdventureCard(),
                
                _buildAdventureCard(
                  title: 'Aventura Grupal', 
                  subtitle: 'Expedición en grupo', 
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
            return const Center(child: Text('No hay aventuras disponibles'));
          }

          final adventures = snapshot.data!;
          
          // Iniciar el auto-scroll cuando los datos estén listos
          _startAutoScroll(adventures.length);

          // NUEVO: NotificationListener para detectar cuándo el usuario toca el carrusel
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Si el usuario empieza a arrastrar con el dedo
              if (notification is ScrollStartNotification && notification.dragDetails != null) {
                _stopAutoScroll();
              } 
              // Si el usuario suelta el dedo (termina el arrastre)
              else if (notification is ScrollEndNotification) {
                // Esperamos 3 segundos de inactividad antes de reanudar el auto-scroll
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) {
                    _startAutoScroll(adventures.length);
                  }
                });
              }
              return false; // Permite que el scroll siga su curso normal
            },
            child: PageView.builder(
              controller: _pageController,
              // Un número muy alto para simular bucle infinito en ambas direcciones
              itemCount: adventures.length * 10000, 
              onPageChanged: (index) {
                _currentPage = index; // Actualizamos la posición actual
              },
              itemBuilder: (context, index) {
                final realIndex = index % adventures.length;
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
                            gradient: LinearGradient(
                              colors: [Color(0xFFCE93D8), Color(0xFF9C27B0)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.photo_camera_back_outlined, color: Colors.white30, size: 50),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 80,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black54],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      right: 10,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 14,
                          shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                        ),
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
    _stopAutoScroll(); // Detenemos el auto-scroll al abrir el diálogo
    
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
              // Reanudamos el auto-scroll al cerrar el diálogo
              _fetchRandomAdventures().then((adventures) {
                if (mounted && adventures.isNotEmpty) {
                  _startAutoScroll(adventures.length);
                }
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
              color: gradientColors.last.withOpacity(0.4),
              blurRadius: 15, 
              offset: const Offset(0, 8), 
              spreadRadius: 2
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14), 
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle
              ), 
              child: Icon(icon, size: 40, color: Colors.white)
            ),
            const SizedBox(width: 25),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, 
                children: [
                  Text(
                    title, 
                    style: const TextStyle(
                      color: Colors.white, 
                      fontSize: 21, 
                      fontWeight: FontWeight.w800, 
                      shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))]
                    )
                  ),
                  const SizedBox(height: 6), 
                  Text(
                    subtitle, 
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 15, 
                      fontWeight: FontWeight.w600
                    )
                  )
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
