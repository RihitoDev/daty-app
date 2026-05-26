import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SoloAdventureMemoryScreen extends StatelessWidget {
  final String myUid;
  final int adventureId;
  final Map<String, dynamic> adventureData;

  const SoloAdventureMemoryScreen({
    super.key, 
    required this.myUid, 
    required this.adventureId, 
    required this.adventureData,
  });

  @override
  Widget build(BuildContext context) {
    String memoryDocId = '${myUid}_$adventureId';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(adventureData['title'] ?? 'Mi Recuerdo', style: const TextStyle(color: Color(0xFF1976D2), fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1976D2)),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('solo_memories').doc(memoryDocId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1976D2)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Aún no hay recuerdos guardados de esta aventura.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          int rating = data['rating'] ?? 0;
          String review = data['review'] ?? '';
          List<dynamic> photos = data['photos'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(adventureData['emoji'] ?? '📍', style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 10),
                const Text('✨ Aventura Completada ✨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 30),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.blue.shade100)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mi experiencia', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1976D2))),
                          Row(
                            children: List.generate(5, (index) => Icon(
                              index < rating ? Icons.star : Icons.star_border, 
                              color: Colors.amber, size: 20
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      if (review.isNotEmpty)
                        Text('"$review"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: Colors.black87))
                      else
                        const Text('Sin comentario', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                      
                      const SizedBox(height: 20),
                      
                      const Text('📸 Mis Fotos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildPhotoBox(photos.isNotEmpty ? photos[0] : null),
                          const SizedBox(width: 10),
                          _buildPhotoBox(photos.length > 1 ? photos[1] : null),
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPhotoBox(String? photoUrl) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid)
          ),
          child: photoUrl != null && photoUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(photoUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildPhotoPlaceholder())
              )
            : _buildPhotoPlaceholder(),
        ),
      ),
    );
  }

  Widget _buildPhotoPlaceholder() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo_outlined, color: Colors.grey, size: 30),
        SizedBox(height: 5),
        Text('Sin foto', style: TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }
}