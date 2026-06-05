import 'package:flutter/material.dart';

// Este traductor convierte los nombres en texto que tenemos en los datos a íconos y colores reales que Flutter entiende
class AchievementMapper {
  static IconData getIcon(String iconName) {
    switch (iconName) {
      case 'waving_hand': return Icons.waving_hand;
      case 'link': return Icons.link;
      case 'star': return Icons.star;
      case 'emoji_events': return Icons.emoji_events;
      case 'backpack': return Icons.backpack;
      case 'hiking': return Icons.hiking;
      case 'explore': return Icons.explore;
      case 'favorite': return Icons.favorite;
      case 'history_edu': return Icons.history_edu;
      case 'local_florist': return Icons.local_florist;
      case 'volunteer_activism': return Icons.volunteer_activism;
      case 'diamond': return Icons.diamond;
      case 'groups': return Icons.groups;
      case 'celebration': return Icons.celebration;
      case 'party_mode': return Icons.party_mode;
      // Ícono de ayuda por si llega un nombre que no tenemos registrado
      default: return Icons.help_outline; 
    }
  }

  static Color getColor(String colorName) {
    switch (colorName) {
      case 'teal': return Colors.teal;
      case 'pink': return Colors.pink;
      case 'amber': return Colors.amber;
      case 'deepPurple': return Colors.deepPurple;
      case 'blue': return Colors.blue;
      case 'indigo': return Colors.indigo;
      case 'lightBlue': return Colors.lightBlue;
      case 'red': return Colors.red;
      case 'purple': return Colors.purple;
      case 'deepOrange': return Colors.deepOrange;
      case 'green': return Colors.green;
      case 'lime': return Colors.lime;
      case 'orange': return Colors.orange;
      // Color gris de emergencia si el nombre no coincide con nada
      default: return Colors.grey; 
    }
  }
}