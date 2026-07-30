import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: const Text('Eliminar cuenta'),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 64, color: Colors.redAccent),
          const SizedBox(height: 18),
          Text(
            'Esta acción será permanente',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.text,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Se eliminarán tu perfil, fotos, progreso y vínculos. Antes de activarla se implementará una función segura en Firebase que limpie todos esos datos.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.text2, height: 1.5),
          ),
          const SizedBox(height: 28),
          TextField(
            controller: _controller,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Escribe ELIMINAR para confirmar',
              helperText: 'Función pendiente de backend seguro.',
            ),
          ),
          const SizedBox(height: 20),
          const FilledButton(
            onPressed: null,
            child: Text('Eliminar mi cuenta'),
          ),
        ],
      ),
    );
  }
}
