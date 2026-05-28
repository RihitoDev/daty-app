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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    // Ahora signIn devuelve un String?
    final errorCode = await authProvider.signIn(_emailController.text, _passwordController.text);

    if (mounted && errorCode != null) {
      String message = 'Correo o contraseña incorrectos';
      if (errorCode == 'user-not-found') message = 'No existe una cuenta con este correo';
      if (errorCode == 'wrong-password') message = 'La contraseña es incorrecta';
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _handleGoogleLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.signInWithGoogle();

    if (mounted && result != null) {
      // Si no fue 'cancelled', mostramos error real
      if (result != 'cancelled') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al iniciar sesión con Google'), backgroundColor: Colors.redAccent),
        );
      }
      // Si fue 'cancelled', no hacemos nada, silenciosamente ignoramos
    }
  }

  void _showResetPasswordDialog() {
    final TextEditingController resetEmailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recuperar Contraseña'),
        content: TextField(
          controller: resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'Ingresa tu correo electrónico'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              if (resetEmailController.text.trim().isNotEmpty) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                final error = await authProvider.resetPassword(resetEmailController.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(error ?? 'Se ha enviado un correo de recuperación a tu dirección.'),
                      backgroundColor: error != null ? Colors.redAccent : Colors.green,
                    ),
                  );
                }
              }
            },
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;

    return Scaffold(
      // CAMBIO: true para que el teclado empuje el contenido hacia arriba
      resizeToAvoidBottomInset: true, 
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFC14BF1), Color(0xFFE27C9D), Color(0xFFFFD147)],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
          _buildBackgroundDecorations(),
          SafeArea(
            child: SingleChildScrollView( // Permite scroll si el teclado tapa
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Image.asset('assets/images/mascot.png', height: 120, errorBuilder: (context, error, stackTrace) => const Icon(Icons.sentiment_very_satisfied, size: 100, color: Colors.white)),
                  const Text('Daty', style: TextStyle(fontFamily: 'Serif', fontSize: 60, color: Colors.white, fontStyle: FontStyle.italic)),
                  const Text('Tu Compañero De Aventuras', style: TextStyle(fontFamily: 'Serif', fontSize: 16, color: Colors.white, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 35),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                      child: Container(
                        padding: const EdgeInsets.all(30.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Correo:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                hintText: 'Ingrese su correo',
                                filled: true, fillColor: Colors.white.withValues(alpha: 0.9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text('Contraseña:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            TextField(
                              controller: _passwordController,
                              obscureText: !_isPasswordVisible,
                              decoration: InputDecoration(
                                hintText: 'Ingrese su contraseña',
                                filled: true, fillColor: Colors.white.withValues(alpha: 0.9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity, height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF81D4FA), Color(0xFF4FC3F7)]),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                  child: isLoading 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('Entrar', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 15),
                            Center(child: TextButton(
                              onPressed: _showResetPasswordDialog,
                              child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, decoration: TextDecoration.underline, decorationColor: Colors.white))
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                    child: RichText(text: const TextSpan(style: TextStyle(color: Colors.white, fontSize: 16), children: [TextSpan(text: '¿No tienes cuenta? '), TextSpan(text: '¡Regístrate!', style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline))])),
                  ),
                  GestureDetector(
                    // CAMBIO: Desactivamos el tap visualmente si está cargando
                    onTap: isLoading ? null : _handleGoogleLogin, 
                    child: Opacity(
                      opacity: isLoading ? 0.5 : 1.0,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 5, spreadRadius: 1)]),
                        child: Image.network('https://img.icons8.com/color/48/000000/google-logo.png', height: 30, width: 30, errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.blue, size: 35)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40), // Espacio extra para el teclado
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundDecorations() {
    return Stack(
      children: [
        Positioned(top: 100, left: 30, child: Icon(Icons.calendar_month_outlined, color: Colors.white.withValues(alpha: 0.1), size: 40)),
        Positioned(top: 250, right: 30, child: Icon(Icons.location_on_outlined, color: Colors.white.withValues(alpha: 0.1), size: 50)),
        Positioned(bottom: 150, left: 50, child: Icon(Icons.people_outline, color: Colors.white.withValues(alpha: 0.1), size: 60)),
      ],
    );
  }
}