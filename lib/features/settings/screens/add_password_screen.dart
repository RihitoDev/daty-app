import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../auth/providers/auth_provider.dart';

class AddPasswordScreen extends StatefulWidget {
  const AddPasswordScreen({super.key});

  @override
  State<AddPasswordScreen> createState() => _AddPasswordScreenState();
}

class _AddPasswordScreenState extends State<AddPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _showPassword = false;
  bool _showConfirmation = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Escribe una contraseña';
    if (password.contains(RegExp(r'\s'))) {
      return 'La contraseña no puede contener espacios';
    }
    if (password.length < 6) return 'Usa al menos 6 caracteres';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    final auth = context.read<AuthProvider>();
    final result = await auth.addPasswordToGoogleAccount(
      _passwordController.text,
    );

    if (!mounted) return;

    if (result == null || result == 'provider-already-linked') {
      Navigator.pop(context, true);
      return;
    }

    final message = switch (result) {
      'cancelled' => 'Debes confirmar tu identidad con Google.',
      'user-mismatch' => 'Selecciona la misma cuenta de Google de Daty.',
      'credential-already-in-use' ||
      'email-already-in-use' =>
        'Este correo ya está vinculado a otra cuenta.',
      'weak-password' => 'La contraseña es demasiado débil.',
      'invalid-password' => 'La contraseña no puede contener espacios.',
      _ => 'No se pudo agregar la contraseña. Inténtalo nuevamente.',
    };

    CustomSnackBar.showError(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: colors.bg,
      appBar: AppBar(
        title: Text(
          'Agregar contraseña',
          style: TextStyle(color: colors.text),
        ),
        backgroundColor: colors.card,
        iconTheme: IconThemeData(color: colors.text),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  color: colors.card,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: colors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Agrega una contraseña para tener otra forma de '
                            'entrar a Daty. Podrás iniciar sesión con Google o '
                            'usando tu correo y esta contraseña. Tu cuenta, '
                            'progreso y datos seguirán siendo los mismos.',
                            style: TextStyle(color: colors.text2, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _passwordField(
                  controller: _passwordController,
                  label: 'Nueva contraseña',
                  visible: _showPassword,
                  onVisibilityChanged: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                  colors: colors,
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                _passwordField(
                  controller: _confirmationController,
                  label: 'Confirmar contraseña',
                  visible: _showConfirmation,
                  onVisibilityChanged: () {
                    setState(
                      () => _showConfirmation = !_showConfirmation,
                    );
                  },
                  colors: colors,
                  validator: (value) {
                    final passwordError = _validatePassword(value);
                    if (passwordError != null) return passwordError;
                    if (value != _passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'Antes de guardarla, te pediremos confirmar tu identidad con Google.',
                  style: TextStyle(color: colors.text2, fontSize: 13),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _submit,
                    icon: isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.card,
                            ),
                          )
                        : const Icon(Icons.g_mobiledata),
                    label: Text(
                      isLoading
                          ? 'Verificando…'
                          : 'Confirmar con Google y guardar',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.card,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String label,
    required bool visible,
    required VoidCallback onVisibilityChanged,
    required AppCustomTheme colors,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: !visible,
      autocorrect: false,
      enableSuggestions: false,
      inputFormatters: [
        FilteringTextInputFormatter.deny(RegExp(r'\s')),
      ],
      validator: validator,
      style: TextStyle(color: colors.text),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.text2),
        prefixIcon: Icon(Icons.lock_outline, color: colors.muted),
        suffixIcon: IconButton(
          onPressed: onVisibilityChanged,
          icon: Icon(
            visible ? Icons.visibility_off : Icons.visibility,
            color: colors.muted,
          ),
        ),
        filled: true,
        fillColor: colors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
