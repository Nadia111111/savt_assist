// lib/widgets/telegram_doodle_pattern.dart
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
    return ClipRect(
      child: Container(
        color: backgroundColor,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _SavtMonogramPainter(
                color: doodleColor.withOpacity(opacity.clamp(0.0, 1.0)),
              ),
            ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _SavtMonogramPainter extends CustomPainter {
  final Color color;

  const _SavtMonogramPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (color.alpha <= 0 || size.width <= 0 || size.height <= 0) return;

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final textStyle = TextStyle(
      color: color,
      fontSize: 16.0,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );

    final List<String> letters = const ['S', 'A', 'V', 'T'];
    final painters = letters.map((l) {
      final tp = TextPainter(
        text: TextSpan(text: l, style: textStyle),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      return tp;
    }).toList();

    const double stepX = 54.0;
    const double stepY = 50.0;
    final int cols = (size.width / stepX).ceil() + 2;
    final int rows = (size.height / stepY).ceil() + 2;

    for (int r = -1; r < rows; r++) {
      for (int c = -1; c < cols; c++) {
        final double x = c * stepX + ((r % 2 == 1 || r % 2 == -1) ? stepX * 0.5 : 0.0);
        final double y = r * stepY;

        final int letterIndex = ((r + c) % 4 + 4) % 4;
        final tp = painters[letterIndex];

        tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SavtMonogramPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
