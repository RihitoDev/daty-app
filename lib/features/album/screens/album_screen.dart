import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/album_memory.dart';
import '../providers/album_provider.dart';
import '../widgets/album_timeline_view.dart';
import '../widgets/memory_card.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  String _selectedCategory = 'TODOS'; // 'TODOS', 'SOLO', 'PAREJA', 'GRUPO'
  String _viewMode = 'grid'; // 'grid' (Pinterest Masonry) o 'timeline' (Línea de Tiempo)

  Stream<List<AlbumMemory>> _getCategoryStream(AlbumProvider provider) {
    switch (_selectedCategory) {
      case 'SOLO':
        return provider.soloStream;
      case 'PAREJA':
        return provider.coupleStream;
      case 'GRUPO':
        return provider.groupStream;
      default:
        return provider.allStream;
    }
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;
    final provider = context.watch<AlbumProvider>();

    return Scaffold(
      backgroundColor: customTheme.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header & Título Limpio
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
              child: Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: customTheme.elevatedSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: customTheme.outline),
                        ),
                        child: Icon(Icons.arrow_back_ios_new,
                            color: customTheme.text, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Text(
                      'Álbum de Recuerdos',
                      style: TextStyle(
                        color: customTheme.text,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  // Conmutador de Vista (Grid / Timeline)
                  Container(
                    decoration: BoxDecoration(
                      color: customTheme.elevatedSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: customTheme.outline),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildViewIconButton(
                          mode: 'grid',
                          icon: Icons.grid_view_rounded,
                          t: customTheme,
                        ),
                        _buildViewIconButton(
                          mode: 'timeline',
                          icon: Icons.view_timeline_rounded,
                          t: customTheme,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. StreamBuilder con Hero Stats & Filtros
            Expanded(
              child: StreamBuilder<List<AlbumMemory>>(
                stream: _getCategoryStream(provider),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: customTheme.primary,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: SelectableText(
                          'Error al cargar recuerdos:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  final memories = snapshot.data ?? [];
                  final totalPhotos = memories.fold<int>(
                      0, (sum, item) => sum + item.photoUrls.length);

                  return Column(
                    children: [
                      // 2a. Tarjeta Hero de Estadísticas Resaltada en Tema
                      if (memories.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: customTheme.softSurface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: customTheme.outline,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: customTheme.shadow,
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  icon: Icons.auto_stories_rounded,
                                  label: 'Aventuras',
                                  value: '${memories.length}',
                                  t: customTheme,
                                ),
                                Container(
                                  height: 24,
                                  width: 1,
                                  color: customTheme.outline,
                                ),
                                _buildStatItem(
                                  icon: Icons.collections_rounded,
                                  label: 'Fotografías',
                                  value: '$totalPhotos',
                                  t: customTheme,
                                ),
                              ],
                            ),
                          ),
                        ),

                      // 2b. Filtros de Cápsula
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildCategoryPill('TODOS', customTheme),
                              const SizedBox(width: 8),
                              _buildCategoryPill('SOLO', customTheme),
                              const SizedBox(width: 8),
                              _buildCategoryPill('PAREJA', customTheme),
                              const SizedBox(width: 8),
                              _buildCategoryPill('GRUPO', customTheme),
                            ],
                          ),
                        ),
                      ),

                      // 2c. Cuerpo (Grid Masonry o Timeline)
                      Expanded(
                        child: memories.isEmpty
                            ? EmptyStateWidget(
                                icon: _getEmptyIcon(_selectedCategory),
                                message: _getEmptyMessage(_selectedCategory),
                              )
                            : (_viewMode == 'timeline'
                                ? AlbumTimelineView(memories: memories)
                                : _buildStaggeredGrid(memories, customTheme)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewIconButton({
    required String mode,
    required IconData icon,
    required AppCustomTheme t,
  }) {
    final isSelected = _viewMode == mode;
    return GestureDetector(
      onTap: () {
        setState(() {
          _viewMode = mode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: isSelected ? t.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isSelected
              ? Colors.white
              : (t.isDark ? Colors.grey.shade400 : t.muted),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required AppCustomTheme t,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: t.primary),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                color: t.text,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: t.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String category, AppCustomTheme t) {
    final isSelected = _selectedCategory == category;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = category;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? t.primary
              : (t.isDark ? const Color(0xFF1E1E24) : t.elevatedSurface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : t.outline.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: t.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          category,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (t.isDark ? Colors.grey.shade400 : t.muted),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildStaggeredGrid(
      List<AlbumMemory> memories, AppCustomTheme t) {
    final leftColumnMemories = <_IndexedMemory>[];
    final rightColumnMemories = <_IndexedMemory>[];

    for (int i = 0; i < memories.length; i++) {
      if (i % 2 == 0) {
        leftColumnMemories.add(_IndexedMemory(index: i, memory: memories[i]));
      } else {
        rightColumnMemories.add(_IndexedMemory(index: i, memory: memories[i]));
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Columna Izquierda
          Expanded(
            child: Column(
              children: leftColumnMemories.map((item) {
                final height = _getDynamicHeight(item.index, true);
                return MemoryCard(
                  memory: item.memory,
                  cardHeight: height,
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 14),
          // Columna Derecha
          Expanded(
            child: Column(
              children: rightColumnMemories.map((item) {
                final height = _getDynamicHeight(item.index, false);
                return MemoryCard(
                  memory: item.memory,
                  cardHeight: height,
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  double _getDynamicHeight(int index, bool isLeft) {
    final heightsLeft = [210.0, 260.0, 225.0];
    final heightsRight = [265.0, 215.0, 250.0];

    if (isLeft) {
      return heightsLeft[(index ~/ 2) % heightsLeft.length];
    } else {
      return heightsRight[(index ~/ 2) % heightsRight.length];
    }
  }

  IconData _getEmptyIcon(String category) => switch (category) {
        'SOLO' => Icons.backpack_outlined,
        'PAREJA' => Icons.favorite_outline,
        'GRUPO' => Icons.groups_outlined,
        _ => Icons.auto_stories,
      };

  String _getEmptyMessage(String category) => switch (category) {
        'SOLO' => 'Aún no tienes aventuras solitarias.\n¡Explora por tu cuenta!',
        'PAREJA' => 'Aún no tienen aventuras juntos.\n¡Planeen una cita!',
        'GRUPO' => 'Aún no hay expediciones grupales.\n¡Arma un grupo!',
        _ => 'Aún no tienes recuerdos guardados.\n¡Completa una aventura!',
      };
}

class _IndexedMemory {
  final int index;
  final AlbumMemory memory;

  _IndexedMemory({required this.index, required this.memory});
}