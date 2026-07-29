import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../services/email_verification_code_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _codeController = TextEditingController();
  Timer? _countdownTimer;
  int _secondsUntilResend = 0;
  bool _isVerifying = false;
  bool _isSending = false;
  String? _message;
  bool _isError = false;

  bool get _isBusy => _isVerifying || _isSending;
  bool get _canResend => !_isBusy && _secondsUntilResend == 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sendCode(initial: true);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    setState(() => _secondsUntilResend = seconds.clamp(0, 60).toInt());

    if (_secondsUntilResend == 0) return;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsUntilResend <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsUntilResend = 0);
        return;
      }
      setState(() => _secondsUntilResend -= 1);
    });
  }

  int _retryAfterSeconds(dynamic details) {
    if (details is Map) {
      final value = details['retryAfterSeconds'];
      if (value is num) return value.ceil().clamp(1, 60).toInt();
    }
    return 60;
  }

  Future<void> _sendCode({bool initial = false}) async {
    if (_isSending || (!initial && !_canResend)) return;

    setState(() {
      _isSending = true;
      _message = null;
    });

    try {
      final result = await context.read<AuthProvider>().sendVerificationCode();

      if (!mounted) return;

      if (result.alreadyVerified) {
        await context.read<AuthProvider>().refreshCurrentUser();
        return;
      }

      final seconds = result.resendAvailableAt
          .difference(DateTime.now())
          .inSeconds
          .clamp(1, 60)
          .toInt();
      _startCountdown(seconds);
      setState(() {
        _isError = false;
        _message = initial
            ? 'Enviamos un código de 6 dígitos a tu correo.'
            : 'Enviamos un nuevo código. El anterior dejó de ser válido.';
      });
    } on EmailVerificationCodeException catch (error) {
      if (!mounted) return;

      if (error.code == 'resource-exhausted') {
        _startCountdown(_retryAfterSeconds(error.details));
        setState(() {
          _isError = false;
          _message = initial
              ? 'Ya enviamos un código. Revisa tu bandeja de entrada.'
              : 'Espera antes de solicitar un código nuevo.';
        });
      } else {
        setState(() {
          _isError = true;
          _message = _sendErrorMessage(error);
        });
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_isVerifying) return;

    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() {
        _isError = true;
        _message = 'Escribe los 6 dígitos del código.';
      });
      return;
    }

    setState(() {
      _isVerifying = true;
      _message = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final verified = await authProvider.verifyEmailCode(code);

      if (!mounted) return;
      if (!verified) {
        setState(() {
          _isError = true;
          _message =
              'Firebase todavía no refleja la verificación. Inténtalo nuevamente.';
        });
        return;
      }

      final reservedUsername = authProvider.user?.displayName?.trim() ?? '';
      if (reservedUsername.isNotEmpty && !authProvider.hasCompleteProfile) {
        final profileResult =
            await authProvider.createProfileAfterVerification(reservedUsername);

        if (!mounted) return;
        if (profileResult != null) {
          setState(() {
            _isError = true;
            _message =
                'El correo fue verificado, pero no pudimos completar tu perfil.';
          });
          return;
        }
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } on EmailVerificationCodeException catch (error) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message = _verificationErrorMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isError = true;
        _message =
            'No pudimos verificar el código. Revisa tu conexión e inténtalo nuevamente.';
      });
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  String _sendErrorMessage(EmailVerificationCodeException error) {
    final details = error.details;
    if (details is Map && details['reason'] == 'email-provider-rejected') {
      return 'Resend rechazó el envío. Si todavía usas el remitente de '
          'pruebas, prueba con el correo propietario de Resend o configura '
          'un dominio verificado.';
    }

    switch (error.code) {
      case 'unauthenticated':
        return 'Tu sesión terminó. Vuelve a iniciar sesión.';
      case 'failed-precondition':
        return 'La cuenta no tiene un correo disponible.';
      case 'internal':
        return 'No pudimos enviar el correo. Inténtalo nuevamente.';
      case 'unavailable':
        return 'No hay conexión con el servidor. Revisa tu internet.';
      default:
        return 'No pudimos enviar el código. Inténtalo nuevamente.';
    }
  }

  String _verificationErrorMessage(EmailVerificationCodeException error) {
    switch (error.code) {
      case 'invalid-argument':
        final details = error.details;
        if (details is Map && details['attemptsRemaining'] is num) {
          return 'Código incorrecto. Te quedan '
              '${details['attemptsRemaining']} intentos.';
        }
        return error.message;
      case 'deadline-exceeded':
        return 'El código venció. Solicita uno nuevo.';
      case 'resource-exhausted':
        return 'Se agotaron los intentos. Solicita un código nuevo.';
      case 'failed-precondition':
        return 'Solicita un código nuevo antes de verificar.';
      case 'unauthenticated':
        return 'Tu sesión terminó. Vuelve a iniciar sesión.';
      case 'unavailable':
        return 'No hay conexión con el servidor. Revisa tu internet.';
      default:
        return 'No pudimos verificar el código. Inténtalo nuevamente.';
    }
  }

  Future<void> _signOut() async {
    if (_isBusy) return;
    await context.read<AuthProvider>().signOut();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final customTheme = context.watch<ThemeProvider>().currentTheme;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _signOut();
      },
      child: Scaffold(
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
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Cerrar sesión',
                          onPressed: _isBusy ? null : _signOut,
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: customTheme.text,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.mark_email_unread_outlined,
                        size: 82,
                        color: customTheme.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Verifica tu correo',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: customTheme.text,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Escribe el código que enviamos a',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: customTheme.text2),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: customTheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _codeController,
                        enabled: !_isBusy,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        onChanged: (_) {
                          if (_message != null && _isError) {
                            setState(() => _message = null);
                          }
                        },
                        onSubmitted: (_) => _verifyCode(),
                        style: TextStyle(
                          color: customTheme.text,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 10,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '000000',
                          filled: true,
                          fillColor: customTheme.card.withValues(alpha: 0.85),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                      if (_message != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _message!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _isError
                                ? customTheme.accent
                                : customTheme.text2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isBusy ? null : _verifyCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: customTheme.primary,
                            foregroundColor: customTheme.card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: _isVerifying
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Verificar',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _canResend ? () => _sendCode() : null,
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                ),
                              )
                            : Text(
                                _secondsUntilResend > 0
                                    ? 'Reenviar código en '
                                        '${_secondsUntilResend}s'
                                    : 'Reenviar código',
                              ),
                      ),
                      TextButton(
                        onPressed: _isBusy ? null : _signOut,
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
}
