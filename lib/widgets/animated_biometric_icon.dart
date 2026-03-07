import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated biometric scan icon — four corner brackets with a scanning line.
/// Matches the Face ID / Fingerprint brand icon.
class AnimatedBiometricIcon extends StatefulWidget {
  final double size;
  final Color color;

  const AnimatedBiometricIcon({
    super.key,
    this.size = 28,
    this.color = const Color(0xFFE8C547),
  });

  @override
  State<AnimatedBiometricIcon> createState() => _AnimatedBiometricIconState();
}

class _AnimatedBiometricIconState extends State<AnimatedBiometricIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _BiometricIconPainter(
              color: widget.color,
              scanProgress: _ctrl.value,
            ),
          );
        },
      ),
    );
  }
}

class _BiometricIconPainter extends CustomPainter {
  final Color color;
  final double scanProgress;

  _BiometricIconPainter({required this.color, required this.scanProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final corner = w * 0.28; // corner bracket length

    // ── Four corner brackets ──
    // Top-left
    canvas.drawLine(Offset(0, corner), Offset.zero, paint);
    canvas.drawLine(Offset.zero, Offset(corner, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - corner, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, corner), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - corner), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(corner, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w, h - corner), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w - corner, h), paint);

    // ── Face outline (simplified) ──
    final facePaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045;

    final cx = w / 2;
    final cy = h / 2;
    final faceW = w * 0.32;
    final faceH = h * 0.38;

    // Head oval
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy - h * 0.02),
        width: faceW,
        height: faceH,
      ),
      facePaint,
    );

    // Eyes
    final eyePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final eyeR = w * 0.03;
    canvas.drawCircle(Offset(cx - faceW * 0.22, cy - h * 0.06), eyeR, eyePaint);
    canvas.drawCircle(Offset(cx + faceW * 0.22, cy - h * 0.06), eyeR, eyePaint);

    // Mouth arc
    final mouthPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round;
    final mouthRect = Rect.fromCenter(
      center: Offset(cx, cy + h * 0.08),
      width: faceW * 0.4,
      height: h * 0.06,
    );
    canvas.drawArc(mouthRect, 0.2, math.pi * 0.6, false, mouthPaint);

    // ── Scanning line (animated) ──
    final scanY = h * 0.1 + (h * 0.8) * scanProgress;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(w * 0.15, scanY, w * 0.7, 2))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.15, scanY),
      Offset(w * 0.85, scanY),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(_BiometricIconPainter old) =>
      old.scanProgress != scanProgress || old.color != color;
}
