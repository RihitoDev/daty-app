import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/theme_provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _authError;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_authError != null) setState(() => _authError = null);
  }

  void _handleRegister() async {
    _clearError();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final errorCode = await authProvider.register(
      _emailController.text,
      _passwordController.text,
      _usernameController.text
    );

    if (mounted) {
      if (errorCode != null) {
        String message = 'Ocurrió un error inesperado.';
        if (errorCode == 'weak-password') message = 'La contraseña es muy débil (mínimo 6 caracteres).';
        if (errorCode == 'email-already-in-use') message = 'Este correo ya está registrado.';
        if (errorCode == 'firestore-error') message = 'Error al crear el perfil. Intenta de nuevo.';
        setState(() => _authError = message);
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;
    final customTheme = Provider.of<ThemeProvider>(context).currentTheme;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [customTheme.primaryLight, customTheme.bg],
              ),
            ),
          ),
          _buildBackgroundDecorations(customTheme.primary),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, color: customTheme.text, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 25),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: customTheme.card.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: customTheme.muted.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: customTheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.auto_awesome, color: customTheme.primary, size: 32),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Únete a Daty', style: TextStyle(fontSize: 24, color: customTheme.text, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                                Text('Comienza tu aventura hoy', style: TextStyle(fontSize: 13, color: customTheme.text2)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(25.0),
                          decoration: BoxDecoration(
                            color: customTheme.card.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: customTheme.muted.withValues(alpha: 0.2)),
                            boxShadow: [BoxShadow(color: customTheme.primary.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5)],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_authError != null) _buildAuthErrorBanner(_authError!, customTheme),
                              _buildStepIndicator(1, 'Perfil', customTheme),
                              const SizedBox(height: 12),
                              _buildTextField(_usernameController, '¿Cómo te llamamos?', Icons.person_outline, customTheme),
                              const SizedBox(height: 24),
                              _buildStepIndicator(2, 'Contacto', customTheme),
                              const SizedBox(height: 12),
                              _buildTextField(_emailController, 'Tu correo electrónico', Icons.email_outlined, customTheme, isEmail: true),
                              const SizedBox(height: 24),
                              _buildStepIndicator(3, 'Seguridad', customTheme),
                              const SizedBox(height: 12),
                              _buildTextField(_passwordController, 'Crea una contraseña', Icons.lock_outline, customTheme, isPassword: true),
                              const SizedBox(height: 12),
                              _buildTextField(_confirmPasswordController, 'Confirma tu contraseña', Icons.lock_outline, customTheme, isPassword: true, isConfirm: true),
                              const SizedBox(height: 35),
                              SizedBox(
                                width: double.infinity, height: 55,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: customTheme.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    elevation: 5,
                                    shadowColor: customTheme.primary.withValues(alpha: 0.3),
                                  ),
                                  child: isLoading
                                    ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: customTheme.card, strokeWidth: 3))
                                    : Text('Crear Cuenta', style: TextStyle(fontSize: 18, color: customTheme.card, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: customTheme.text2, fontSize: 14),
                          children: [
                            const TextSpan(text: '¿Ya tienes cuenta? '),
                            TextSpan(text: 'Inicia sesión', style: TextStyle(fontWeight: FontWeight.bold, color: customTheme.primary)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String title, AppCustomTheme customTheme) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: customTheme.primaryLight,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(step.toString(), style: TextStyle(color: customTheme.primaryDark, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: customTheme.text, fontWeight: FontWeight.w700, fontSize: 14)),
      ],
    );
  }

  Widget _buildAuthErrorBanner(String message, AppCustomTheme customTheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: customTheme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: customTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: customTheme.accent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(color: customTheme.accent, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, AppCustomTheme customTheme, {bool isPassword = false, bool isEmail = false, bool isConfirm = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: TextStyle(color: customTheme.text),
      onChanged: (_) => _clearError(),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Campo obligatorio';
        if (isEmail && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Correo no válido';
        if (isPassword && value.length < 6) return 'Mínimo 6 caracteres';
        if (isConfirm && value != _passwordController.text) return 'Las contraseñas no coinciden';
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: customTheme.muted),
        filled: true,
        fillColor: customTheme.bg.withValues(alpha: 0.5),
        prefixIcon: Icon(icon, color: customTheme.muted),
        suffixIcon: isPassword
          ? IconButton(
              icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: customTheme.muted),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            )
          : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: customTheme.muted.withValues(alpha: 0.2))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: customTheme.muted.withValues(alpha: 0.2))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: customTheme.primary, width: 1.5)),
        errorStyle: TextStyle(color: customTheme.accent, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBackgroundDecorations(Color primaryColor) {
    return Stack(
      children: [
        Positioned(top: 80, right: -20, child: Icon(Icons.star_rounded, color: primaryColor.withValues(alpha: 0.05), size: 120)),
        Positioned(bottom: 150, left: -30, child: Icon(Icons.explore_outlined, color: primaryColor.withValues(alpha: 0.05), size: 150)),
      ],
    );
  }
}