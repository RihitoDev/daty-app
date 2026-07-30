import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/theme_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _adventures = true;
  bool _couple = true;
  bool _memories = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _adventures = prefs.getBool('notifications_adventures') ?? true;
      _couple = prefs.getBool('notifications_couple') ?? true;
      _memories = prefs.getBool('notifications_memories') ?? true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Notificaciones', style: TextStyle(color: colors.text)),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _tile('Nuevas aventuras', 'Recomendaciones y novedades',
              Icons.explore_outlined, _adventures, (value) {
            setState(() => _adventures = value);
            _save('notifications_adventures', value);
          }),
          _tile('Actividad de pareja', 'Invitaciones y avances compartidos',
              Icons.favorite_border, _couple, (value) {
            setState(() => _couple = value);
            _save('notifications_couple', value);
          }),
          _tile('Recuerdos', 'Recordatorios de momentos especiales',
              Icons.photo_outlined, _memories, (value) {
            setState(() => _memories = value);
            _save('notifications_memories', value);
          }),
        ],
      ),
    );
  }

  Widget _tile(String title, String subtitle, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    return Card(
      color: colors.card,
      margin: const EdgeInsets.only(bottom: 12),
      child: SwitchListTile(
        secondary: Icon(icon, color: colors.primary),
        title: Text(title, style: TextStyle(color: colors.text)),
        subtitle: Text(subtitle, style: TextStyle(color: colors.text2)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
