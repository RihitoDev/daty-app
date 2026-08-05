import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/full_screen_image_viewer.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../models/album_memory.dart';

class MemoryCard extends StatelessWidget {
  final AlbumMemory memory;
  final double cardHeight;

  const MemoryCard({
    super.key,
    required this.memory,
    this.cardHeight = 220,
  });

  Color _getTypeColor() {
    switch (memory.type) {
      case 'Solo':
        return const Color(0xFF64B5F6);
      case 'Pareja':
        return const Color(0xFFF48FB1);
      case 'Grupo':
        return const Color(0xFFCE93D8);
      default:
        return const Color(0xFFB388FF);
    }
  }

  IconData _getTypeIcon() {
    switch (memory.type) {
      case 'Solo':
        return Icons.person_outline_rounded;
      case 'Pareja':
        return Icons.favorite_outline_rounded;
      case 'Grupo':
        return Icons.groups_outlined;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  static IconData _getVectorIconForMemory(AlbumMemory memory) {
    final title = memory.title.toLowerCase();
    if (title.contains('cena') ||
        title.contains('comida') ||
        title.contains('angostura')) {
      return Icons.restaurant_rounded;
    }
    if (title.contains('café') || title.contains('cafe')) {
      return Icons.local_cafe_rounded;
    }
    if (title.contains('lectura') || title.contains('libro')) {
      return Icons.menu_book_rounded;
    }
    if (title.contains('arte') ||
        title.contains('dibujo') ||
        title.contains('pintura')) {
      return Icons.palette_rounded;
    }
    if (title.contains('caminata') ||
        title.contains('mirador') ||
        title.contains('apote') ||
        title.contains('naturaleza')) {
      return Icons.hiking_rounded;
    }
    if (title.contains('cine') ||
        title.contains('película') ||
        title.contains('pelicula')) {
      return Icons.movie_rounded;
    }
    if (title.contains('bicicleta') || title.contains('tunari')) {
      return Icons.directions_bike_rounded;
    }
    if (title.contains('museo') || title.contains('arqueoló')) {
      return Icons.museum_rounded;
    }
    if (title.contains('palacio') || title.contains('portales')) {
      return Icons.castle_rounded;
    }
    if (title.contains('helado')) {
      return Icons.icecream_rounded;
    }
    if (title.contains('spa') || title.contains('baño')) {
      return Icons.hot_tub_rounded;
    }
    if (title.contains('meditación') || title.contains('laguna')) {
      return Icons.self_improvement_rounded;
    }
    if (title.contains('runner') || title.contains('cristo')) {
      return Icons.directions_run_rounded;
    }
    if (title.contains('fotografía') || title.contains('foto')) {
      return Icons.camera_alt_rounded;
    }
    if (title.contains('cocinar') || title.contains('receta')) {
      return Icons.soup_kitchen_rounded;
    }

    switch (memory.type) {
      case 'Solo':
        return Icons.explore_rounded;
      case 'Pareja':
        return Icons.favorite_rounded;
      case 'Grupo':
        return Icons.groups_rounded;
      default:
        return Icons.auto_stories_rounded;
    }
  }

  String _formatDateShort(DateTime d) {
    const months = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic'
    ];
    final day = d.day.toString().padLeft(2, '0');
    final month = months[d.month - 1];
    return '$day $month ${d.year}';
  }

  Widget buildDetailSheet(BuildContext context, AppCustomTheme t) {
    return _MemoryDetailSheet(memory: memory, theme: t);
  }

  void _openDetailModal(BuildContext context, AppCustomTheme t) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => buildDetailSheet(ctx, t),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().currentTheme;
    final typeColor = _getTypeColor();
    final dateStr = _formatDateShort(memory.date);
    final hasPhotos = memory.photoUrls.isNotEmpty;
    final coverPhoto = hasPhotos ? memory.photoUrls.first : null;

    return PressableScale(
      scale: 0.96,
      onTap: () => _openDetailModal(context, t),
      semanticsLabel: 'Ver recuerdo: ${memory.title}',
      child: Container(
        height: cardHeight,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: t.isDark
                ? typeColor.withValues(alpha: 0.25)
                : t.outline.withValues(alpha: 0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: t.isDark ? 0.35 : 0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Imagen de portada o Gradiente Artístico Limpio
              if (hasPhotos && coverPhoto != null)
                CachedNetworkImage(
                  imageUrl: coverPhoto,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: t.isDark
                        ? const Color(0xFF1E1E24)
                        : Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: t.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    debugPrint(
                        'Error al cargar foto de portada [$url]: $error');
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: t.adventureGradient(typeColor),
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 32,
                        ),
                      ),
                    );
                  },
                )
              else
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: t.adventureGradient(typeColor),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: -20,
                        top: -20,
                        child: Icon(
                          _getVectorIconForMemory(memory),
                          size: 110,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.25),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _getVectorIconForMemory(memory),
                            size: 38,
                            color: Colors.white.withValues(alpha: 0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Gradiente Oscuro de Lectura
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.4),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0.0, 0.35, 0.7, 1.0],
                    ),
                  ),
                ),
              ),

              // 3. Etiqueta Neón y Contador Superior
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_getTypeIcon(), size: 12, color: typeColor),
                              const SizedBox(width: 4),
                              Text(
                                memory.type.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: typeColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (memory.photoUrls.length > 1)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.collections_rounded,
                                    size: 11, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  '${memory.photoUrls.length}',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (memory.preservationWindowEnd != null &&
                        !memory.isPersonal)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color:
                                  Colors.amber.shade900.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.amber.shade300,
                                width: 0.8,
                              ),
                            ),
                            child: Builder(
                              builder: (_) {
                                final diff = memory.preservationWindowEnd!
                                    .difference(DateTime.now());
                                final days = diff.inDays;
                                final hours = diff.inHours % 24;
                                final str = days > 0
                                    ? '${days}d ${hours}h'
                                    : '${hours}h';
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.timer_outlined,
                                        size: 11, color: Colors.white),
                                    const SizedBox(width: 3),
                                    Text(
                                      str,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 4. Información Inferior (Título & Fecha)
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      memory.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.8)),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hoja Modal Desplegable de Detalle ────────────────────────────────────────

class _MemoryDetailSheet extends StatefulWidget {
  final AlbumMemory memory;
  final AppCustomTheme theme;

  const _MemoryDetailSheet({
    required this.memory,
    required this.theme,
  });

  @override
  State<_MemoryDetailSheet> createState() => _MemoryDetailSheetState();
}

class _MemoryDetailSheetState extends State<_MemoryDetailSheet> {
  int _activePhotoIndex = 0;
  bool _isSharing = false;

  String _formatDate(DateTime d) {
    const months = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return '${d.day} de ${months[d.month - 1]} de ${d.year}';
  }

  Future<void> _share() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final memory = widget.memory;
      final buffer = StringBuffer();
      buffer.writeln('${memory.emoji} ${memory.title}');
      buffer.writeln('📅 ${_formatDate(memory.date)} (${memory.type})');
      if (memory.reviews.isNotEmpty) {
        buffer.writeln('\n💬 Reseña:');
        for (final r in memory.reviews) {
          buffer.writeln('• $r');
        }
      }
      buffer.writeln('\n✨ ¡Compartido desde Daty!');

      if (memory.photoUrls.isNotEmpty) {
        try {
          final imageUrl = memory.photoUrls.first;
          final response = await http.get(Uri.parse(imageUrl));

          if (response.statusCode == 200) {
            if (kIsWeb) {
              final xFile = XFile.fromData(
                response.bodyBytes,
                name: 'share_${DateTime.now().millisecondsSinceEpoch}.jpg',
                mimeType: 'image/jpeg',
              );
              await Share.shareXFiles(
                [xFile],
                text: buffer.toString(),
              );
              return;
            } else {
              final tempDir = await getTemporaryDirectory();
              final file = File(
                  '${tempDir.path}/share_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await file.writeAsBytes(response.bodyBytes);

              await Share.shareXFiles(
                [XFile(file.path)],
                text: buffer.toString(),
              );
              return;
            }
          }
        } catch (e) {
          debugPrint('Error al descargar foto para compartir: $e');
        }
      }

      await Share.share(buffer.toString());
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al compartir: $e');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _downloadImage() async {
    if (widget.memory.photoUrls.isEmpty) {
      CustomSnackBar.showError(
          context, 'Este recuerdo no contiene fotografías.');
      return;
    }

    try {
      final url = widget.memory.photoUrls[_activePhotoIndex];
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        if (kIsWeb) {
          final xFile = XFile.fromData(
            response.bodyBytes,
            name: 'recuerdo_${DateTime.now().millisecondsSinceEpoch}.jpg',
            mimeType: 'image/jpeg',
          );
          await Share.shareXFiles([xFile], text: 'Descargado desde Daty');
        } else {
          final tempDir = await getTemporaryDirectory();
          final file = File(
              '${tempDir.path}/recuerdo_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await file.writeAsBytes(response.bodyBytes);
          await Share.shareXFiles([XFile(file.path)],
              text: 'Guardado desde Daty');
        }
        if (mounted) {
          CustomSnackBar.showSuccess(context, 'Imagen preparada para guardar');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al descargar la imagen: $e');
      }
    }
  }

  Future<void> _moveToPersonal() async {
    final memory = widget.memory;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myUid = auth.user?.uid;
    final currentPartnerId = auth.userData?['partnerId'];

    try {
      String collectionName = 'solo_memories';
      if (memory.type == 'Pareja' ||
          memory.originalType == 'Pareja' ||
          memory.rawData?['coupleDocId'] != null) {
        collectionName = 'memories';
      } else if (memory.type == 'Grupo' || memory.originalType == 'Grupo') {
        collectionName = 'group_memories';
      }

      final isCouple = collectionName == 'memories';
      final isUnlinkedCouple = isCouple && currentPartnerId == null;

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(memory.id)
          .set({
        'isPersonal': true,
        'originalType':
            memory.originalType.isNotEmpty ? memory.originalType : memory.type,
        if (myUid != null) 'userId': myUid,
        if (isUnlinkedCouple) 'isExCoupleConserved': true,
      }, SetOptions(merge: true));

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Movido a Personal');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al mover a Personal');
      }
    }
  }

  Future<void> _restoreFromPersonal() async {
    final memory = widget.memory;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final myUid = auth.user?.uid;
    final currentPartnerId = auth.userData?['partnerId'];

    final isCoupleMemory = memory.originalType == 'Pareja' ||
        memory.type == 'Pareja' ||
        memory.rawData?['coupleDocId'] != null;

    if (isCoupleMemory) {
      final raw = memory.rawData ?? {};
      String? memoryCoupleDocId = raw['coupleDocId'] as String?;
      if (memoryCoupleDocId == null && memory.id.contains('_')) {
        final parts = memory.id.split('_');
        if (parts.length >= 2) {
          memoryCoupleDocId = '${parts[0]}_${parts[1]}';
        }
      }

      String? activeCoupleDocId;
      if (myUid != null && currentPartnerId != null) {
        activeCoupleDocId = myUid.compareTo(currentPartnerId) < 0
            ? '${myUid}_$currentPartnerId'
            : '${currentPartnerId}_$myUid';
      }

      final isSamePartnerActive = activeCoupleDocId != null &&
          memoryCoupleDocId != null &&
          activeCoupleDocId == memoryCoupleDocId;

      if (!isSamePartnerActive) {
        CustomSnackBar.showError(
          context,
          'Este recuerdo pertenece a una pareja anterior. Permanece resguardado en Personal y no se puede trasladar a tu vínculo actual.',
        );
        return;
      }
    }

    try {
      String collectionName = 'solo_memories';
      if (isCoupleMemory) collectionName = 'memories';
      if (memory.originalType == 'Grupo' || memory.type == 'Grupo') {
        collectionName = 'group_memories';
      }

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(memory.id)
          .set({
        'isPersonal': false,
        if (isCoupleMemory) 'isExCoupleConserved': FieldValue.delete(),
      }, SetOptions(merge: true));

      if (mounted) {
        CustomSnackBar.showSuccess(context,
            'Restaurado a ${memory.originalType.isNotEmpty ? memory.originalType : memory.type}');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al restaurar recuerdo');
      }
    }
  }

  Future<void> _deleteMemory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        actionsOverflowAlignment: OverflowBarAlignment.end,
        actionsOverflowButtonSpacing: 6,
        title: const Text('¿Eliminar recuerdo?'),
        content: const Text(
            'Esta acción eliminará el recuerdo de forma permanente. No se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final memory = widget.memory;
      String collectionName = 'solo_memories';
      if (memory.type == 'Pareja') collectionName = 'memories';
      if (memory.type == 'Grupo') collectionName = 'group_memories';

      await FirebaseFirestore.instance
          .collection(collectionName)
          .doc(memory.id)
          .delete();

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Recuerdo eliminado');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al eliminar recuerdo');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final memory = widget.memory;
    final t = widget.theme;
    final dateStr = _formatDate(memory.date);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: t.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 38,
            height: 4.5,
            decoration: BoxDecoration(
              color: t.muted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
          ),

          // Header Bar con Categoría, Fecha, Opciones (3 Puntos) y Cierre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    memory.type.toUpperCase(),
                    style: TextStyle(
                      color: t.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dateStr,
                    style: TextStyle(
                      color: t.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (_isSharing)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: t.primary,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon:
                        Icon(Icons.share_outlined, color: t.primary, size: 20),
                    onPressed: _share,
                  ),

                // Menú de 3 Puntos (⋮)
                PopupMenuButton<String>(
                  icon:
                      Icon(Icons.more_vert_rounded, color: t.primary, size: 20),
                  color: t.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: t.outline),
                  ),
                  onSelected: (val) {
                    if (val == 'download') _downloadImage();
                    if (val == 'move_personal') _moveToPersonal();
                    if (val == 'restore') _restoreFromPersonal();
                    if (val == 'delete') _deleteMemory();
                  },
                  itemBuilder: (ctx) => [
                    if (memory.photoUrls.isNotEmpty)
                      PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download_rounded,
                                color: t.primary, size: 18),
                            const SizedBox(width: 10),
                            Text('Descargar Imagen',
                                style: TextStyle(color: t.text, fontSize: 13)),
                          ],
                        ),
                      ),
                    if (!memory.isPersonal)
                      PopupMenuItem(
                        value: 'move_personal',
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline_rounded,
                                color: t.primary, size: 18),
                            const SizedBox(width: 10),
                            Text('Mover a PERSONAL',
                                style: TextStyle(color: t.text, fontSize: 13)),
                          ],
                        ),
                      )
                    else if (!memory.isExCoupleConserved)
                      PopupMenuItem(
                        value: 'restore',
                        child: Row(
                          children: [
                            Icon(Icons.unarchive_rounded,
                                color: t.primary, size: 18),
                            const SizedBox(width: 10),
                            Text('Restaurar a ${memory.originalType}',
                                style: TextStyle(color: t.text, fontSize: 13)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: t.primary, size: 18),
                          const SizedBox(width: 10),
                          Text('Eliminar Recuerdo',
                              style: TextStyle(color: t.text, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),

                IconButton(
                  icon: Icon(Icons.close_rounded, color: t.muted, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Cuerpo desplazable
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (memory.preservationWindowEnd != null &&
                      !memory.isPersonal) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade900.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: Colors.amber.shade700, width: 1),
                        ),
                        child: Builder(
                          builder: (_) {
                            final diff = memory.preservationWindowEnd!
                                .difference(DateTime.now());
                            final days = diff.inDays;
                            final hours = diff.inHours % 24;
                            final timeStr = days > 0
                                ? '$days días y $hours horas'
                                : '$hours horas';

                            return Row(
                              children: [
                                const Icon(Icons.timer_outlined,
                                    color: Colors.amber, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '⏱️ Quedan $timeStr para resguardar este recuerdo en Personal o descargarlo antes de su eliminación permanente.',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ],

                  // Título de la Aventura
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: t.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            MemoryCard._getVectorIconForMemory(memory),
                            color: t.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            memory.title,
                            style: TextStyle(
                              color: t.text,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Carrusel de Fotos
                  if (memory.photoUrls.isNotEmpty) ...[
                    SizedBox(
                      height: 300,
                      child: PageView.builder(
                        itemCount: memory.photoUrls.length,
                        onPageChanged: (idx) {
                          setState(() => _activePhotoIndex = idx);
                        },
                        itemBuilder: (context, index) {
                          final url = memory.photoUrls[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      FullScreenImageViewer(imageUrl: url),
                                ),
                              );
                            },
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: t.outline),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: CachedNetworkImage(
                                  imageUrl: url,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Center(
                                    child: CircularProgressIndicator(
                                        color: t.primary),
                                  ),
                                  errorWidget: (_, __, ___) => Icon(
                                      Icons.broken_image_outlined,
                                      color: t.muted),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (memory.photoUrls.length > 1) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          memory.photoUrls.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _activePhotoIndex == i ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _activePhotoIndex == i
                                  ? t.primary
                                  : t.muted.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // Sección de Reseñas
                  if (memory.reviews.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 16, color: t.primary),
                          const SizedBox(width: 6),
                          Text(
                            'Reseñas & Reflexiones',
                            style: TextStyle(
                              color: t.text,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...memory.reviews.map(
                      (r) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: t.softSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: t.outline),
                        ),
                        child: Text(
                          r,
                          style: TextStyle(
                            color: t.text,
                            fontSize: 13.5,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
