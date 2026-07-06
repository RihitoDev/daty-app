import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../../../core/validators/email_validator.dart';

class ResetPasswordDialog extends StatefulWidget {
  const ResetPasswordDialog({super.key});

  @override
  State<ResetPasswordDialog> createState() =>
      _ResetPasswordDialogState();
}

class _ResetPasswordDialogState
    extends State<ResetPasswordDialog> {

  final TextEditingController _emailController =
      TextEditingController();

  String? _dialogError;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customTheme =
        Provider.of<ThemeProvider>(context).currentTheme;

    return AlertDialog(
      backgroundColor: customTheme.card,
      shape: RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(20),
),
title: Row(
  children: [
    Icon(
      Icons.lock_outline,
      color: customTheme.primary,
    ),
    const SizedBox(width: 10),
    Text(
      'Recuperar Contraseña',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: customTheme.text,
      ),
    ),
  ],
),
      content: Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      'Ingresa tu correo y te enviaremos un enlace para restablecer tu contraseña.',
      style: TextStyle(color: customTheme.text2),
    ),
    const SizedBox(height: 15),
    TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: customTheme.text),
      decoration: InputDecoration(
        hintText: 'correo@ejemplo.com',
        hintStyle: TextStyle(color: customTheme.muted),
        prefixIcon: Icon(
          Icons.email_outlined,
          color: customTheme.muted,
        ),
        errorText: _dialogError,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: customTheme.muted.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(
            color: customTheme.primary,
          ),
        ),
      ),
      onChanged: (_) {
        if (_dialogError != null) {
          setState(() {
            _dialogError = null;
          });
        }
      },
    ),
  ],
),
actions: [
  TextButton(
    onPressed: () {
      Navigator.pop(context);
    },
    child: Text(
      'Cancelar',
      style: TextStyle(color: customTheme.text2),
    ),
  ),
  ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: customTheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    ),
    onPressed: () async {
  final email = _emailController.text.trim();

final error = EmailValidator.validate(email);

if (error != null) {
  setState(() {
    _dialogError = error;
  });
  return;
}

  // Aquí conectaremos Firebase en el siguiente paso.
  final authProvider = Provider.of<AuthProvider>(
  context,
  listen: false,
);

final result = await authProvider.resetPassword(email);

if (!mounted) return;

if (result == null) {
  Navigator.pop(context);

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Correo enviado'),
      content: const Text(
        'Revisa tu bandeja de entrada para restablecer tu contraseña.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
} else {
  setState(() {
    _dialogError = result == 'not-found'
        ? 'No existe una cuenta con ese correo.'
        : 'Ocurrió un error. Inténtalo nuevamente.';
  });
}
},
    child: Text(
      'Enviar',
      style: TextStyle(color: customTheme.card),
    ),
  ),
],
    );
  }
}