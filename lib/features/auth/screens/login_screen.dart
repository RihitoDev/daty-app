import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
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

    if (mounted && errorCode != null) {
      String message = 'Correo o contraseña incorrectos';
      if (errorCode == 'user-not-found') message = 'No existe una cuenta con este correo';
      if (errorCode == 'wrong-password') message = 'La contraseña es incorrecta';
      if (errorCode == 'invalid-email') message = 'El formato del correo no es válido';
      setState(() => _authError = message);
    }
  }

  void _handleGoogleLogin() async {
    _clearError();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final result = await authProvider.signInWithGoogle();

    if (mounted && result != null && result != 'cancelled') {
      setState(() => _authError = 'No se pudo iniciar sesión con Google');
    }
  }

  void _showResetPasswordDialog(BuildContext context) {
    final customTheme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    final TextEditingController resetEmailController = TextEditingController();
    String? dialogError;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: customTheme.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: customTheme.primary),
                const SizedBox(width: 10),
                Text('Recuperar Contraseña', style: TextStyle(fontWeight: FontWeight.bold, color: customTheme.text)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ingresa tu correo y te enviaremos un enlace para restablecerla.', style: TextStyle(color: customTheme.text2)),
                const SizedBox(height: 15),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: customTheme.text),
                  decoration: InputDecoration(
                    hintText: 'correo@ejemplo.com',
                    hintStyle: TextStyle(color: customTheme.muted),
                    prefixIcon: Icon(Icons.email_outlined, color: customTheme.muted),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: customTheme.muted.withValues(alpha: 0.3))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: customTheme.primary)),
                    errorText: dialogError,
                  ),
                  onChanged: (_) => setDialogState(() => dialogError = null),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  resetEmailController.dispose();
                  Navigator.pop(dialogContext);
                },
                child: Text('Cancelar', style: TextStyle(color: customTheme.text2)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: customTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  if (resetEmailController.text.trim().isEmpty) {
                    setDialogState(() => dialogError = 'El correo es obligatorio');
                    return;
                  }

                  final authProvider = Provider.of<AuthProvider>(dialogContext, listen: false);
                  final error = await authProvider.resetPassword(resetEmailController.text.trim());

                  if (dialogContext.mounted) {
                    resetEmailController.dispose();
                    Navigator.pop(dialogContext);
                    if (error == null) {
                      _showSuccessDialog('Correo Enviado', 'Revisa tu bandeja de entrada para restablecer tu contraseña.');
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
    final customTheme = Provider.of<ThemeProvider>(context, listen: false).currentTheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: customTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(Icons.check_circle_outline, color: customTheme.primary, size: 40),
        title: Text(title, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: customTheme.text)),
        content: Text(message, textAlign: TextAlign.center, style: TextStyle(color: customTheme.text2)),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Entendido', style: TextStyle(color: customTheme.primary)),
            ),
          )
        ],
      ),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 25.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Image.asset(
                      'assets/images/mascot.png', 
                      height: 200, 
                      errorBuilder: (context, error, stackTrace) => Icon(Icons.sentiment_very_satisfied, size: 140, color: customTheme.primary)
                    ),
                    const Text('Daty', style: TextStyle(fontSize: 58, color: Colors.black)),
                    const Text('Explora, Conecta, Comparte', style: TextStyle(fontSize: 16, color: Colors.black87, letterSpacing: 1.5)),
                    const SizedBox(height: 35),
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
                              if (_authError != null) _buildAuthErrorBanner(_authError!, customTheme.accent),
                              _buildInputLabel('Correo', customTheme.text),
                              _buildTextField(_emailController, 'ingresa@correo.com', Icons.email_outlined, customTheme, keyboardType: TextInputType.emailAddress),
                              const SizedBox(height: 20),
                              _buildInputLabel('Contraseña', customTheme.text),
                              _buildTextField(_passwordController, 'Tu contraseña', Icons.lock_outline, customTheme, isPassword: true),
                              const SizedBox(height: 5),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () => _showResetPasswordDialog(context),
                                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30)),
                                  child: Text('Olvidé mi contraseña', style: TextStyle(color: customTheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),
                              const SizedBox(height: 15),
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: customTheme.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                    elevation: 5,
                                    shadowColor: customTheme.primary.withValues(alpha: 0.3),
                                  ),
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
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : _handleGoogleLogin,
                        icon: Icon(Icons.g_mobiledata, size: 30, color: customTheme.text),
                        label: Text('Continuar con Google', style: TextStyle(color: customTheme.text, fontWeight: FontWeight.w600, fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: customTheme.card.withValues(alpha: 0.5),
                          side: BorderSide(color: customTheme.muted.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen())),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(color: customTheme.text2, fontSize: 14),
                          children: [
                            const TextSpan(text: '¿No tienes cuenta? '),
                            TextSpan(text: 'Regístrate', style: TextStyle(fontWeight: FontWeight.bold, color: customTheme.primary)),
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

  Widget _buildAuthErrorBanner(String message, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label, Color textColor) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 13)),
  );

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, dynamic customTheme, {bool isPassword = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      keyboardType: keyboardType,
      style: TextStyle(color: customTheme.text),
      onChanged: (_) => _clearError(),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Este campo es obligatorio';
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
        errorStyle: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildBackgroundDecorations(Color primaryColor) {
    return Stack(
      children: [
        Positioned(top: 80, left: 20, child: Icon(Icons.explore_outlined, color: primaryColor.withValues(alpha: 0.05), size: 60)),
        Positioned(top: 220, right: 20, child: Icon(Icons.favorite_outline, color: primaryColor.withValues(alpha: 0.05), size: 80)),
        Positioned(bottom: 200, left: 40, child: Icon(Icons.backpack_outlined, color: primaryColor.withValues(alpha: 0.05), size: 70)),
        Positioned(bottom: 80, right: 40, child: Icon(Icons.star_outline, color: primaryColor.withValues(alpha: 0.05), size: 50)),
      ],
    );
  }
}