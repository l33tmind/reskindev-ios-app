import 'package:flutter/material.dart';

/// A widget that draws the official WhatsApp icon using CustomPainter.
/// This is 100% reliable on all platforms including Flutter Web.
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppIcon({super.key, this.size = 36, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _WhatsAppIconPainter(color: color),
    );
  }
}

class _WhatsAppIconPainter extends CustomPainter {
  final Color color;
  _WhatsAppIconPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Draw speech bubble (rounded rect)
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.06, h * 0.04, w * 0.88, h * 0.82),
      Radius.circular(w * 0.22),
    );
    canvas.drawRRect(bubbleRect, paint);

    // Draw the tail of the speech bubble (bottom-left)
    final tailPath = Path();
    tailPath.moveTo(w * 0.12, h * 0.78);
    tailPath.lineTo(w * 0.03, h * 0.97);
    tailPath.lineTo(w * 0.30, h * 0.85);
    tailPath.close();
    canvas.drawPath(tailPath, paint);

    // Draw phone handset CUTOUT (white on white = transparent effect via blend)
    final phonePaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.095
      ..strokeCap = StrokeCap.round;

    // Phone arc (top of handset)
    final phoneArcRect = Rect.fromLTWH(w * 0.28, h * 0.18, w * 0.44, h * 0.44);
    canvas.drawArc(phoneArcRect, -3.14, 3.14, false, phonePaint);

    // Left ear (receiver)
    final leftEarPaint = Paint()
      ..color = const Color(0xFF25D366)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.29, h * 0.40), w * 0.085, leftEarPaint);

    // Right ear (speaker)
    canvas.drawCircle(Offset(w * 0.71, h * 0.40), w * 0.085, leftEarPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
