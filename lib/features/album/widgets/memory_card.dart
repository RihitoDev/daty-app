import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/full_screen_image_viewer.dart';
import '../../../shared/widgets/pressable_scale.dart';
import '../models/album_memory.dart';

class MemoryCard extends StatelessWidget {
  final AlbumMemory memory;
  final double cardHeight;

  const MemoryCard({
    super.key,
    required this.memory,
    this.cardHeight = 240,
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

  String _formatDateShort(DateTime d) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
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
                    color: t.isDark ? const Color(0xFF1E1E24) : Colors.grey.shade200,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: t.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) {
                    debugPrint('Error al cargar foto de portada [$url]: $error');
                    return Container(
                      color: t.isDark ? const Color(0xFF1E1E24) : Colors.grey.shade300,
                      child: Icon(Icons.broken_image_outlined, color: t.muted),
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
                        bottom: -20,
                        child: Icon(
                          _getTypeIcon(),
                          size: 110,
                          color: typeColor.withValues(alpha: 0.12),
                        ),
                      ),
                      Center(
                        child: Text(
                          memory.emoji,
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Degradado Inferior Suave (Sombra progresiva)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: cardHeight * 0.55,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black87,
                        Colors.black45,
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Badges Superiores con Efecto Vidrio (Glassmorphism)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badge de Tipo de Aventura
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

                    // Contador de Fotos
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
                      '${memory.emoji} ${memory.title}',
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
                            color: Colors.white.withValues(alpha: 0.75)),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
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

// ── Hoja Modal Desplegable de Detalle Estilo Red Social ────────────────────────

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

  String _formatDate(DateTime d) {
    const months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${d.day} de ${months[d.month - 1]} de ${d.year}';
  }

  bool _isSharing = false;

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

      // Si la aventura tiene fotos, descargamos la foto principal para adjuntarla
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
          debugPrint('Error descargando imagen para compartir: $e');
        }
      }

      // Si no tiene fotos o falla la descarga, compartimos solo el texto
      await Share.share(buffer.toString());
    } catch (e) {
      debugPrint('Error al compartir recuerdo: $e');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final memory = widget.memory;
    final dateStr = _formatDate(memory.date);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: t.elevatedSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: t.outline),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Asa superior de arrastre
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: t.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Cabecera Modal
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
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
                  _isSharing
                      ? Padding(
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
                      : IconButton(
                          icon: Icon(Icons.share_outlined,
                              color: t.primary, size: 20),
                          onPressed: _share,
                        ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: t.muted, size: 22),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Cuerpo desplazable con más aire y espaciado de lectura
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Título de la Aventura
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                      child: Text(
                        '${memory.emoji} ${memory.title}',
                        style: TextStyle(
                          color: t.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
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
                                  color: t.isDark
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade200,
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
                            (idx) => AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _activePhotoIndex == idx ? 18 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _activePhotoIndex == idx
                                    ? t.primary
                                    : t.muted.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],

                    // Sección de Reseñas / Comentarios
                    if (memory.reviews.isNotEmpty) ...[
                      const SizedBox(height: 22),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 16, color: t.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Reseñas y Experiencias',
                              style: TextStyle(
                                color: t.text,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: memory.reviews
                              .map(
                                (r) => Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: t.isDark
                                        ? Colors.black.withValues(alpha: 0.3)
                                        : t.primaryLight.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: t.outline.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.format_quote_rounded,
                                          size: 18, color: t.primary),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          r,
                                          style: TextStyle(
                                            color: t.text,
                                            fontSize: 14,
                                            height: 1.45,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}