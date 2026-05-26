import 'package:flutter/material.dart';

class CandyPathPainter extends CustomPainter {
  final List<Offset> points;
  final Color pathColor; // NUEVO

  CandyPathPainter({required this.points, this.pathColor = const Color.fromARGB(255, 255, 199, 77)}); // Rosa por defecto

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i]; final next = points[i + 1];
      path.cubicTo(current.dx, current.dy + (next.dy - current.dy) * 0.8, next.dx, next.dy - (next.dy - current.dy) * 0.8, next.dx, next.dy);
    }
    
    canvas.drawPath(path.shift(const Offset(2, 4)), Paint()..color = Colors.brown.withValues(alpha: 0.15)..strokeWidth = 20..strokeCap = StrokeCap.round..style = PaintingStyle.stroke);
    canvas.drawPath(path, Paint()..color = pathColor..strokeWidth = 16..strokeCap = StrokeCap.round..style = PaintingStyle.stroke); // USA EL COLOR AQUÍ
  }
  
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}