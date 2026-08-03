import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/pressable_scale.dart';

class PersonalVaultSetupDialog extends StatefulWidget {
  const PersonalVaultSetupDialog({super.key});

  @override
  State<PersonalVaultSetupDialog> createState() => _PersonalVaultSetupDialogState();
}

class _PersonalVaultSetupDialogState extends State<PersonalVaultSetupDialog> {
  int _step = 1; // 1: PIN de 4 dígitos, 2: 3 Preguntas de Seguridad
  String _pin = '';
  bool _isSaving = false;

  final List<String> _defaultQuestions = [
    '¿Cuál fue el nombre de tu primera mascota?',
    '¿En qué ciudad nacieron tus padres?',
    '¿Cuál es tu comida o platillo favorito?',
    '¿Cuál fue tu primer vehículo o bicicleta?',
    '¿Cuál es el nombre de tu escuela primaria?',
    '¿En qué ciudad te gustaría jubilarte?',
  ];

  late String _q1;
  late String _q2;
  late String _q3;

  final _a1Ctrl = TextEditingController();
  final _a2Ctrl = TextEditingController();
  final _a3Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _q1 = _defaultQuestions[0];
    _q2 = _defaultQuestions[1];
    _q3 = _defaultQuestions[2];
  }

  @override
  void dispose() {
    _a1Ctrl.dispose();
    _a2Ctrl.dispose();
    _a3Ctrl.dispose();
    super.dispose();
  }

  void _onKeyPress(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
      });
      if (_pin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            setState(() {
              _step = 2;
            });
          }
        });
      }
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Future<void> _saveVaultConfig() async {
    final a1 = _a1Ctrl.text.trim();
    final a2 = _a2Ctrl.text.trim();
    final a3 = _a3Ctrl.text.trim();

    if (a1.isEmpty || a2.isEmpty || a3.isEmpty) {
      CustomSnackBar.showError(context, 'Por favor responde las 3 preguntas de seguridad');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final myUid = Provider.of<AuthProvider>(context, listen: false).user!.uid;

      await FirebaseFirestore.instance.collection('users').doc(myUid).set({
        'personalVaultPin': _pin,
        'securityQuestions': [
          {'question': _q1, 'answer': a1.toLowerCase()},
          {'question': _q2, 'answer': a2.toLowerCase()},
          {'question': _q3, 'answer': a3.toLowerCase()},
        ],
      }, SetOptions(merge: true));

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Personal configurado correctamente');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Error al guardar la configuración: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<ThemeProvider>().currentTheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: t.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.security_rounded, color: t.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
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
                        Text(
                          _step == 1
                              ? 'Paso 1: Crea tu PIN de 4 dígitos'
                              : 'Paso 2: Configura 3 preguntas',
                          style: TextStyle(color: t.muted, fontSize: 12.5),
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

              if (_step == 1) _buildPinStep(t) else _buildQuestionsStep(t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPinStep(AppCustomTheme t) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < _pin.length;
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

  Widget _buildQuestionsStep(AppCustomTheme t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Configura 3 Preguntas de Seguridad por si en algún momento olvidas tu PIN:',
          style: TextStyle(color: t.text2, fontSize: 13, height: 1.35),
        ),
        const SizedBox(height: 16),

        _buildQuestionField(1, _q1, (val) => setState(() => _q1 = val!), _a1Ctrl, t),
        const SizedBox(height: 12),
        _buildQuestionField(2, _q2, (val) => setState(() => _q2 = val!), _a2Ctrl, t),
        const SizedBox(height: 12),
        _buildQuestionField(3, _q3, (val) => setState(() => _q3 = val!), _a3Ctrl, t),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: t.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: _isSaving ? null : _saveVaultConfig,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Guardar Configuración',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionField(
    int num,
    String selectedQ,
    ValueChanged<String?> onChanged,
    TextEditingController ctrl,
    AppCustomTheme t,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: selectedQ,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Pregunta $num',
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
          items: _defaultQuestions
              .map((q) => DropdownMenuItem(
                    value: q,
                    child: Text(q, style: TextStyle(color: t.text, fontSize: 12)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: TextStyle(color: t.text, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Tu respuesta...',
            hintStyle: TextStyle(color: t.muted, fontSize: 12),
            filled: true,
            fillColor: t.softSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.outline),
            ),
          ),
        ),
      ],
    );
  }
}
