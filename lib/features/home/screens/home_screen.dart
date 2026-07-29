import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../couple/providers/couple_provider.dart';
import '../../couple/providers/pair_link_provider.dart';
import '../../couple/widgets/contract_dialog.dart';
import '../../couple/widgets/pairing_dialog.dart';
import '../../profile/screens/profile_screen.dart';
import '../../solo/widgets/solo_adventure_card.dart';
import '../../couple/widgets/couple_adventure_card.dart';
import '../../group/screens/group_loby.dart';
import '../../settings/screens/settings_screen.dart';
import '../../album/screens/album_screen.dart';
import '../../calendar/screens/calendar_screen.dart';
import '../../../shared/widgets/adventure_action_card.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  PairLinkProvider? _pairLinkProvider;
  bool _isHandlingPairLink = false;

  final List<Widget> _screens = const [
    HomeContent(),
    AlbumScreen(),
    SettingsScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<PairLinkProvider>();
    if (identical(provider, _pairLinkProvider)) return;

    _pairLinkProvider?.removeListener(_onPairLinkChanged);
    _pairLinkProvider = provider..addListener(_onPairLinkChanged);
    _onPairLinkChanged();
  }

  void _onPairLinkChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handlePendingPairLink();
    });
  }

  Future<void> _handlePendingPairLink() async {
    if (_isHandlingPairLink) return;

    final code = _pairLinkProvider?.pendingCode;
    if (code == null) return;

    _isHandlingPairLink = true;
    _pairLinkProvider?.consumePendingCode();

    final coupleProvider = context.read<CoupleProvider>();
    if (coupleProvider.hasPartner) {
      CustomSnackBar.showInfo(
        context,
        'Ya estás vinculado con ${coupleProvider.partnerName}.',
      );
      _isHandlingPairLink = false;
      return;
    }

    final linked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PairingDialog(initialCode: code),
    );

    if (!mounted) return;

    if (linked == true) {
      await _openContractWhenReady();
    }

    _isHandlingPairLink = false;
    if (_pairLinkProvider?.pendingCode != null) {
      _onPairLinkChanged();
    }
  }

  Future<void> _openContractWhenReady() async {
    for (var attempt = 0; attempt < 20; attempt += 1) {
      if (!mounted) return;

      final coupleProvider = context.read<CoupleProvider>();
      if (coupleProvider.hasPartner &&
          !coupleProvider.isLoading &&
          coupleProvider.coupleData != null &&
          !coupleProvider.iSigned) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => ContractDialog(
            myUid: coupleProvider.myUid,
            partnerUid: coupleProvider.partnerId!,
            coupleDocId: coupleProvider.coupleDocId!,
          ),
        );
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (mounted) {
      CustomSnackBar.showInfo(
        context,
        'La vinculación está lista. Abre Aventura en pareja para firmar.',
      );
    }
  }

  @override
  void dispose() {
    _pairLinkProvider?.removeListener(_onPairLinkChanged);
    super.dispose();
  }

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
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Container(
          height: 66,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: customTheme.elevatedSurface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: customTheme.outline,
            ),
            boxShadow: [
              BoxShadow(
                color: customTheme.shadow,
                blurRadius: customTheme.isDark ? 28 : 24,
                offset: const Offset(0, 8),
              ),
              if (customTheme.isDark)
                BoxShadow(
                  color: customTheme.primary.withValues(alpha: 0.08),
                  blurRadius: 24,
                  spreadRadius: -5,
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
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        customTheme.primary.withValues(alpha: 0.2),
                        customTheme.primary.withValues(alpha: 0.08),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(19),
              border: isSelected && customTheme.isDark
                  ? Border.all(
                      color: customTheme.primary.withValues(alpha: 0.18),
                    )
                  : null,
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
                    color: isSelected ? customTheme.primary : customTheme.muted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? customTheme.primary : customTheme.text2,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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

  @override
  void initState() {
    super.initState();
    _randomAdventuresFuture = _fetchRandomAdventures();
    _pageController =
        PageController(initialPage: _currentPage, viewportFraction: 0.84);
  }

  @override
  void dispose() {
    _stopAutoScroll();
    _pageController.dispose();
    super.dispose();
  }

  bool _fetchFailed = false;

  Future<List<Map<String, dynamic>>> _fetchRandomAdventures() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('adventures')
          .limit(15)
          .get();
      final adventures = snapshot.docs.map((doc) => doc.data()).toList();
      adventures.shuffle();
      _fetchFailed = false;
      _adventuresCount = adventures.length;
      if (_adventuresCount > 0) {
        _currentPage = _adventuresCount * 500;
        _startAutoScroll();
      }
      return adventures;
    } catch (e) {
      _fetchFailed = true;
      debugPrint('Error cargando aventuras del carrusel: $e');
      return [];
    }
  }

  void _startAutoScroll() {
    _stopAutoScroll();
    if (_adventuresCount <= 1) return;

    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_pageController.hasClients && mounted) {
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final customTheme = context.watch<ThemeProvider>().currentTheme;

    final String userName = authProvider.userData?['username'] ??
        authProvider.user?.displayName ??
        'Aventurero';
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
                Text('Elige tu aventura',
                    style: TextStyle(
                        color: customTheme.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.12)),
                const SizedBox(height: 7),
                Text('Tres formas de salir de la rutina.',
                    style: TextStyle(
                        color: customTheme.text2, fontSize: 14, height: 1.4)),
                const SizedBox(height: 22),
                const SoloAdventureCard(),
                const CoupleAdventureCard(),
                _buildAdventureCard(
                  customTheme: customTheme,
                  title: 'Aventura grupal',
                  subtitle: 'Una expedición para compartir',
                  icon: Icons.groups_rounded,
                  accent: const Color(0xFF8E24AA),
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const GroupLobby())),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: Text('Inspírate',
                            style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                color: customTheme.text))),
                    Text('Conoce estos lugares',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: customTheme.text2)),
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

  Widget _buildHeader(AppCustomTheme customTheme, String userName,
      String? photoUrl, String initials) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [customTheme.primary, customTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
              color: customTheme.primary.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 12))
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
              right: -36,
              bottom: -50,
              child:
                  _decorativeCircle(125, Colors.white.withValues(alpha: 0.08))),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              PressableScale(
                scale: 0.92,
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CalendarScreen())),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.28),
                          Colors.white.withValues(alpha: 0.10),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('TU PRÓXIMA HISTORIA',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text('Hola, $userName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ])),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen())),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.75),
                          width: 2)),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? CachedNetworkImageProvider(photoUrl)
                        : null,
                    onBackgroundImageError: photoUrl != null && photoUrl.isNotEmpty
                        ? (exception, stackTrace) {
                            debugPrint('Fallo al cargar avatar: $exception');
                          }
                        : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? Text(initials,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800))
                        : null,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 18),
            Row(children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                  child: Text('Hoy puede convertirse en un gran recuerdo.',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w600))),
            ]),
          ]),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations(AppCustomTheme customTheme) =>
      IgnorePointer(
        child: Stack(children: [
          Positioned(
              top: 270,
              right: -45,
              child: _decorativeCircle(
                  145, customTheme.primary.withValues(alpha: 0.06))),
          Positioned(
              top: 620,
              left: -55,
              child: _decorativeCircle(
                  125, customTheme.accent.withValues(alpha: 0.06))),
        ]),
      );

  Widget _decorativeCircle(double size, Color color) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color));

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
                Icon(Icons.explore_off_outlined,
                    color: customTheme.muted, size: 40),
                const SizedBox(height: 10),
                Text(
                    _fetchFailed
                        ? 'Error al cargar aventuras'
                        : 'No hay aventuras disponibles',
                    style: TextStyle(
                        color: customTheme.text2, fontWeight: FontWeight.w600)),
                if (_fetchFailed) ...[
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _randomAdventuresFuture = _fetchRandomAdventures();
                      });
                    },
                    child: Text('Reintentar',
                        style: TextStyle(
                            color: customTheme.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ],
            ));
          }

          final adventures = snapshot.data!;
          _adventuresCount = adventures.length;

          final visibleCount =
              adventures.length > 5 ? 5 : adventures.length;
          final realIndex = _currentPage % adventures.length;
          final activeDotIndex = realIndex % visibleCount;

          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification &&
                  notification.dragDetails != null) {
                _stopAutoScroll();
              } else if (notification is ScrollEndNotification) {
                _stopAutoScroll();
                Future.delayed(const Duration(seconds: 4), () {
                  if (mounted && _autoScrollTimer == null) {
                    _startAutoScroll();
                  }
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
                      final itemIndex = index % _adventuresCount;
                      final adv = adventures[itemIndex];
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
                      visibleCount,
                      (index) {
                        final isActive = activeDotIndex == index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: isActive ? 18 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: isActive
                                ? customTheme.primary
                                : customTheme.muted.withValues(alpha: 0.35),
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
      clipBehavior: Clip.antiAlias,
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
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

  Widget _buildCarouselCard(
      Map<String, dynamic> adventure, AppCustomTheme customTheme) {
    final String title = adventure['title'] ?? 'Aventura';
    final String description = adventure['description'] ?? '';
    final int number = adventure['number'] ?? 0;

    return PressableScale(
      onTap: () => _showDescriptionDialog(title, description, customTheme),
      semanticsLabel: 'Ver aventura: $title',
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: customTheme.elevatedSurface,
          border: Border.all(
            color: customTheme.isDark
                ? customTheme.primary.withValues(alpha: 0.22)
                : customTheme.outline,
          ),
          boxShadow: [
            BoxShadow(
              color: customTheme.shadow,
              blurRadius: customTheme.isDark ? 22 : 16,
              offset: const Offset(0, 7),
            ),
            if (customTheme.isDark)
              BoxShadow(
                color: customTheme.primary.withValues(alpha: 0.07),
                blurRadius: 20,
                spreadRadius: -5,
              ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/adventures/$number.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [
                                  customTheme.primaryLight,
                                  customTheme.primary
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight),
                          ),
                          child: const Center(
                              child: Icon(Icons.photo_camera_back_outlined,
                                  color: Colors.white30, size: 50)),
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
                                colors: [Colors.transparent, Colors.black54])),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('IDEA PARA HOY',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                                letterSpacing: 0.8)),
                      ),
                    ),
                    Positioned(
                      bottom: 14,
                      left: 14,
                      right: 14,
                      child: Row(children: [
                        Expanded(
                            child: Text(title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 17,
                                    shadows: [
                                      Shadow(color: Colors.black, blurRadius: 4)
                                    ]))),
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.all(7),
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                            child: Icon(Icons.arrow_outward_rounded,
                                color: customTheme.primary, size: 17)),
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

  void _showDescriptionDialog(
      String title, String description, AppCustomTheme customTheme) {
    _stopAutoScroll();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: customTheme.card,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: customTheme.text)),
            const SizedBox(height: 15),
            Text(description,
                textAlign: TextAlign.center,
                style: TextStyle(color: customTheme.text2, fontSize: 14)),
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
              child:
                  Text('Cerrar', style: TextStyle(color: customTheme.primary))),
        ],
      ),
    );
  }

  Widget _buildAdventureCard(
      {required AppCustomTheme customTheme,
      required String title,
      required String subtitle,
      required IconData icon,
      required Color accent,
      required VoidCallback onTap}) {
    return AdventureActionCard(
      theme: customTheme,
      title: title,
      subtitle: subtitle,
      icon: icon,
      accent: accent,
      onTap: onTap,
    );
  }
}
