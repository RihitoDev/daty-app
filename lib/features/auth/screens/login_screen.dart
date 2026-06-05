import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  String? _authError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_authError != null) setState(() => _authError = null);
  }

  void _handleLogin() async {
    _clearError();
    if (!_formKey.currentState!.validate()) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final errorCode = await authProvider.signIn(_emailController.text, _passwordController.text);

    // Si Firebase devuelve un error, lo mapeamos a un mensaje amigable para la UI
    if (mounted && errorCode != null) {
      String message = 'Correo o contrasena incorrectos';
      if (errorCode == 'user-not-found') message = 'No existe una cuenta con este correo';
      if (errorCode == 'wrong-password') message = 'La contrasena es incorrecta';
      if (errorCode == 'invalid-email') message = 'El formato del correo no es valido';
      setState(() => _authError = message);
    }
  }

  void _handleGoogleLogin() async {
    _clearError();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.signInWithGoogle();

    if (mounted && result != null && result != 'cancelled') {
      setState(() => _authError = 'No se pudo iniciar sesion con Google');
    }
  }

  void _showResetPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      // Usamos StatefulBuilder para poder hacer setState solo dentro del diálogo (para mostrar errores) sin reconstruir toda la pantalla de fondo
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.purple.shade300),
                const SizedBox(width: 10),
                const Text('Recuperar Contrasena', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Ingresa tu correo y te enviaremos un enlace para restablecerla.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 15),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'correo@ejemplo.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    errorText: dialogError,
                  ),
                  onChanged: (_) => setDialogState(() => dialogError = null),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC14BF1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  if (resetEmailController.text.trim().isEmpty) {
                    setDialogState(() => dialogError = 'El correo es obligatorio');
                    return;
                  }
                  
                  final authProvider = Provider.of<AuthProvider>(dialogContext, listen: false);
                  final error = await authProvider.resetPassword(resetEmailController.text.trim());
                  
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    if (error == null) {
                      _showSuccessDialog('Correo Enviado', 'Revisa tu bandeja de entrada para restablecer tu contrasena.');
                    } else {
                      String msg = 'No se pudo enviar el correo.';
                      if (error == 'not-found') msg = 'No existe una cuenta con este correo.';
                      setState(() => _authError = msg);
                    }
                  }
                },
                child: const Text('Enviar', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 40),
        title: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
        actions: [Center(child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')))],
      ),
    );
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
          _buildBackgroundDecorations(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 30),
                    Image.asset('assets/images/mascot.png', height: 110, errorBuilder: (context, error, stackTrace) => const Icon(Icons.sentiment_very_satisfied, size: 100, color: Colors.white)),
                    const Text('Daty', style: TextStyle(fontFamily: 'Serif', fontSize: 55, color: Colors.white, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic, shadows: [Shadow(blurRadius: 10, color: Colors.black26)])),
                    const Text('Tu Companero De Aventuras', style: TextStyle(fontSize: 16, color: Colors.white70, letterSpacing: 1.5)),
                    const SizedBox(height: 35),

                    // Efecto Glassmorphism (vidrio esmerilado) para el fondo del formulario principal
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
                              _buildInputLabel('Correo'),
                              _buildTextField(_emailController, 'ingresa@correo.com', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 20),
                              _buildInputLabel('Contrasena'),
                              _buildTextField(_passwordController, 'Tu contrasena', Icons.lock_outline, isPassword: true),
                              const SizedBox(height: 5),
                              
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _showResetPasswordDialog,
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                  child: const Text('Olvide mi contrasena', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(height: 15),
                              
                              SizedBox(
                                width: double.infinity, height: 55,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4FC3F7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 5, shadowColor: Colors.blue.withValues(alpha: 0.3)),
                                  child: isLoading 
                                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                                    : const Text('Entrar', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity, height: 55,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _handleGoogleLogin,
                        icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.white),
                        label: const Text('Continuar con Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                        style: OutlinedButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.15), side: BorderSide(color: Colors.white.withValues(alpha: 0.4)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                      child: RichText(text: const TextSpan(style: TextStyle(color: Colors.white, fontSize: 16), children: [TextSpan(text: 'No tienes cuenta? '), TextSpan(text: 'Registrate', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline, decorationColor: Colors.white))])),
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

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      onChanged: (_) => _clearError(),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Este campo es obligatorio';
        return null;
      },
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        filled: true, 
        fillColor: Colors.white.withValues(alpha: 0.15),
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword 
          ? IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.white70), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)) 
          : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.white, width: 1.5)),
        errorStyle: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(top: 80, left: 20, child: Icon(Icons.explore_outlined, color: Colors.white.withValues(alpha: 0.15), size: 60)),
        Positioned(top: 220, right: 20, child: Icon(Icons.favorite_outline, color: Colors.white.withValues(alpha: 0.1), size: 80)),
        Positioned(bottom: 200, left: 40, child: Icon(Icons.backpack_outlined, color: Colors.white.withValues(alpha: 0.1), size: 70)),
        Positioned(bottom: 80, right: 40, child: Icon(Icons.star_outline, color: Colors.white.withValues(alpha: 0.15), size: 50)),
      ],
    );
  }
}