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
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_usernameController.text.trim().isEmpty || _emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos'), backgroundColor: Colors.redAccent));
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La contraseña debe tener al menos 6 caracteres'), backgroundColor: Colors.redAccent));
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden'), backgroundColor: Colors.redAccent));
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final errorCode = await authProvider.register(
      _emailController.text, 
      _passwordController.text, 
      _usernameController.text
    );

    if (mounted) {
      if (errorCode != null) {
        // Manejo mejorado de errores de Firebase
        String message = 'Ocurrió un error inesperado.';
        if (errorCode == 'weak-password') message = 'La contraseña es muy debil (mínimo 6 caracteres).';
        if (errorCode == 'email-already-in-use') message = 'El correo ya esta registrado.';
        if (errorCode.contains('perfil en la base de datos')) message = errorCode; // Error custom nuestro
        
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
      } else {
        // Éxito: cerramos hasta la raíz
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;

    return Scaffold(
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
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft, 
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Colors.white), 
                      onPressed: () => Navigator.pop(context)
                    )
                  ),
                  const Text(
                    'Crear Cuenta', 
                    style: TextStyle(
                      fontFamily: 'Serif', fontSize: 40, color: Colors.white, 
                      fontWeight: FontWeight.bold, fontStyle: FontStyle.italic
                    )
                  ),
                  const SizedBox(height: 20),
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
                            _buildInputLabel('Usuario (Apodo):'),
                            _buildTextField(_usernameController, 'Tu apodo en Daty', Icons.person_outline),
                            const SizedBox(height: 15),
                            _buildInputLabel('Correo Electrónico:'),
                            _buildTextField(_emailController, 'ejemplo@correo.com', Icons.email_outlined, isEmail: true),
                            const SizedBox(height: 15),
                            _buildInputLabel('Contraseña:'),
                            _buildTextField(_passwordController, 'Mínimo 6 caracteres', Icons.lock_outline, isPassword: true),
                            const SizedBox(height: 15),
                            _buildInputLabel('Confirmar Contraseña:'),
                            _buildTextField(_confirmPasswordController, 'Repite tu contraseña', Icons.lock_outline, isPassword: true),
                            const SizedBox(height: 30),
                            SizedBox(
                              width: double.infinity, height: 50,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [Color(0xFF81D4FA), Color(0xFF4FC3F7)]), 
                                  borderRadius: BorderRadius.circular(25)
                                ),
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent, 
                                    shadowColor: Colors.transparent
                                  ),
                                  child: isLoading 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        'Registrarse', 
                                        style: TextStyle(
                                          fontSize: 18, color: Colors.white, 
                                          fontWeight: FontWeight.bold
                                        )
                                      ),
                                ),
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
                      text: const TextSpan(
                        style: TextStyle(color: Colors.white, fontSize: 16), 
                        children: [
                          TextSpan(text: '¿Ya tienes cuenta? '), 
                          TextSpan(
                            text: 'Entrar', 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              decoration: TextDecoration.underline
                            )
                          )
                        ]
                      )
                    ),
                  ),
                  const SizedBox(height: 40), // Espacio extra para teclado
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 5.0), 
    child: Text(
      label, 
      style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)
    )
  );

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false, bool isEmail = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint, 
        filled: true, 
        fillColor: Colors.white.withValues(alpha: 0.9), 
        prefixIcon: Icon(icon, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25), 
          borderSide: BorderSide.none
        ),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility, 
                color: Colors.grey
              ), 
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)
            ) 
          : null,
      ),
    );
  }
}