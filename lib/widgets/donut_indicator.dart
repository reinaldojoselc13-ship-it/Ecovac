import 'dart:math';
import 'package:flutter/material.dart';

class DonutIndicator extends StatelessWidget {
  final double progress; // 0.0 - 1.0
  final double size;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;
  final Widget? center;

  const DonutIndicator({
    super.key,
    required this.progress,
    this.size = 160,
    this.strokeWidth = 24,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.progressColor = const Color(0xFF5D3AE6),
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(progress.clamp(0.0, 1.0), strokeWidth, backgroundColor, progressColor),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color bgColor;
  final Color fgColor;

  _DonutPainter(this.progress, this.strokeWidth, this.bgColor, this.fgColor);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = fgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // draw background full circle
    canvas.drawCircle(center, radius, bgPaint);

    // draw foreground arc from -90 degrees clockwise
    final startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweepAngle, false, fgPaint);
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) {
    return old.progress != progress || old.fgColor != fgColor || old.bgColor != bgColor || old.strokeWidth != strokeWidth;
  }
}

// math imported at top
