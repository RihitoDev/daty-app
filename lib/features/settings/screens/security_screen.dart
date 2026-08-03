import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'add_password_screen.dart';
import 'delete_account_screen.dart';

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
              title: Text(
                  usesPassword
                      ? 'Cambiar contraseña'
                      : 'Agregar contraseña para Daty',
                  style: TextStyle(color: colors.text)),
              subtitle: Text(
                usesPassword
                    ? 'Recibirás un enlace seguro en tu correo.'
                    : 'Entra con Google o con tu correo y una contraseña.',
                style: TextStyle(color: colors.text2),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.muted),
              onTap: usesPassword
                  ? () => _sendPasswordReset(context, auth)
                  : providers.contains('google.com')
                      ? () => _openAddPassword(context)
                      : null,
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
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Zona de peligro',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Card(
            color: colors.card,
            child: ListTile(
              leading: const Icon(
                Icons.delete_forever_outlined,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Eliminar cuenta',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Elimina permanentemente tu información',
                style: TextStyle(color: colors.text2),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.muted),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              ),
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

  Future<void> _openAddPassword(BuildContext context) async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddPasswordScreen(),
      ),
    );

    if (!context.mounted || added != true) return;
    CustomSnackBar.showSuccess(
      context,
      'Ya puedes entrar con Google o con correo y contraseña.',
    );
  }
}
