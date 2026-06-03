import 'package:flutter/material.dart';

class CandyPathPainter extends CustomPainter {
  final List<Offset> points;
  final Color pathColor;

  CandyPathPainter({required this.points, this.pathColor = const Color(0xFFFFC74D)});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i]; 
      final next = points[i + 1];
      path.cubicTo(
        current.dx, current.dy + (next.dy - current.dy) * 0.8, 
        next.dx, next.dy - (next.dy - current.dy) * 0.8, 
        next.dx, next.dy
      );
    }

    final glowPaintOuter = Paint()
      ..color = pathColor.withOpacity(0.15)
      ..strokeWidth = 40.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    final glowPaintInner = Paint()
      ..color = pathColor.withOpacity(0.5)
      ..strokeWidth = 20.0 
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final corePaint = Paint()
      ..color = pathColor
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 3.0 
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, glowPaintOuter);
    canvas.drawPath(path, glowPaintInner);
    canvas.drawPath(path, corePaint);
    canvas.drawPath(path, highlightPaint);
  }
  
  @override
  bool shouldRepaint(covariant CandyPathPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.pathColor != pathColor;
  }
}