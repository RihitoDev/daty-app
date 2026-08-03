import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/album_memory.dart';
import '../providers/album_provider.dart';
import '../widgets/album_timeline_view.dart';
import '../widgets/memory_card.dart';
import '../widgets/personal_vault_login_dialog.dart';
import '../widgets/personal_vault_setup_dialog.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  String _selectedCategory = 'TODOS'; // 'TODOS', 'SOLO', 'PAREJA', 'GRUPO', 'PERSONAL'
  String _viewMode = 'grid'; // 'grid' (Pinterest Masonry) o 'timeline' (Línea de Tiempo)
  bool _isPersonalUnlocked = false;

  Stream<List<AlbumMemory>> _getCategoryStream(AlbumProvider provider) {
    switch (_selectedCategory) {
      case 'SOLO':
        return provider.soloStream;
      case 'PAREJA':
        return provider.coupleStream;
      case 'GRUPO':
        return provider.groupStream;
      case 'PERSONAL':
        return provider.personalStream;
      default:
        return provider.allStream;
    }
  }

  Future<void> _handlePersonalCategoryTap(AppCustomTheme customTheme) async {
    if (_isPersonalUnlocked) {
      setState(() {
        _selectedCategory = 'PERSONAL';
      });
      return;
    }

    final myUid = Provider.of<AuthProvider>(context, listen: false).user?.uid;
    if (myUid == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();
      final pin = doc.data()?['personalVaultPin'] as String?;

      if (!mounted) return;

      if (pin == null || pin.isEmpty) {
        // Primera vez: configurar PIN y preguntas
        final setupSuccess = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const PersonalVaultSetupDialog(),
        );

        if (setupSuccess == true && mounted) {
          setState(() {
            _isPersonalUnlocked = true;
            _selectedCategory = 'PERSONAL';
          });
        }
      } else {
        // Ingreso con PIN
        final loginSuccess = await showDialog<bool>(
          context: context,
          builder: (ctx) => PersonalVaultLoginDialog(correctPin: pin),
        );

        if (loginSuccess == true && mounted) {
          setState(() {
            _isPersonalUnlocked = true;
            _selectedCategory = 'PERSONAL';
          });
        }
      }
    } catch (e) {
      debugPrint('Error al acceder al baúl PERSONAL: $e');
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
                      0, (acc, item) => acc + item.photoUrls.length);

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

                      // 2b. Filtros de Cápsula (incluyendo PERSONAL 🔒)
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
                              const SizedBox(width: 8),
                              _buildCategoryPill('PERSONAL', customTheme),
                            ],
                          ),
                        ),
                      ),

                      // 2c. Cuerpo (Grid Masonry o Timeline + Acordeón Desplegable para ex-pareja)
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              if (memories.isEmpty)
                                EmptyStateWidget(
                                  icon: _getEmptyIcon(_selectedCategory),
                                  message: _getEmptyMessage(_selectedCategory),
                                )
                              else
                                (_viewMode == 'timeline'
                                    ? AlbumTimelineView(memories: memories)
                                    : _buildStaggeredGrid(memories, customTheme)),

                              if (_selectedCategory == 'PAREJA')
                                StreamBuilder<List<PausedCoupleGroup>>(
                                  stream: provider.pausedCoupleGroupsStream,
                                  builder: (context, pausedSnap) {
                                    final groups = pausedSnap.data ?? [];
                                    if (groups.isEmpty) return const SizedBox.shrink();
                                    return Column(
                                      children: groups.map((group) {
                                        return _PausedCoupleAccordion(
                                          partnerName: group.partnerName,
                                          memories: group.memories,
                                          preservationEnd: group.preservationWindowEnd,
                                          theme: customTheme,
                                          onDownloadAll: (m) =>
                                              _downloadAllCoupleMemories(context, m),
                                          onMoveAllToPersonal: (m) =>
                                              _moveAllCoupleMemoriesToPersonal(context, m),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
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
        if (category == 'PERSONAL') {
          _handlePersonalCategoryTap(t);
        } else {
          setState(() {
            _selectedCategory = category;
          });
        }
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
        'PERSONAL' => Icons.lock_outline,
        _ => Icons.auto_stories,
      };

  String _getEmptyMessage(String category) => switch (category) {
        'SOLO' => 'Aún no tienes aventuras solitarias.\n¡Explora por tu cuenta!',
        'PAREJA' => 'Aún no tienen aventuras juntos.\n¡Planeen una cita!',
        'GRUPO' => 'Aún no hay expediciones grupales.\n¡Arma un grupo!',
        'PERSONAL' => 'Tu sección Personal está vacía.\nMueve recuerdos aquí con el menú de 3 puntos (⋮).',
        _ => 'Aún no tienes recuerdos guardados.\n¡Completa una aventura!',
      };



  Future<void> _moveAllCoupleMemoriesToPersonal(
    BuildContext context,
    List<AlbumMemory> coupleMemories,
  ) async {
    if (coupleMemories.isEmpty) {
      CustomSnackBar.showError(context, 'No hay recuerdos de pareja pendientes por guardar.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Mover Todo a Personal?'),
        content: Text(
          'Se moverán ${coupleMemories.length} recuerdos de pareja a tu sección Personal. Quedarán protegidos con tu PIN y se conservarán para siempre.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mover Todo'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final memory in coupleMemories) {
        final docRef = FirebaseFirestore.instance.collection('memories').doc(memory.id);
        batch.set(docRef, {
          'isPersonal': true,
          'originalType': 'Pareja',
          'userId': myUid,
          'isExCoupleConserved': true,
        }, SetOptions(merge: true));
      }
      await batch.commit();

      if (context.mounted) {
        CustomSnackBar.showSuccess(
          context,
          '¡${coupleMemories.length} recuerdos guardados exitosamente en Personal!',
        );
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.showError(context, 'Error al mover recuerdos: $e');
      }
    }
  }

  Future<void> _downloadAllCoupleMemories(
    BuildContext context,
    List<AlbumMemory> coupleMemories,
  ) async {
    final allPhotoUrls = <String>[];
    for (final m in coupleMemories) {
      allPhotoUrls.addAll(m.photoUrls);
    }

    if (allPhotoUrls.isEmpty) {
      CustomSnackBar.showError(context, 'No hay fotografías para descargar.');
      return;
    }

    CustomSnackBar.showSuccess(
      context,
      'Preparando descarga de ${allPhotoUrls.length} fotografías...',
    );

    try {
      final List<XFile> xFiles = [];
      final tempDir = await getTemporaryDirectory();

      for (int i = 0; i < allPhotoUrls.length; i++) {
        final response = await http.get(Uri.parse(allPhotoUrls[i]));
        if (response.statusCode == 200) {
          final file = File('${tempDir.path}/recuerdo_pareja_${i + 1}_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(response.bodyBytes);
          xFiles.add(XFile(file.path));
        }
      }

      if (xFiles.isNotEmpty) {
        await Share.shareXFiles(xFiles, text: 'Recuerdos de pareja descargados desde Daty');
      }
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.showError(context, 'Error al procesar imágenes: $e');
      }
    }
  }
}

class _IndexedMemory {
  final int index;
  final AlbumMemory memory;

  _IndexedMemory({required this.index, required this.memory});
}

class _PausedCoupleAccordion extends StatefulWidget {
  final String partnerName;
  final List<AlbumMemory> memories;
  final DateTime? preservationEnd;
  final AppCustomTheme theme;
  final Function(List<AlbumMemory>) onDownloadAll;
  final Function(List<AlbumMemory>) onMoveAllToPersonal;

  const _PausedCoupleAccordion({
    required this.partnerName,
    required this.memories,
    required this.preservationEnd,
    required this.theme,
    required this.onDownloadAll,
    required this.onMoveAllToPersonal,
  });

  @override
  State<_PausedCoupleAccordion> createState() => _PausedCoupleAccordionState();
}

class _PausedCoupleAccordionState extends State<_PausedCoupleAccordion> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.memories.isEmpty) return const SizedBox.shrink();

    final preservationEnd = widget.preservationEnd ?? widget.memories.first.preservationWindowEnd;
    final now = DateTime.now();

    String timeStr = '';
    if (preservationEnd != null && now.isBefore(preservationEnd)) {
      final diff = preservationEnd.difference(now);
      final days = diff.inDays;
      final hours = diff.inHours % 24;
      timeStr = days > 0 ? '$days días y $hours horas' : '$hours horas';
    }

    final t = widget.theme;
    final titleLabel = widget.partnerName.isNotEmpty &&
            widget.partnerName != 'Pareja' &&
            widget.partnerName != 'Pareja anterior'
        ? 'Relación con ${widget.partnerName} (${widget.memories.length})'
        : 'Relación Anterior (${widget.memories.length})';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      decoration: BoxDecoration(
        color: t.softSurface.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.text2.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header Título del Acordeón (Desplegable Sutil)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.history_rounded,
                    color: t.text2.withValues(alpha: 0.8),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          titleLabel,
                          style: TextStyle(
                            color: t.text2,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•  $timeStr',
                            style: TextStyle(
                              color: t.text2.withValues(alpha: 0.6),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: t.text2.withValues(alpha: 0.7),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Contenido Desplegable
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fotos de tu relación anterior en periodo de resguardo. Mantenlas a salvo en Personal antes de que venza el plazo.',
                    style: TextStyle(color: t.text2, fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(color: t.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(Icons.download_rounded, size: 16, color: t.primary),
                          label: Text(
                            'Descargar Todo',
                            style: TextStyle(color: t.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => widget.onDownloadAll(widget.memories),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            backgroundColor: t.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Mover Todo a Personal',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => widget.onMoveAllToPersonal(widget.memories),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Mini Grid de recuerdos de la ex-pareja
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: widget.memories.length,
                    itemBuilder: (ctx, index) {
                      return MemoryCard(
                        memory: widget.memories[index],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}