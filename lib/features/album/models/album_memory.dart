import 'package:cloud_firestore/cloud_firestore.dart';

class AlbumMemory {
  final String type;
  final String title;
  final String emoji;
  final DateTime date;
  final List<String> reviews;
  final List<String> photoUrls;

  AlbumMemory({
    required this.type,
    required this.title,
    required this.emoji,
    required this.date,
    required this.reviews,
    required this.photoUrls,
  });

  // Mapeo directo para aventuras en solitario.
  factory AlbumMemory.fromSoloFirestore(Map<String, dynamic> data) {
    return AlbumMemory(
      type: 'Solo',
      title: data['adventure_title'] ?? 'Aventura',
      emoji: '🧘‍♂️',
      date: _parseDate(data['timestamp']),
      reviews: [
        if (data['review'] != null && data['review'].toString().isNotEmpty)
          data['review']
      ],
      photoUrls: List<String>.from(data['photos'] ?? []),
    );
  }

  // Para las citas, unimos la data de los dos usuarios en un solo objeto.
  factory AlbumMemory.fromCoupleFirestore(Map<String, dynamic> data, String user1Name, String user2Name) {
    List<String> reviews = [];
    if (data['user1_review'] != null && data['user1_review'].toString().isNotEmpty) {
      reviews.add('$user1Name: ${data['user1_review']}');
    }
    if (data['user2_review'] != null && data['user2_review'].toString().isNotEmpty) {
      reviews.add('$user2Name: ${data['user2_review']}');
    }

    List<String> photos = [];
    photos.addAll(List<String>.from(data['user1_photos'] ?? []));
    photos.addAll(List<String>.from(data['user2_photos'] ?? []));

    return AlbumMemory(
      type: 'Pareja',
      title: data['adventure_title'] ?? 'Cita',
      emoji: '❤️',
      date: _parseDate(data['timestamp']),
      reviews: reviews,
      photoUrls: photos,
    );
  }

  // Manejo del álbum de grupos.
  factory AlbumMemory.fromGroupFirestore(Map<String, dynamic> data) {
    List<String> photos = [];
    if (data['photos'] is List) {
      photos = List<String>.from(data['photos']);
    } else if (data['photos'] is Map) {
      photos = List<String>.from((data['photos'] as Map).values);
    }

    return AlbumMemory(
      type: 'Grupo',
      title: data['adventure_title'] ?? 'Expedición',
      emoji: '👥',
      date: _parseDate(data['timestamp']),
      reviews: [],
      photoUrls: photos,
    );
  }

  // Parseo seguro del timestamp. 
  static DateTime _parseDate(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    return DateTime.now();
  }
}