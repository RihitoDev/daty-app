import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

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
                  // CAMBIO: Caché aplicado al Avatar del usuario
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

                const SizedBox(height: 10),
                SizedBox(
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(left: 20, child: Transform.rotate(angle: -0.2, child: _buildPolaroidPhoto('https://picsum.photos/200/300?random=1'))),
                      Positioned(right: 20, child: Transform.rotate(angle: 0.2, child: _buildPolaroidPhoto('https://picsum.photos/200/300?random=2'))),
                      Positioned(child: _buildPolaroidPhoto('https://picsum.photos/200/300?random=3')),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
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
          boxShadow: [BoxShadow(color: gradientColors.last.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8), spreadRadius: 2)],
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle), child: Icon(icon, size: 40, color: Colors.white)),
            const SizedBox(width: 25),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, shadows: [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(1, 2))])), const SizedBox(height: 6), Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 15, fontWeight: FontWeight.w600))])),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 28)
          ],
        ),
      ),
    );
  }

  Widget _buildPolaroidPhoto(String imageUrl) {
    return Container(
      width: 100, 
      height: 120, 
      padding: const EdgeInsets.all(5), 
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(10), 
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5, offset: Offset(0, 3))]
      ), 
      child: ClipRRect(
        borderRadius: BorderRadius.circular(5), 
        // CAMBIO: Caché aplicado a fotos decorativas
        child: CachedNetworkImage(
          imageUrl: imageUrl, 
          fit: BoxFit.cover, 
          placeholder: (_, __) => Container(
            color: Colors.grey.shade200, 
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2))
          ),
          errorWidget: (_, __, ___) => Container(
            color: Colors.grey.shade200, 
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey, size: 40)
          ),
        )
      )
    );
  }
}