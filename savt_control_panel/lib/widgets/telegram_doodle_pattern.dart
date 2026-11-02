// lib/widgets/telegram_doodle_pattern.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class TelegramDoodlePattern extends StatelessWidget {
  final Color backgroundColor;
  final Color doodleColor;
  final double opacity;
  final Widget? child;

  const TelegramDoodlePattern({
    super.key,
    this.backgroundColor = const Color(0xFF13111C),
    this.doodleColor = Colors.white,
    this.opacity = 0.09,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _TelegramDoodlePainter(
              color: doodleColor.withValues(alpha: opacity),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _TelegramDoodlePainter extends CustomPainter {
  final Color color;

  const _TelegramDoodlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.4)
      ..style = PaintingStyle.fill;

    const double stepX = 52.0;
    const double stepY = 52.0;
    final int cols = (size.width / stepX).ceil() + 1;
    final int rows = (size.height / stepY).ceil() + 1;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final double x = c * stepX + ((r % 2 == 1) ? stepX * 0.5 : 0.0);
        final double y = r * stepY;

        canvas.save();
        canvas.translate(x, y);

        final int shapeIndex = (r * 7 + c * 3) % 10;
        _drawShape(canvas, paint, fillPaint, shapeIndex);

        canvas.restore();
      }
    }
  }

  void _drawShape(Canvas canvas, Paint paint, Paint fillPaint, int index) {
    switch (index) {
      case 0:
        // Gear / Tech Cog (replaced heart)
        canvas.drawCircle(Offset.zero, 4.0, paint);
        for (int i = 0; i < 6; i++) {
          final double angle = i * (math.pi / 3);
          final double x1 = math.cos(angle) * 4.0;
          final double y1 = math.sin(angle) * 4.0;
          final double x2 = math.cos(angle) * 7.5;
          final double y2 = math.sin(angle) * 7.5;
          canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        }
        break;

      case 1:
        // 4-point sparkle star
        final path = Path();
        path.moveTo(0, -9);
        path.quadraticBezierTo(0, 0, 9, 0);
        path.quadraticBezierTo(0, 0, 0, 9);
        path.quadraticBezierTo(0, 0, -9, 0);
        path.quadraticBezierTo(0, 0, 0, -9);
        canvas.drawPath(path, paint);
        break;

      case 2:
        // Speech Bubble
        final rrect = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-8, -6, 16, 12),
          const Radius.circular(4),
        );
        canvas.drawRRect(rrect, paint);
        final tail = Path()
          ..moveTo(-4, 6)
          ..lineTo(-7, 9)
          ..lineTo(-1, 6);
        canvas.drawPath(tail, paint);
        break;

      case 3:
        // Diamond
        final path = Path()
          ..moveTo(0, -8)
          ..lineTo(7, 0)
          ..lineTo(0, 8)
          ..lineTo(-7, 0)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case 4:
        // Smiley Face
        canvas.drawCircle(Offset.zero, 7, paint);
        canvas.drawCircle(const Offset(-2.5, -2), 0.8, fillPaint);
        canvas.drawCircle(const Offset(2.5, -2), 0.8, fillPaint);
        final smile = Path()
          ..arcTo(
            const Rect.fromLTWH(-3.5, 0, 7, 4),
            0.2,
            math.pi - 0.4,
            false,
          );
        canvas.drawPath(smile, paint);
        break;

      case 5:
        // Music Note
        canvas.drawCircle(const Offset(-2, 4), 2.5, fillPaint);
        final stem = Path()
          ..moveTo(0.5, 4)
          ..lineTo(0.5, -6)
          ..lineTo(5, -4);
        canvas.drawPath(stem, paint);
        break;

      case 6:
        // Coffee Cup
        final cup = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-6, -4, 12, 10),
          const Radius.circular(3),
        );
        canvas.drawRRect(cup, paint);
        final handle = Path()
          ..arcTo(
            const Rect.fromLTWH(6, -2, 5, 6),
            -math.pi / 2,
            math.pi,
            false,
          );
        canvas.drawPath(handle, paint);
        break;

      case 7:
        // Little Flower
        for (int i = 0; i < 5; i++) {
          final double angle = i * (2 * math.pi / 5);
          final double px = math.cos(angle) * 4.5;
          final double py = math.sin(angle) * 4.5;
          canvas.drawCircle(Offset(px, py), 2.2, paint);
        }
        canvas.drawCircle(Offset.zero, 1.8, fillPaint);
        break;

      case 8:
        // Lightning bolt / Spark
        final path = Path()
          ..moveTo(2, -8)
          ..lineTo(-3, 0)
          ..lineTo(1, 0)
          ..lineTo(-2, 8)
          ..lineTo(4, -1)
          ..lineTo(0, -1)
          ..close();
        canvas.drawPath(path, paint);
        break;

      case 9:
        // Math / Crown
        final path = Path()
          ..moveTo(-7, 4)
          ..lineTo(-7, -4)
          ..lineTo(-3, 0)
          ..lineTo(0, -5)
          ..lineTo(3, 0)
          ..lineTo(7, -4)
          ..lineTo(7, 4)
          ..close();
        canvas.drawPath(path, paint);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TelegramDoodlePainter oldDelegate) =>
      oldDelegate.color != color;
}
