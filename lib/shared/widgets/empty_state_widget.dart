import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  const EmptyStateWidget({super.key, required this.icon, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 70, color: Colors.grey.shade400),
            const SizedBox(height: 15),
            Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
            // Solo mostramos el botón si nos pasaron una acción para reintentar
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF9C27B0)),
              )
            ]
          ],
        ),
      ),
    );
  }
}