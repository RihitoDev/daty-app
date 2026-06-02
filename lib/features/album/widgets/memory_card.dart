import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/album_memory.dart';
import '../../shared/widgets/full_screen_image_viewer.dart';

class MemoryCard extends StatelessWidget {
  final AlbumMemory memory;

  const MemoryCard({super.key, required this.memory});

  Color _getTypeColor() {
    switch (memory.type) {
      case 'Solo': return const Color(0xFF1976D2);
      case 'Pareja': return const Color(0xFFC2185B);
      case 'Grupo': return const Color(0xFF8E24AA);
      default: return const Color(0xFF9C27B0);
    }
  }

  IconData _getTypeIcon() {
    switch (memory.type) {
      case 'Solo': return Icons.backpack_outlined;
      case 'Pareja': return Icons.favorite_outline;
      case 'Grupo': return Icons.groups_outlined;
      default: return Icons.auto_stories;
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeColor = _getTypeColor();
    final formattedDate = "${memory.date.day.toString().padLeft(2, '0')}/${memory.date.month.toString().padLeft(2, '0')}/${memory.date.year}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CABECERA
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_getTypeIcon(), size: 14, color: typeColor),
                      const SizedBox(width: 5),
                      Text(memory.type.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor)),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(formattedDate, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          
          if (memory.title.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('${memory.emoji} ${memory.title}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF2C2C2C))),
            ),

          if (memory.reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: memory.reviews.map((review) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Text(review, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.4)),
                )).toList(),
              ),
            ),
          
          const SizedBox(height: 10),

          if (memory.photoUrls.isNotEmpty) _buildPhotoGrid(context),
          
          if (memory.photoUrls.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sentiment_dissatisfied_outlined, color: Colors.grey, size: 16),
                    SizedBox(width: 8),
                    Text('Sin fotos guardadas', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12)),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildPhotoGrid(BuildContext context) {
    int photoCount = memory.photoUrls.length;
    
    if (photoCount == 1) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: _buildPhotoItem(context, memory.photoUrls[0], borderRadius: BorderRadius.circular(16)),
      );
    }

    if (photoCount == 2) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(child: _buildPhotoItem(context, memory.photoUrls[0], borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)))),
            const SizedBox(width: 2),
            Expanded(child: _buildPhotoItem(context, memory.photoUrls[1], borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)))),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 2, mainAxisSpacing: 2, childAspectRatio: 1.2),
        itemCount: photoCount > 4 ? 4 : photoCount,
        itemBuilder: (context, index) {
          if (index == 3 && photoCount > 4) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildPhotoItem(context, memory.photoUrls[index], borderRadius: BorderRadius.circular(8)),
                Container(
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('+${photoCount - 3}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))),
                ),
              ],
            );
          }
          return _buildPhotoItem(context, memory.photoUrls[index], borderRadius: BorderRadius.circular(8));
        },
      ),
    );
  }

  Widget _buildPhotoItem(BuildContext context, String url, {required BorderRadius borderRadius}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImageViewer(imageUrl: url)));
      },
      child: Container(
        decoration: BoxDecoration(borderRadius: borderRadius, color: Colors.grey.shade200),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400))),
            errorWidget: (context, url, error) => const Icon(Icons.broken_image_outlined, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}