import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/full_screen_image_viewer.dart';
import '../models/album_memory.dart';

class MemoryCard extends StatelessWidget {
  final AlbumMemory memory;

  const MemoryCard({super.key, required this.memory});

  Color _getTypeColor() {
    switch (memory.type) {
      case 'Solo':
        return const Color(0xFF1976D2);
      case 'Pareja':
        return const Color(0xFFC2185B);
      case 'Grupo':
        return const Color(0xFF8E24AA);
      default:
        return const Color(0xFF9C27B0);
    }
  }

  IconData _getTypeIcon() {
    switch (memory.type) {
      case 'Solo':
        return Icons.person_outline;
      case 'Pareja':
        return Icons.favorite_outline;
      case 'Grupo':
        return Icons.groups_outlined;
      default:
        return Icons.auto_stories;
    }
  }

  void _shareMemory(BuildContext context) {
    final formattedDate =
        "${memory.date.day.toString().padLeft(2, '0')}/${memory.date.month.toString().padLeft(2, '0')}/${memory.date.year}";
    final buffer = StringBuffer();
    buffer.writeln('${memory.emoji} ${memory.title}');
    buffer.writeln('📅 Fecha: $formattedDate (${memory.type})');
    if (memory.reviews.isNotEmpty) {
      buffer.writeln('\n💬 Reseñas:');
      for (final r in memory.reviews) {
        buffer.writeln('• $r');
      }
    }
    buffer.writeln('\n✨ Compartido desde Datty!');

    Share.share(buffer.toString());
  }

  void _showOptionsMenu(BuildContext context, AppCustomTheme t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: t.elevatedSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: t.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '${memory.emoji} ${memory.title}',
              style: TextStyle(
                color: t.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.share_outlined, color: t.primary),
              title: Text('Compartir Recuerdo', style: TextStyle(color: t.text)),
              onTap: () {
                Navigator.pop(ctx);
                _shareMemory(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.copy_outlined, color: t.primary),
              title: Text('Copiar Texto', style: TextStyle(color: t.text)),
              onTap: () {
                Navigator.pop(ctx);
                final formattedDate =
                    "${memory.date.day.toString().padLeft(2, '0')}/${memory.date.month.toString().padLeft(2, '0')}/${memory.date.year}";
                Clipboard.setData(ClipboardData(
                    text: '${memory.emoji} ${memory.title} - $formattedDate'));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('¡Copiado al portapapeles!')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().currentTheme;
    final typeColor = _getTypeColor();
    final formattedDate =
        "${memory.date.day.toString().padLeft(2, '0')}/${memory.date.month.toString().padLeft(2, '0')}/${memory.date.year}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: t.elevatedSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: t.outline),
        boxShadow: [
          BoxShadow(
              color: t.shadow, blurRadius: 14, offset: const Offset(0, 5)),
          if (t.isDark)
            BoxShadow(
                color: typeColor.withValues(alpha: 0.1),
                blurRadius: 18,
                spreadRadius: -4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Tipo + Fecha + Menú de Opciones
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: typeColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getTypeIcon(), size: 14, color: typeColor),
                      const SizedBox(width: 5),
                      Text(
                        memory.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: typeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 12, color: t.muted),
                    const SizedBox(width: 4),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: t.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.more_vert_rounded,
                          size: 18, color: t.muted),
                      onPressed: () => _showOptionsMenu(context, t),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Título
          if (memory.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                '${memory.emoji} ${memory.title}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: t.text,
                  height: 1.25,
                ),
              ),
            ),

          // Reseñas
          if (memory.reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: memory.reviews
                    .map(
                      (review) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: t.isDark
                              ? Colors.black.withValues(alpha: 0.25)
                              : t.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: t.outline.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.format_quote_rounded,
                              size: 16,
                              color: typeColor.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                review,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: t.text,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
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

          const SizedBox(height: 10),

          // Galería de fotos
          if (memory.photoUrls.isNotEmpty) _buildPhotoGrid(context, t),

          if (memory.photoUrls.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_outlined, color: t.muted, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Sin fotografías adjuntas',
                      style: TextStyle(
                        color: t.muted,
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext context, AppCustomTheme t) {
    final photoCount = memory.photoUrls.length;

    if (photoCount == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _buildPhotoItem(context, t, memory.photoUrls[0],
            borderRadius: BorderRadius.circular(16)),
      );
    }

    if (photoCount == 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: _buildPhotoItem(context, t, memory.photoUrls[0],
                  borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16))),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildPhotoItem(context, t, memory.photoUrls[1],
                  borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomRight: Radius.circular(16))),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1.3,
        ),
        itemCount: photoCount > 4 ? 4 : photoCount,
        itemBuilder: (context, index) {
          if (index == 3 && photoCount > 4) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                        imageUrl: memory.photoUrls[index]),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPhotoItem(context, t, memory.photoUrls[index],
                      borderRadius: BorderRadius.circular(12)),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        '+${photoCount - 3}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return _buildPhotoItem(context, t, memory.photoUrls[index],
              borderRadius: BorderRadius.circular(12));
        },
      ),
    );
  }

  Widget _buildPhotoItem(BuildContext context, AppCustomTheme t, String url,
      {required BorderRadius borderRadius}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(imageUrl: url),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: t.isDark ? Colors.grey.shade900 : Colors.grey.shade200,
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: t.primary,
              ),
            ),
            errorWidget: (context, url, error) => Icon(
              Icons.broken_image_outlined,
              color: t.muted,
            ),
          ),
        ),
      ),
    );
  }
}