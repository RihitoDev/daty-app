import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/pressable_scale.dart';

class PersonalVaultLoginDialog extends StatefulWidget {
  final String correctPin;

  const PersonalVaultLoginDialog({
    super.key,
    required this.correctPin,
  });

  @override
  State<PersonalVaultLoginDialog> createState() => _PersonalVaultLoginDialogState();
}

class _PersonalVaultLoginDialogState extends State<PersonalVaultLoginDialog> {
  String _enteredPin = '';
  bool _isRecovering = false;

  List<Map<String, dynamic>> _securityQuestions = [];
  int _selectedQuestionIndex = 0;
  final _answerCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();

  bool _isLoadingQuestions = false;
  bool _questionVerified = false;
  bool _isResettingPin = false;

  @override
  void dispose() {
    _answerCtrl.dispose();
    _newPinCtrl.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
      });
      if (_enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (!mounted) return;
          if (_enteredPin == widget.correctPin) {
            Navigator.pop(context, true);
          } else {
            CustomSnackBar.showError(context, 'PIN incorrecto');
            setState(() {
              _enteredPin = '';
            });
          }
        });
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      });
    }
  }

  Future<void> _startRecovery() async {
    setState(() {
      _isRecovering = true;
      _isLoadingQuestions = true;
    });

    try {
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
      final doc = await FirebaseFirestore.instance.collection('users').doc(myUid).get();

      if (doc.exists && doc.data()?['securityQuestions'] != null) {
        final rawList = doc.data()!['securityQuestions'] as List<dynamic>;
        setState(() {
          _securityQuestions = List<Map<String, dynamic>>.from(rawList);
          _selectedQuestionIndex = 0;
        });
      } else {
        if (mounted) {
          CustomSnackBar.showError(context, 'No se encontraron preguntas de seguridad');
          setState(() => _isRecovering = false);
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al cargar preguntas de seguridad');
        setState(() => _isRecovering = false);
      }
    } finally {
      if (mounted) setState(() => _isLoadingQuestions = false);
    }
  }

  void _verifyChosenQuestion() {
    if (_securityQuestions.isEmpty) return;

    final chosen = _securityQuestions[_selectedQuestionIndex];
    final correctAnswer = (chosen['answer'] ?? '').toString().toLowerCase();
    final userAnswer = _answerCtrl.text.trim().toLowerCase();

    if (userAnswer.isEmpty) {
      CustomSnackBar.showError(context, 'Por favor ingresa tu respuesta');
      return;
    }

    if (userAnswer == correctAnswer) {
      setState(() {
        _questionVerified = true;
      });
      CustomSnackBar.showSuccess(context, 'Respuesta correcta. Define tu nuevo PIN.');
    } else {
      CustomSnackBar.showError(context, 'Respuesta incorrecta. Inténtalo de nuevo.');
    }
  }

  Future<void> _resetPin() async {
    final newPin = _newPinCtrl.text.trim();
    if (newPin.length != 4 || int.tryParse(newPin) == null) {
      CustomSnackBar.showError(context, 'El PIN debe ser exactamente de 4 dígitos');
      return;
    }

    setState(() => _isResettingPin = true);

    try {
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;
      await FirebaseFirestore.instance.collection('users').doc(myUid).set({
        'personalVaultPin': newPin,
      }, SetOptions(merge: true));

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'PIN actualizado con éxito');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al guardar el nuevo PIN');
      }
    } finally {
      if (mounted) setState(() => _isResettingPin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().currentTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
        decoration: BoxDecoration(
          color: t.elevatedSurface,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.outline, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: t.shadow,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_rounded, color: t.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal',
                          style: TextStyle(
                            color: t.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isRecovering
                              ? 'Recuperación de PIN'
                              : 'Ingresa tu PIN de 4 dígitos',
                          style: TextStyle(
                            color: t.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: t.softSurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: t.outline),
                      ),
                      child: Icon(Icons.close_rounded, color: t.muted, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (!_isRecovering) _buildPinEntry(t) else _buildRecoveryFlow(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinEntry(AppCustomTheme t) {
    return Column(
      children: [
        // Indicadores de PIN
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _enteredPin.length;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isFilled ? t.primary : Colors.transparent,
                border: Border.all(
                  color: isFilled ? t.primary : t.outline,
                  width: 2,
                ),
                boxShadow: isFilled
                    ? [
                        BoxShadow(
                          color: t.primary.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
        const SizedBox(height: 28),

        // Teclado numérico circular con alto contraste
        SizedBox(
          width: 260,
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 3,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map(
                (digit) => _buildKeyButton(digit, () => _onKeyPress(digit), t),
              ),
              const SizedBox(),
              _buildKeyButton('0', () => _onKeyPress('0'), t),
              _buildBackspaceButton(t),
            ],
          ),
        ),

        const SizedBox(height: 20),
        TextButton(
          onPressed: _startRecovery,
          child: Text(
            '¿Olvidaste tu PIN?',
            style: TextStyle(
              color: t.primary,
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyButton(String text, VoidCallback onTap, AppCustomTheme t) {
    return PressableScale(
      scale: 0.92,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: t.softSurface,
          shape: BoxShape.circle,
          border: Border.all(color: t.outline),
          boxShadow: [
            BoxShadow(
              color: t.shadow,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: t.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceButton(AppCustomTheme t) {
    return PressableScale(
      scale: 0.92,
      onTap: _onBackspace,
      child: Container(
        decoration: BoxDecoration(
          color: t.softSurface.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: t.outline),
        ),
        child: Center(
          child: Icon(
            Icons.backspace_outlined,
            color: t.text,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildRecoveryFlow(AppCustomTheme t) {
    if (_isLoadingQuestions) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: t.primary),
        ),
      );
    }

    if (_questionVerified) {
      return Column(
        children: [
          Text(
            'Ingresa tu nuevo PIN de 4 dígitos:',
            style: TextStyle(color: t.text, fontSize: 13.5, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _newPinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            style: TextStyle(color: t.text, fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              filled: true,
              fillColor: t.softSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: t.outline),
              ),
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: t.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isResettingPin ? null : _resetPin,
              child: _isResettingPin
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Establecer Nuevo PIN',
                      style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona cuál de tus preguntas de seguridad deseas responder:',
          style: TextStyle(color: t.text2, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<int>(
          value: _selectedQuestionIndex,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Elige tu pregunta',
            labelStyle: TextStyle(color: t.primary, fontSize: 12),
            filled: true,
            fillColor: t.softSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.outline),
            ),
          ),
          dropdownColor: t.card,
          items: _securityQuestions.asMap().entries.map((entry) {
            return DropdownMenuItem<int>(
              value: entry.key,
              child: Text(
                entry.value['question'] ?? 'Pregunta ${entry.key + 1}',
                style: TextStyle(color: t.text, fontSize: 12),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedQuestionIndex = val);
            }
          },
        ),
        const SizedBox(height: 12),

        TextField(
          controller: _answerCtrl,
          style: TextStyle(color: t.text, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Tu respuesta...',
            hintStyle: TextStyle(color: t.muted, fontSize: 12.5),
            filled: true,
            fillColor: t.softSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.outline),
            ),
          ),
        ),
        const SizedBox(height: 22),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _verifyChosenQuestion,
            child: const Text(
              'Verificar Respuesta',
              style: TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
