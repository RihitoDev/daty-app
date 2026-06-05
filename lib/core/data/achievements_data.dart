import '../models/achievement_definition.dart';

class AchievementsData {
  // Lista maestra con todos los logros del app. Aquí definimos el nombre, el ícono, el color y lo que se necesita para desbloquear cada uno.
  static List<AchievementDefinition> get allAchievements => [
    
    const AchievementDefinition(
      id: 'gen_welcome', 
      title: 'Primer Pasos', 
      description: 'Crear tu cuenta en Daty', 
      iconName: 'waving_hand', 
      colorName: 'teal', 
      mode: AchievementMode.general, 
      requiredValue: 1
    ),
    const AchievementDefinition(
      id: 'gen_link', 
      title: 'Media Naranja', 
      description: 'Vincularte con tu pareja por primera vez', 
      iconName: 'link', 
      colorName: 'pink', 
      mode: AchievementMode.general, 
      requiredValue: 1
    ),
    const AchievementDefinition(
      id: 'gen_level5', 
      title: 'Aventurero Novato', 
      description: 'Alcanzar el Nivel 5', 
      iconName: 'star', 
      colorName: 'amber', 
      mode: AchievementMode.general, 
      requiredValue: 5
    ),
    const AchievementDefinition(
      id: 'gen_level10', 
      title: 'Explorador Experto', 
      description: 'Alcanzar el Nivel 10', 
      iconName: 'emoji_events', 
      colorName: 'deepPurple', 
      mode: AchievementMode.general, 
      requiredValue: 10
    ),

    const AchievementDefinition(
      id: 'solo_first', 
      title: 'Vuelo Solo', 
      description: 'Completar tu primera aventura individual', 
      iconName: 'backpack', 
      colorName: 'blue', 
      mode: AchievementMode.solo, 
      requiredValue: 1
    ),
    const AchievementDefinition(
      id: 'solo_5', 
      title: 'Lobo Solitario', 
      description: 'Completar 5 aventuras individuales', 
      iconName: 'hiking', 
      colorName: 'indigo', 
      mode: AchievementMode.solo, 
      requiredValue: 5
    ),
    const AchievementDefinition(
      id: 'solo_15', 
      title: 'Explorador Intrépido', 
      description: 'Completar 15 aventuras individuales', 
      iconName: 'explore', 
      colorName: 'lightBlue', 
      mode: AchievementMode.solo, 
      requiredValue: 15
    ),

    const AchievementDefinition(
      id: 'couple_first', 
      title: 'Chispa Inicial', 
      description: 'Completar la primera cita en el mapa', 
      iconName: 'favorite', 
      colorName: 'red', 
      mode: AchievementMode.couple, 
      requiredValue: 1
    ),
    const AchievementDefinition(
      id: 'couple_contract', 
      title: 'Pacto de Amor', 
      description: 'Firmar el contrato de 100 citas', 
      iconName: 'history_edu', 
      colorName: 'purple', 
      mode: AchievementMode.couple, 
      requiredValue: 1
    ),
    const AchievementDefinition(
      id: 'couple_10', 
      title: 'Novios Románticos', 
      description: 'Completar 10 citas de pareja', 
      iconName: 'local_florist', 
      colorName: 'pink', 
      mode: AchievementMode.couple, 
      requiredValue: 10
    ),
    const AchievementDefinition(
      id: 'couple_25', 
      title: 'Amor Consolidado', 
      description: 'Completar 25 citas de pareja', 
      iconName: 'volunteer_activism', 
      colorName: 'deepOrange', 
      mode: AchievementMode.couple, 
      requiredValue: 25
    ),
    const AchievementDefinition(
      id: 'couple_50', 
      title: 'Leyenda del Amor', 
      description: 'Completar las 50 citas del mapa', 
      iconName: 'diamond', 
      colorName: 'deepPurple', 
      mode: AchievementMode.couple, 
      requiredValue: 50
    ),

    const AchievementDefinition(
      id: 'group_first', 
      title: 'La Banda Se Reúne', 
      description: 'Planificar tu primera salida grupal', 
      iconName: 'groups', 
      colorName: 'green', 
      mode: AchievementMode.group, 
      requiredValue: 1
    ),
    const AchievementDefinition(
      id: 'group_5', 
      title: 'Alma Social', 
      description: 'Planificar 5 salidas grupales', 
      iconName: 'celebration', 
      colorName: 'lime', 
      mode: AchievementMode.group, 
      requiredValue: 5
    ),
    const AchievementDefinition(
      id: 'group_10', 
      title: 'El Anfitrión', 
      description: 'Planificar 10 salidas grupales', 
      iconName: 'party_mode', 
      colorName: 'orange', 
      mode: AchievementMode.group, 
      requiredValue: 10
    ),
  ];

  // Filtra la lista para devolver solo los logros de una categoría específica (general, solitario, etc.)
  static List<AchievementDefinition> getByMode(AchievementMode mode) {
    return allAchievements.where((ach) => ach.mode == mode).toList();
  }
}