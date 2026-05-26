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
}