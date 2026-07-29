import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;
  bool _isError = false;

  Future<void> _checkVerification() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _message = null;
    });

    final authProvider = context.read<AuthProvider>();

    final verified = await authProvider.refreshCurrentUser();

    if (!mounted) return;

    if (!verified) {
      setState(() {
        _isChecking = false;
        _isError = true;
        _message =
            'Tu correo todavía no ha sido verificado. Abre el enlace que enviamos y vuelve a intentarlo.';
      });
      return;
    }

    final username = authProvider.user?.displayName?.trim() ?? '';

    final result = await authProvider.createProfileAfterVerification(username);

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _isChecking = false;
        _isError = true;

        if (result == 'not-verified') {
          _message = 'Tu correo todavía no está verificado.';
        } else if (result == 'no-user') {
          _message = 'No encontramos una sesión activa.';
        } else {
          _message = 'No se pudo crear tu perfil. Inténtalo nuevamente.';
        }
      });
      return;
    }

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _resendVerification() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
      _message = null;
    });

    final result = await context.read<AuthProvider>().resendVerificationEmail();

    if (!mounted) return;

    if (result == null) {
      setState(() {
        _isResending = false;
        _isError = false;
        _message = 'Enviamos un nuevo enlace de verificación a tu correo.';
      });
      return;
    }

    setState(() {
      _isResending = false;
      _isError = true;

      if (result == 'too-many-requests') {
        _message = 'Has solicitado demasiados correos. Espera unos minutos.';
      } else if (result == 'no-user') {
        _message = 'No encontramos una sesión activa.';
      } else {
        _message = 'No pudimos reenviar el correo. Inténtalo nuevamente.';
      }
    });
  }

  Future<void> _returnToLogin() async {
    final authProvider = context.read<AuthProvider>();

    final result = await authProvider.deletePendingAccount();

    if (!mounted) return;

    if (result != null && result != 'no-user' && result != 'already-verified') {
      setState(() {
        _isError = true;

        if (result == 'requires-recent-login') {
          _message =
              'No pudimos cancelar el registro automáticamente. Inténtalo nuevamente.';
        } else {
          _message = 'No pudimos cancelar el registro. Inténtalo nuevamente.';
        }
      });
      return;
    }

    if (result == 'already-verified') {
      await authProvider.signOut();
    }

    if (!mounted) return;

    // No abrir LoginScreen manualmente.
    // AuthWrapper lo mostrará porque ya no existe una sesión.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<bool> _handleBack() async {
    await _returnToLogin();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                customTheme.primaryLight,
                customTheme.bg,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: _returnToLogin,
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: customTheme.text,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: customTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread_outlined,
                      size: 58,
                      color: customTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Verifica tu correo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: customTheme.text,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Enviamos un enlace de verificación a:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: customTheme.text2,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.email,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: customTheme.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Abre el mensaje, confirma tu correo y luego vuelve aquí para continuar.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: customTheme.text2,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (_message != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: _isError
                            ? customTheme.accent.withValues(alpha: 0.1)
                            : customTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isError
                              ? customTheme.accent.withValues(alpha: 0.3)
                              : customTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isError
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            color: _isError
                                ? customTheme.accent
                                : customTheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(
                                color: customTheme.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isChecking ? null : _checkVerification,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isChecking
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: customTheme.card,
                                strokeWidth: 3,
                              ),
                            )
                          : Text(
                              'Ya verifiqué mi correo',
                              style: TextStyle(
                                color: customTheme.card,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isResending ? null : _resendVerification,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: customTheme.primary,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: _isResending
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: customTheme.primary,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              'Reenviar correo',
                              style: TextStyle(
                                color: customTheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _returnToLogin,
                    child: Text(
                      'Cambiar correo',
                      style: TextStyle(
                        color: customTheme.text2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
