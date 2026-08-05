import 'dart:ui';
import 'package:flutter/material.dart';

class CandyPathPainter extends CustomPainter {
  final List<Offset> points;
  final Color pathColor;

  CandyPathPainter({required this.points, this.pathColor = const Color(0xFFFFC74D)});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    final int n = points.length;

    // Algoritmo Catmull-Rom Spline continuo C1 estilo Candy Crush Soda Saga
    for (int i = 0; i < n - 1; i++) {
      final p0 = i > 0 ? points[i - 1] : points[i];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i < n - 2 ? points[i + 2] : p2;

      const double smoothness = 0.22;

      final cp1 = Offset(
        p1.dx + (p2.dx - p0.dx) * smoothness,
        p1.dy + (p2.dy - p0.dy) * smoothness,
      );

      final cp2 = Offset(
        p2.dx - (p3.dx - p1.dx) * smoothness,
        p2.dy - (p3.dy - p1.dy) * smoothness,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
    }

    final glowPaintOuter = Paint()
      ..color = pathColor.withOpacity(0.12)
      ..strokeWidth = 36.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    final glowPaintInner = Paint()
      ..color = pathColor.withOpacity(0.4)
      ..strokeWidth = 18.0 
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final corePaint = Paint()
      ..color = pathColor
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 2.5 
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Se apilan las capas desde la más gruesa/transparente hasta la más delgada/brillante para crear el efecto neón o caramelo
    canvas.drawPath(path, glowPaintOuter);
    canvas.drawPath(path, glowPaintInner);
    canvas.drawPath(path, corePaint);
    canvas.drawPath(path, highlightPaint);

    // Dibujamos micro-partículas de luz a lo largo del camino
    final particlePaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    for (PathMetric metric in path.computeMetrics()) {
      final double totalLength = metric.length;
      const double step = 28.0;
      for (double distance = 0.0; distance < totalLength; distance += step) {
        final Tangent? tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 2.0, particlePaint);
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CandyPathPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.pathColor != pathColor;
  }
}