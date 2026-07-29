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

  factory AlbumMemory.fromSoloFirestore(Map<String, dynamic> data) {
    List<String> photos = [];
    if (data['photos'] is List) {
      photos = List<String>.from(data['photos']);
    }

    return AlbumMemory(
      type: 'Solo',
      title: data['adventure_title'] ?? data['title'] ?? 'Aventura',
      emoji: data['emoji'] ?? '🧘‍♂️',
      date: _parseDate(data['timestamp'] ?? data['date'] ?? data['createdAt']),
      reviews: [
        if (data['review'] != null && data['review'].toString().isNotEmpty)
          data['review'].toString()
      ],
      photoUrls: photos,
    );
  }

  factory AlbumMemory.fromCoupleFirestore(Map<String, dynamic> data, String user1Name, String user2Name) {
    List<String> reviews = [];
    if (data['user1_review'] != null && data['user1_review'].toString().isNotEmpty) {
      reviews.add('$user1Name: ${data['user1_review']}');
    }
    if (data['user2_review'] != null && data['user2_review'].toString().isNotEmpty) {
      reviews.add('$user2Name: ${data['user2_review']}');
    }

    List<String> photos = [];
    if (data['user1_photos'] is List) {
      photos.addAll(List<String>.from(data['user1_photos']));
    }
    if (data['user2_photos'] is List) {
      photos.addAll(List<String>.from(data['user2_photos']));
    }

    return AlbumMemory(
      type: 'Pareja',
      title: data['adventure_title'] ?? data['title'] ?? 'Cita',
      emoji: data['emoji'] ?? '❤️',
      date: _parseDate(data['timestamp'] ?? data['date'] ?? data['createdAt']),
      reviews: reviews,
      photoUrls: photos,
    );
  }

  factory AlbumMemory.fromGroupFirestore(Map<String, dynamic> data) {
    List<String> photos = [];
    if (data['photos'] is List) {
      photos = List<String>.from(data['photos']);
    } else if (data['photos'] is Map) {
      photos = List<String>.from((data['photos'] as Map).values);
    }

    return AlbumMemory(
      type: 'Grupo',
      title: data['adventure_title'] ?? data['title'] ?? 'Expedición',
      emoji: data['emoji'] ?? '👥',
      date: _parseDate(data['timestamp'] ?? data['date'] ?? data['createdAt']),
      reviews: [],
      photoUrls: photos,
    );
  }

  static DateTime _parseDate(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      final parsed = DateTime.tryParse(timestamp);
      if (parsed != null) return parsed;
    }
    if (timestamp is int) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime.now();
  }
}