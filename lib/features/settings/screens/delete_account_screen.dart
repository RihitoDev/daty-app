import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../auth/providers/auth_provider.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirmationController = TextEditingController();
  bool _isDeleting = false;

  bool get _confirmationIsValid =>
      _confirmationController.text.trim().toUpperCase() == 'ELIMINAR';

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    final auth = context.watch<AuthProvider>();

    return PopScope(
      canPop: !_isDeleting,
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          title: const Text('Eliminar cuenta'),
          backgroundColor: colors.card,
          iconTheme: IconThemeData(color: colors.text),
        ),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 64,
              color: Colors.redAccent,
            ),
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
              'Se eliminarán tu perfil, fotos, progreso, recuerdos y vínculos. Esta acción no se puede deshacer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.text2, height: 1.5),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _confirmationController,
              enabled: !_isDeleting,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Escribe ELIMINAR para confirmar',
                helperText: 'La palabra debe coincidir exactamente.',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: !_confirmationIsValid || _isDeleting
                  ? null
                  : () => _confirmDeletion(auth),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
                minimumSize: const Size.fromHeight(54),
              ),
              child: _isDeleting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletion(AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_forever_outlined,
          color: Colors.redAccent,
          size: 42,
        ),
        title: const Text('¿Estás seguro?'),
        content: const Text(
          'Si aceptas, se eliminarán permanentemente tu cuenta, progreso, '
          'fotos, recuerdos y vínculos. Esta acción no se puede deshacer.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, eliminar todo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    FocusScope.of(context).unfocus();
    setState(() => _isDeleting = true);
    final error = await auth.deleteAccount();
    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (error == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    CustomSnackBar.showError(
      context,
      'No se pudo eliminar la cuenta. Inténtalo nuevamente.',
    );
  }
}
