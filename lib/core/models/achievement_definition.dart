// Las categorías en las que se dividen los logros
enum AchievementMode { solo, couple, group, general }

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  
  // Guardamos los nombres como texto y luego los convertimos en íconos y colores reales usando el AchievementMapper
  final String iconName;
  final String colorName; 
  
  final AchievementMode mode;
  final int requiredValue; // La meta que hay que alcanzar para desbloquear el logro

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.colorName,
    required this.mode,
    required this.requiredValue,
  });
}