import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  bool _privateProfile = true;
  bool _shareActivity = true;
  bool _allowLocation = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _privateProfile = prefs.getBool('privacy_private_profile') ?? true;
      _shareActivity = prefs.getBool('privacy_share_activity') ?? true;
      _allowLocation = prefs.getBool('privacy_allow_location') ?? false;
    });
  }

  Future<void> _set(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'privacy': {
          'privateProfile': _privateProfile,
          'shareActivity': _shareActivity,
          'allowLocation': _allowLocation,
        },
      }, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Privacidad', style: TextStyle(color: colors.text)),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _switch(
            'Cuenta privada',
            'Solo las personas vinculadas contigo podrán ver tu actividad.',
            Icons.lock_outline,
            _privateProfile,
            (value) {
              setState(() => _privateProfile = value);
              _set('privacy_private_profile', value);
            },
          ),
          _switch(
            'Compartir actividad',
            'Permite mostrar avances de aventura a tu pareja.',
            Icons.visibility_outlined,
            _shareActivity,
            (value) {
              setState(() => _shareActivity = value);
              _set('privacy_share_activity', value);
            },
          ),
          _switch(
            'Datos de ubicación',
            'Autoriza usar ubicación únicamente en funciones que la necesiten.',
            Icons.location_on_outlined,
            _allowLocation,
            (value) {
              setState(() => _allowLocation = value);
              _set('privacy_allow_location', value);
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Estas preferencias quedan guardadas en tu cuenta. Cada función también solicitará el permiso correspondiente del teléfono.',
            style: TextStyle(color: colors.text2, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _switch(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
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
