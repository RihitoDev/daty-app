enum AchievementMode { solo, couple, group, general }

class AchievementDefinition {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final String colorName; 
  final AchievementMode mode;
  final int requiredValue;

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