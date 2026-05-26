import 'package:flutter/material.dart';
import '../models/album_memory.dart';

class MemoryCard extends StatelessWidget {
  final AlbumMemory memory;

  const MemoryCard({super.key, required this.memory});

  @override
  Widget build(BuildContext context) {
    Color typeColor;
    if (memory.type == 'Solo') typeColor = const Color(0xFF1976D2);
    else if (memory.type == 'Pareja') typeColor = const Color(0xFFC2185B);
    else typeColor = const Color(0xFF8E24AA);

    String formattedDate = "${memory.date.day.toString().padLeft(2, '0')}/${memory.date.month.toString().padLeft(2, '0')}/${memory.date.year}";

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: typeColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(memory.emoji, style: const TextStyle(fontSize: 35)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(memory.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: typeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                          child: Text(memory.type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor)),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(formattedDate, style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              )
            ],
          ),
          
          if (memory.reviews.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: memory.reviews.map((review) => Padding(
                  padding: const EdgeInsets.only(bottom: 2.0),
                  child: Text(review, style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.black54, fontSize: 13)),
                )).toList(),
              ),
            ),

          if (memory.photoUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('📸 Recuerdos:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 8),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: memory.photoUrls.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 90,
                    height: 90,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        memory.photoUrls[index], 
                        fit: BoxFit.cover, 
                        errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.sentiment_dissatisfied, color: Colors.grey, size: 16), SizedBox(width: 6), Text('Sin fotos guardadas', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 12))]),
            )
          ]
        ],
      ),
    );
  }
}