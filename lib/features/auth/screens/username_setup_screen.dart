import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/username_rules.dart';

enum _UsernameStatus { idle, checking, taken, error }

class UsernameSetupScreen extends StatefulWidget {
  const UsernameSetupScreen({super.key});

  @override
  State<UsernameSetupScreen> createState() => _UsernameSetupScreenState();
}

class _UsernameSetupScreenState extends State<UsernameSetupScreen> {
  final _usernameController = TextEditingController();
  bool _isSubmitting = false;
  _UsernameStatus _status = _UsernameStatus.idle;
  String? _statusMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    return UsernameRules.validationMessage(value ?? '');
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final validationError = _validateUsername(_usernameController.text);
    if (validationError != null) {
      setState(() {
        _status = _UsernameStatus.error;
        _statusMessage = validationError;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _status = _UsernameStatus.checking;
      _statusMessage = 'Comprobando disponibilidad...';
    });

    final result = await context
        .read<AuthProvider>()
        .completeProfile(_usernameController.text);

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
      if (result == 'username-taken') {
        _status = _UsernameStatus.taken;
        _statusMessage = 'Ese nombre ya está en uso. Prueba con otro.';
      } else if (result == 'invalid-username') {
        _status = _UsernameStatus.error;
        _statusMessage = 'Elige un nombre de usuario válido.';
      } else if (result != null) {
        _status = _UsernameStatus.error;
        _statusMessage = 'No pudimos guardar tu perfil. Inténtalo nuevamente.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.watch<ThemeProvider>().currentTheme;
    final user = context.watch<AuthProvider>().user;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.bg,
        body: Stack(
          children: [
            Positioned(
              top: -110,
              right: -90,
              child: _glow(colors.primary, 270),
            ),
            Positioned(
              bottom: -130,
              left: -100,
              child: _glow(colors.accent, 250),
            ),
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/images/mascot.png',
                          height: 125,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '¿Cómo quieres que te llamemos?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.text,
                            fontSize: 28,
                            height: 1.12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Este será tu nombre dentro de Daty. Podrás cambiarlo más adelante desde tu perfil.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.text2,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 26),
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: colors.card,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: .12),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: .12),
                                blurRadius: 30,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Form(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (user?.email != null) ...[
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: colors.primaryLight,
                                        backgroundImage: user?.photoURL != null
                                            ? NetworkImage(user!.photoURL!)
                                            : null,
                                        child: user?.photoURL == null
                                            ? Icon(
                                                Icons.person_rounded,
                                                color: colors.primary,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 11),
                                      Expanded(
                                        child: Text(
                                          user!.email!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: colors.text2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.verified_rounded,
                                        size: 20,
                                        color: colors.primary,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 22),
                                ],
                                Text(
                                  'Tu nombre en Daty',
                                  style: TextStyle(
                                    color: colors.text,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 9),
                                TextField(
                                  controller: _usernameController,
                                  autofocus: false,
                                  enabled: !_isSubmitting,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.done,
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(
                                      UsernameRules.maxLength,
                                    ),
                                    _threeSpacesFormatter,
                                  ],
                                  onChanged: (_) {
                                    if (_status != _UsernameStatus.idle) {
                                      setState(() {
                                        _status = _UsernameStatus.idle;
                                        _statusMessage = null;
                                      });
                                    }
                                  },
                                  onSubmitted:
                                      _isSubmitting ? null : (_) => _submit(),
                                  decoration: InputDecoration(
                                    hintText: 'Escribe tu nombre',
                                    prefixIcon: const Icon(
                                        Icons.alternate_email_rounded),
                                    filled: true,
                                    fillColor: colors.bg.withValues(alpha: .65),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(17),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(17),
                                      borderSide: BorderSide(
                                        color:
                                            colors.muted.withValues(alpha: .18),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(17),
                                      borderSide: BorderSide(
                                        color: colors.primary,
                                        width: 1.6,
                                      ),
                                    ),
                                  ),
                                ),
                                // La altura siempre está reservada para evitar
                                // que el botón salte cuando aparece un mensaje.
                                SizedBox(
                                  height: 46,
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: _statusMessage == null
                                        ? const SizedBox.expand()
                                        : Row(
                                            key: ValueKey(_status),
                                            children: [
                                              if (_status ==
                                                  _UsernameStatus.checking)
                                                const SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                  ),
                                                )
                                              else
                                                Icon(
                                                  _status ==
                                                          _UsernameStatus.taken
                                                      ? Icons.cancel_outlined
                                                      : Icons
                                                          .error_outline_rounded,
                                                  size: 18,
                                                  color: Colors.redAccent,
                                                ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _statusMessage!,
                                                  style: TextStyle(
                                                    color: _status ==
                                                            _UsernameStatus
                                                                .checking
                                                        ? colors.text2
                                                        : Colors.redAccent,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                SizedBox(
                                  width: double.infinity,
                                  height: 54,
                                  child: FilledButton(
                                    onPressed: _isSubmitting ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.primary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(17),
                                      ),
                                    ),
                                    child: _isSubmitting
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () => context.read<AuthProvider>().signOut(),
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          label: const Text('Usar otra cuenta'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glow(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: .10),
      ),
    );
  }

  static final TextInputFormatter _threeSpacesFormatter =
      TextInputFormatter.withFunction((oldValue, newValue) {
    final normalized = newValue.text.replaceAll(RegExp(r'\s'), ' ');
    if (RegExp(' ').allMatches(normalized).length > 3) return oldValue;
    return newValue.copyWith(text: normalized);
  });
}
