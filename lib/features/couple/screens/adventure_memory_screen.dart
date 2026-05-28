import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../auth/providers/auth_provider.dart';

class AdventureMemoryScreen extends StatelessWidget {
  final String coupleDocId;
  final int adventureId;
  final Map<String, dynamic> adventureData;

  const AdventureMemoryScreen({
    super.key, 
    required this.coupleDocId, 
    required this.adventureId, 
    required this.adventureData,
  });

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProvider.user!.uid;
    final partnerId = authProvider.userData!['partnerId'];
    bool isUser1 = myUid.compareTo(partnerId) < 0;

    String memoryDocId = '${coupleDocId}_$adventureId';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(adventureData['title'] ?? 'Nuestro Recuerdo', style: const TextStyle(color: Color(0xFFC2185B), fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFFC2185B)),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('memories').doc(memoryDocId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFC2185B)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Aún no hay recuerdos guardados de esta cita.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          String myPrefix = isUser1 ? 'user1' : 'user2';
          String partnerPrefix = isUser1 ? 'user2' : 'user1';

          int myRating = data['${myPrefix}_rating'] ?? 0;
          String myReview = data['${myPrefix}_review'] ?? '';
          List<dynamic> myPhotos = data['${myPrefix}_photos'] ?? [];

          int partnerRating = data['${partnerPrefix}_rating'] ?? 0;
          String partnerReview = data['${partnerPrefix}_review'] ?? '';
          List<dynamic> partnerPhotos = data['${partnerPrefix}_photos'] ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(adventureData['emoji'] ?? '📍', style: const TextStyle(fontSize: 60)),
                const SizedBox(height: 10),
                const Text('✨ Cita Completada ✨', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 30),
                
                _buildReviewCard(context, title: 'Mi experiencia', rating: myRating, review: myReview, photos: myPhotos, isMe: true),
                const SizedBox(height: 20),
                _buildReviewCard(context, title: 'Experiencia de tu pareja', rating: partnerRating, review: partnerReview, photos: partnerPhotos, isMe: false),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReviewCard(BuildContext context, {required String title, required int rating, required String review, required List<dynamic> photos, required bool isMe}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFCE4EC) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isMe ? Colors.pink.shade100 : Colors.blue.shade100)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFC2185B))),
              Row(children: List.generate(5, (index) => Icon(index < rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 20))),
            ],
          ),
          const SizedBox(height: 15),
          if (review.isNotEmpty)
            Text('"$review"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: Colors.black87))
          else
            const Text('Sin comentario', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          
          const SizedBox(height: 20),
          const Text('📸 Recuerdos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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
    );
  }

  Widget _buildPhotoBox(String? photoUrl) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
          child: photoUrl != null && photoUrl.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                // CAMBIO: Caché de imágenes
                child: CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover, placeholder: (_, __) => const Center(child: CircularProgressIndicator()), errorWidget: (_, __, ___) => _buildPhotoPlaceholder())
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