import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/album_memory.dart';
import '../providers/album_provider.dart';
import '../widgets/memory_card.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  String _selectedCategory = 'TODOS'; // 'TODOS', 'SOLO', 'PAREJA', 'GRUPO'

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
            // 1. Header & Título
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
                  Text(
                    'Álbum de Recuerdos',
                    style: TextStyle(
                      color: customTheme.text,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Filtros estilo Pill / Cápsula (TODOS, SOLO, PAREJA, GRUPO)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildCategoryPill('TODOS', customTheme),
                    const SizedBox(width: 10),
                    _buildCategoryPill('SOLO', customTheme),
                    const SizedBox(width: 10),
                    _buildCategoryPill('PAREJA', customTheme),
                    const SizedBox(width: 10),
                    _buildCategoryPill('GRUPO', customTheme),
                  ],
                ),
              ),
            ),

            // 3. Grid Escalonado 2-Columnas Estilo Instagram / Pinterest
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
                  if (memories.isEmpty) {
                    return EmptyStateWidget(
                      icon: _getEmptyIcon(_selectedCategory),
                      message: _getEmptyMessage(_selectedCategory),
                    );
                  }

                  return _buildStaggeredGrid(memories, customTheme);
                },
              ),
            ),
          ],
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (t.isDark ? const Color(0xFFA855F7) : t.primary)
              : (t.isDark ? const Color(0xFF222228) : t.elevatedSurface),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : t.outline.withValues(alpha: 0.8),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (t.isDark ? const Color(0xFFA855F7) : t.primary)
                        .withValues(alpha: 0.35),
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
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            letterSpacing: 0.6,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
          const SizedBox(width: 12),
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
    final heightsLeft = [200.0, 260.0, 220.0];
    final heightsRight = [270.0, 210.0, 250.0];

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