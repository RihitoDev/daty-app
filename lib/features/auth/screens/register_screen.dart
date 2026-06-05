import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
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
        // Filtro rápido de errores comunes de Firebase para la UI
        String message = 'Ocurrio un error inesperado.';
        if (errorCode == 'weak-password') message = 'La contrasena es muy debil (minimo 6 caracteres).';
        if (errorCode == 'email-already-in-use') message = 'Este correo ya esta registrado.';
        if (errorCode == 'firestore-error') message = 'Error al crear el perfil. Intenta de nuevo.';
        setState(() => _authError = message);
      } else {
        // Reseteamos el stack de navegación para evitar que vuelvan al login con el botón de "Atrás"
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFC14BF1), Color(0xFFE27C9D), Color(0xFFFFD147)], stops: [0.0, 0.5, 1.0]),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 10.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft, 
                      child: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context))
                    ),
                    const Text('Crear Cuenta', style: TextStyle(fontFamily: 'Serif', fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, shadows: [Shadow(blurRadius: 10, color: Colors.black26)])),
                    const SizedBox(height: 25),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(25.0),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                            boxShadow: [BoxShadow(color: Colors.purple.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 5)]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_authError != null) _buildAuthErrorBanner(_authError!),
                              _buildInputLabel('Usuario (Apodo)'),
                              _buildTextField(_usernameController, 'Tu apodo en Daty', Icons.person_outline),
                              const SizedBox(height: 18),
                              _buildInputLabel('Correo Electronico'),
                              _buildTextField(_emailController, 'ejemplo@correo.com', Icons.email_outlined, isEmail: true),
                              const SizedBox(height: 18),
                              _buildInputLabel('Contrasena'),
                              _buildTextField(_passwordController, 'Minimo 6 caracteres', Icons.lock_outline, isPassword: true),
                              const SizedBox(height: 18),
                              _buildInputLabel('Confirmar Contrasena'),
                              _buildTextField(_confirmPasswordController, 'Repite tu contrasena', Icons.lock_outline, isPassword: true, isConfirm: true),
                              const SizedBox(height: 30),
                              SizedBox(
                                width: double.infinity, height: 55,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 5, shadowColor: Colors.blue.withValues(alpha: 0.3)),
                                  child: isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                    : const Text('Registrarse', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
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
                      child: RichText(text: const TextSpan(style: TextStyle(color: Colors.white, fontSize: 16), children: [TextSpan(text: 'Ya tienes cuenta? '), TextSpan(text: 'Entrar', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.white))])),
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

  Widget _buildAuthErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5))),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0), 
    child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
  );

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false, bool isEmail = false, bool isConfirm = false}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => _clearError(),
      validator: (value) {
        // Bloqueo de avance si el input rompe las reglas de negocio
        if (value == null || value.isEmpty) return 'Campo obligatorio';
        if (isEmail && !RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) return 'Correo no valido';
        if (isPassword && value.length < 6) return 'Minimo 6 caracteres';
        if (isConfirm && value != _passwordController.text) return 'Las contrasenas no coinciden';
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true, 
        fillColor: Colors.white.withValues(alpha: 0.15),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword 
          ? IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)) : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
        errorStyle: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.w600),
      ),
    );
  }
}