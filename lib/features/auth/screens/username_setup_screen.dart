import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final displayName =
        context.read<AuthProvider>().user?.displayName?.trim() ?? '';
    _usernameController = TextEditingController(text: displayName);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await context
        .read<AuthProvider>()
        .completeProfile(_usernameController.text);

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      if (result == 'username-taken') {
        _errorMessage = 'Ese nombre de usuario ya está en uso.';
      } else if (result != null) {
        _errorMessage = 'No pudimos guardar tu perfil. Inténtalo nuevamente.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [customTheme.primaryLight, customTheme.bg],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 72,
                        color: customTheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Elige tu nombre en Daty',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: customTheme.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Así te reconocerán las personas con las que compartas aventuras.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: customTheme.text2, height: 1.4),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _usernameController,
                        autofocus: true,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(40),
                          _singleSpaceFormatter,
                        ],
                        onChanged: (_) {
                          if (_errorMessage != null) {
                            setState(() => _errorMessage = null);
                          }
                        },
                        onFieldSubmitted: (_) => _submit(),
                        validator: (value) {
                          final username = value?.trim() ?? '';
                          if (username.isEmpty) {
                            return 'Escribe un nombre de usuario';
                          }
                          if (RegExp(r'\s').allMatches(username).length > 1) {
                            return 'Usa como máximo un espacio';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: 'Nombre de usuario',
                          errorText: _errorMessage,
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: customTheme.primary,
                            foregroundColor: customTheme.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Continuar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _isSubmitting
                            ? null
                            : () => context.read<AuthProvider>().signOut(),
                        child: const Text('Cerrar sesión'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static final TextInputFormatter _singleSpaceFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized = newValue.text.replaceAll(RegExp(r'\s'), ' ');
    if (RegExp(' ').allMatches(normalized).length > 1) return oldValue;
    return newValue.copyWith(text: normalized);
  });
}
