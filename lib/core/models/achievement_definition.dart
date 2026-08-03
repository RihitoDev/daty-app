// Las categorías en las que se dividen los logros
enum AchievementMode { solo, couple, group, general }

// El grado de rareza o dificultad del logro
enum AchievementRarity { common, rare, epic, legendary }

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final String colorName;
  final AchievementMode mode;
  final AchievementRarity rarity;
  final int unlockPercentage; // Porcentaje global de jugadores que tienen el logro
  final String categoryTag; // Etiqueta descriptiva (ej: Fotografía, Progreso, Social)
  final int requiredValue;

  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.colorName,
    required this.mode,
    required this.rarity,
    required this.unlockPercentage,
    required this.categoryTag,
    required this.requiredValue,
  });

  String get rarityLabel {
    switch (rarity) {
      case AchievementRarity.common:
        return 'Común';
      case AchievementRarity.rare:
        return 'Raro';
      case AchievementRarity.epic:
        return 'Épico';
      case AchievementRarity.legendary:
        return 'Legendario';
    }
  }
}