import 'package:cloud_firestore/cloud_firestore.dart';

class AlbumMemory {
  final String id;
  final String type;
  final String title;
  final String emoji;
  final DateTime date;
  final List<String> reviews;
  final List<String> photoUrls;
  final bool isPersonal;
  final bool isExCoupleConserved;
  final String originalType;
  final DateTime? preservationWindowEnd;
  final Map<String, dynamic>? rawData;

  AlbumMemory({
    required this.id,
    required this.type,
    required this.title,
    required this.emoji,
    required this.date,
    required this.reviews,
    required this.photoUrls,
    this.isPersonal = false,
    this.isExCoupleConserved = false,
    this.originalType = 'Solo',
    this.preservationWindowEnd,
    this.rawData,
  });

  AlbumMemory copyWith({
    DateTime? preservationWindowEnd,
  }) {
    return AlbumMemory(
      id: id,
      type: type,
      title: title,
      emoji: emoji,
      date: date,
      reviews: reviews,
      photoUrls: photoUrls,
      isPersonal: isPersonal,
      isExCoupleConserved: isExCoupleConserved,
      originalType: originalType,
      preservationWindowEnd: preservationWindowEnd ?? this.preservationWindowEnd,
      rawData: rawData,
    );
  }

  factory AlbumMemory.fromSoloFirestore(Map<String, dynamic> data, {String id = ''}) {
    List<String> photos = [];
    if (data['photos'] is List) {
      photos = List<String>.from(data['photos']);
    }

    final bool isPers = data['isPersonal'] ?? false;
    final bool isExConserved = data['isExCoupleConserved'] ?? false;
    final String origType = data['originalType'] ?? 'Solo';

    return AlbumMemory(
      id: id.isNotEmpty ? id : (data['id'] ?? ''),
      type: 'Solo',
      title: data['adventure_title'] ?? data['title'] ?? 'Aventura',
      emoji: _getEmoji(data, '🧘‍♂️'),
      date: parseDate(data['timestamp'] ?? data['date'] ?? data['createdAt']),
      reviews: [
        if (data['review'] != null && data['review'].toString().isNotEmpty)
          data['review'].toString()
      ],
      photoUrls: photos,
      isPersonal: isPers,
      isExCoupleConserved: isExConserved,
      originalType: origType,
      rawData: data,
    );
  }

  factory AlbumMemory.fromCoupleFirestore(
    Map<String, dynamic> data,
    String user1Name,
    String user2Name, {
    String id = '',
  }) {
    List<String> photos = [];
    if (data['user1_photos'] is List) {
      photos.addAll(List<String>.from(data['user1_photos']));
    }
    if (data['user2_photos'] is List) {
      photos.addAll(List<String>.from(data['user2_photos']));
    }
    if (data['photos'] is List) {
      photos.addAll(List<String>.from(data['photos']));
    }

    List<String> reviews = [];
    if (data['user1_review'] != null &&
        data['user1_review'].toString().isNotEmpty) {
      reviews.add('$user1Name: "${data['user1_review']}"');
    }
    if (data['user2_review'] != null &&
        data['user2_review'].toString().isNotEmpty) {
      reviews.add('$user2Name: "${data['user2_review']}"');
    }

    final bool isPers = data['isPersonal'] ?? false;
    final bool isExConserved = data['isExCoupleConserved'] ?? false;
    final String origType = data['originalType'] ?? 'Pareja';

    return AlbumMemory(
      id: id.isNotEmpty ? id : (data['id'] ?? ''),
      type: 'Pareja',
      title: data['adventure_title'] ?? data['title'] ?? 'Cita en Pareja',
      emoji: _getEmoji(data, '❤️'),
      date: parseDate(data['timestamp'] ?? data['date'] ?? data['createdAt']),
      reviews: reviews,
      photoUrls: photos,
      isPersonal: isPers,
      isExCoupleConserved: isExConserved,
      originalType: origType,
      rawData: data,
    );
  }

  factory AlbumMemory.fromGroupFirestore(Map<String, dynamic> data, {String id = ''}) {
    List<String> photos = [];
    if (data['photos'] is List) {
      photos = List<String>.from(data['photos']);
    }

    final bool isPers = data['isPersonal'] ?? false;
    final bool isExConserved = data['isExCoupleConserved'] ?? false;
    final String origType = data['originalType'] ?? 'Grupo';

    return AlbumMemory(
      id: id.isNotEmpty ? id : (data['id'] ?? ''),
      type: 'Grupo',
      title: data['adventure_title'] ?? data['title'] ?? 'Aventura Grupal',
      emoji: _getEmoji(data, '👥'),
      date: parseDate(data['timestamp'] ?? data['date'] ?? data['createdAt']),
      reviews: [
        if (data['review'] != null && data['review'].toString().isNotEmpty)
          data['review'].toString()
      ],
      photoUrls: photos,
      isPersonal: isPers,
      isExCoupleConserved: isExConserved,
      originalType: origType,
      rawData: data,
    );
  }

  static String _getEmoji(Map<String, dynamic> data, String defaultEmoji) {
    if (data['emoji'] != null && data['emoji'].toString().isNotEmpty) {
      return data['emoji'].toString();
    }
    final title =
        (data['adventure_title'] ?? data['title'] ?? '').toString().toLowerCase();
    if (title.contains('cena') || title.contains('angostura') || title.contains('comida')) {
      return '🌌';
    }
    if (title.contains('café') || title.contains('cafe')) return '☕';
    if (title.contains('lectura') || title.contains('libro')) return '📚';
    if (title.contains('dibujo') || title.contains('pintura') || title.contains('arte')) {
      return '🎨';
    }
    if (title.contains('caminata') || title.contains('mirador') || title.contains('apote')) {
      return '🥾';
    }
    if (title.contains('cine') || title.contains('película')) return '🎬';
    if (title.contains('bicicleta') || title.contains('tunari')) return '🚴';
    if (title.contains('museo') || title.contains('arqueoló')) return '🏺';
    if (title.contains('palacio') || title.contains('portales')) return '🏰';
    if (title.contains('helado')) return '🍨';
    if (title.contains('spa') || title.contains('baño')) return '🛁';
    if (title.contains('meditación') || title.contains('laguna')) return '🧘';
    if (title.contains('runner') || title.contains('cristo')) return '🏃';
    if (title.contains('fotografía') || title.contains('foto')) return '📸';
    if (title.contains('cocinar') || title.contains('receta')) return '👨‍🍳';
    if (title.contains('incachaca') || title.contains('cascada')) return '🏞️';
    if (title.contains('limpiar') || title.contains('ordenar')) return '🧹';
    return defaultEmoji;
  }

  static DateTime parseDate(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) {
      final parsed = DateTime.tryParse(timestamp);
      if (parsed != null) return parsed;
    }
    if (timestamp is int) {
      if (timestamp < 10000000000) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
      }
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
    }
    return DateTime.now();
  }
}