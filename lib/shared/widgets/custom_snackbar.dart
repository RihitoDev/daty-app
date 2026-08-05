import 'package:flutter/material.dart';
import 'dart:ui';

class CustomSnackBar {
  static void showSuccess(BuildContext context, String message) {
    _show(
        context, message, Icons.check_circle_rounded, const Color(0xFF4CAF50));
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Icons.error_rounded, const Color(0xFFFF5252));
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Icons.info_rounded, const Color(0xFF9C27B0));
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, Icons.warning_rounded, const Color(0xFFFFB300));
  }

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    final compact = MediaQuery.sizeOf(context).width <= 360;
    // Cerramos cualquier otro aviso antes de mostrar el nuevo, así no se apilan
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        // El fondo del SnackBar tiene que ser transparente para que nuestro efecto de cristal funcione
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.zero,
        margin: EdgeInsets.only(
          bottom: 20,
          left: compact ? 10 : 25,
          right: compact ? 10 : 25,
        ),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(
                sigmaX: 10, sigmaY: 10), // Efecto cristal esmerilado
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 20,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  SizedBox(width: compact ? 10 : 15),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
