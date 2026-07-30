import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    final auth = context.watch<AuthProvider>();
    final providers = auth.user?.providerData
            .map((provider) => provider.providerId)
            .toSet() ??
        {};
    final usesPassword = providers.contains('password');
    final methods = [
      if (providers.contains('google.com')) 'Google',
      if (usesPassword) 'Correo y contraseña',
    ].join(' · ');

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text('Seguridad', style: TextStyle(color: colors.text)),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: colors.card,
            child: ListTile(
              leading:
                  Icon(Icons.verified_user_outlined, color: colors.primary),
              title:
                  Text('Autenticación', style: TextStyle(color: colors.text)),
              subtitle: Text(
                methods.isEmpty ? 'Método no identificado' : methods,
                style: TextStyle(color: colors.text2),
              ),
            ),
          ),
          Card(
            color: colors.card,
            child: ListTile(
              leading: Icon(Icons.password_rounded, color: colors.primary),
              title: Text('Cambiar contraseña',
                  style: TextStyle(color: colors.text)),
              subtitle: Text(
                usesPassword
                    ? 'Recibirás un enlace seguro en tu correo.'
                    : 'Tu contraseña es administrada por Google.',
                style: TextStyle(color: colors.text2),
              ),
              trailing: usesPassword
                  ? Icon(Icons.chevron_right, color: colors.muted)
                  : null,
              onTap:
                  usesPassword ? () => _sendPasswordReset(context, auth) : null,
            ),
          ),
          Card(
            color: colors.card,
            child: ListTile(
              leading: Icon(Icons.devices_outlined, color: colors.primary),
              title: Text('Sesiones activas',
                  style: TextStyle(color: colors.text)),
              subtitle: Text(
                'Este dispositivo está conectado. La gestión remota se habilitará con el backend de seguridad.',
                style: TextStyle(color: colors.text2),
              ),
              trailing: const Chip(label: Text('Actual')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPasswordReset(
    BuildContext context,
    AuthProvider auth,
  ) async {
    final email = auth.user?.email;
    if (email == null) return;
    final error = await auth.resetPassword(email);
    if (!context.mounted) return;
    if (error == null) {
      CustomSnackBar.showSuccess(context, 'Enlace enviado a $email');
    } else {
      CustomSnackBar.showError(context, 'No se pudo enviar el enlace');
    }
  }
}
