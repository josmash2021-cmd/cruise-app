import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Determines which biometric icon to show.
enum BiometricIconType { faceId, fingerprint }

/// Animated biometric icon that shows either a Face ID or Fingerprint icon
/// with smooth scanning animation.
class AnimatedBiometricIcon extends StatefulWidget {
  final double size;
  final Color color;
  final BiometricIconType type;

  const AnimatedBiometricIcon({
    super.key,
    this.size = 28,
    this.color = const Color(0xFFE8C547),
    this.type = BiometricIconType.faceId,
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
      duration: const Duration(milliseconds: 2400),
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
            painter: widget.type == BiometricIconType.faceId
                ? _FaceIdPainter(color: widget.color, progress: _ctrl.value)
                : _FingerprintPainter(
                    color: widget.color,
                    progress: _ctrl.value,
                  ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  FACE ID PAINTER — Apple-style face scan icon
// ═══════════════════════════════════════════════════════════

class _FaceIdPainter extends CustomPainter {
  final Color color;
  final double progress;

  _FaceIdPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final corner = w * 0.28;
    final strokeW = w * 0.065;

    final bracketPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    // ── Four corner brackets ──
    // Top-left
    canvas.drawLine(
      Offset(strokeW / 2, corner),
      Offset(strokeW / 2, strokeW / 2),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(strokeW / 2, strokeW / 2),
      Offset(corner, strokeW / 2),
      bracketPaint,
    );
    // Top-right
    canvas.drawLine(
      Offset(w - corner, strokeW / 2),
      Offset(w - strokeW / 2, strokeW / 2),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(w - strokeW / 2, strokeW / 2),
      Offset(w - strokeW / 2, corner),
      bracketPaint,
    );
    // Bottom-left
    canvas.drawLine(
      Offset(strokeW / 2, h - corner),
      Offset(strokeW / 2, h - strokeW / 2),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(strokeW / 2, h - strokeW / 2),
      Offset(corner, h - strokeW / 2),
      bracketPaint,
    );
    // Bottom-right
    canvas.drawLine(
      Offset(w - strokeW / 2, h - corner),
      Offset(w - strokeW / 2, h - strokeW / 2),
      bracketPaint,
    );
    canvas.drawLine(
      Offset(w - strokeW / 2, h - strokeW / 2),
      Offset(w - corner, h - strokeW / 2),
      bracketPaint,
    );

    // ── Face features ──
    final cx = w / 2;
    final cy = h / 2;
    final faceStroke = w * 0.055;

    final facePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = faceStroke
      ..strokeCap = StrokeCap.round;

    // Left eye — vertical line with small hook at top
    final eyeTop = cy - h * 0.12;
    final eyeBot = cy - h * 0.02;
    final eyeLeft = cx - w * 0.13;
    final eyeRight = cx + w * 0.13;

    // Left eye arc (like an upside down J)
    final leftEyePath = Path()
      ..moveTo(eyeLeft - w * 0.02, eyeTop)
      ..quadraticBezierTo(
        eyeLeft,
        eyeTop - h * 0.02,
        eyeLeft + w * 0.02,
        eyeTop,
      )
      ..moveTo(eyeLeft, eyeTop)
      ..lineTo(eyeLeft, eyeBot);
    canvas.drawPath(leftEyePath, facePaint);

    // Right eye arc
    final rightEyePath = Path()
      ..moveTo(eyeRight - w * 0.02, eyeTop)
      ..quadraticBezierTo(
        eyeRight,
        eyeTop - h * 0.02,
        eyeRight + w * 0.02,
        eyeTop,
      )
      ..moveTo(eyeRight, eyeTop)
      ..lineTo(eyeRight, eyeBot);
    canvas.drawPath(rightEyePath, facePaint);

    // Nose — small vertical line
    canvas.drawLine(
      Offset(cx, cy + h * 0.0),
      Offset(cx, cy + h * 0.08),
      facePaint,
    );
    // Nose tip curve
    final nosePath = Path()
      ..moveTo(cx, cy + h * 0.08)
      ..quadraticBezierTo(
        cx + w * 0.04,
        cy + h * 0.10,
        cx + w * 0.06,
        cy + h * 0.07,
      );
    canvas.drawPath(nosePath, facePaint);

    // Mouth — smile arc
    final mouthY = cy + h * 0.16;
    final mouthPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = faceStroke
      ..strokeCap = StrokeCap.round;

    final mouthPath = Path()
      ..moveTo(cx - w * 0.10, mouthY - h * 0.02)
      ..quadraticBezierTo(
        cx - w * 0.08,
        mouthY + h * 0.03,
        cx,
        mouthY + h * 0.02,
      )
      ..quadraticBezierTo(
        cx + w * 0.08,
        mouthY + h * 0.03,
        cx + w * 0.10,
        mouthY - h * 0.02,
      );
    canvas.drawPath(mouthPath, mouthPaint);

    // ── Scanning line (animated) ──
    // Bounces up and down
    final bounced = (progress <= 0.5) ? progress * 2.0 : 2.0 - progress * 2.0;
    final scanY = h * 0.12 + (h * 0.76) * bounced;
    final scanPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color.withValues(alpha: 0.6),
          color.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(w * 0.15, scanY - 1, w * 0.7, 2))
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(w * 0.15, scanY),
      Offset(w * 0.85, scanY),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(_FaceIdPainter old) =>
      old.progress != progress || old.color != color;
}

// ═══════════════════════════════════════════════════════════
//  FINGERPRINT PAINTER — circular fingerprint pattern
// ═══════════════════════════════════════════════════════════

class _FingerprintPainter extends CustomPainter {
  final Color color;
  final double progress;

  _FingerprintPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final strokeW = w * 0.04;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW
      ..strokeCap = StrokeCap.round;

    // Draw concentric fingerprint-like arcs
    // The fingerprint is made of curved lines radiating from center

    // Center vertical ridge
    _drawArc(canvas, cx, cy, w * 0.04, -90, 180, paint);

    // Inner arcs
    _drawArc(canvas, cx, cy, w * 0.10, -100, 200, paint);
    _drawArc(canvas, cx, cy, w * 0.16, -110, 200, paint);

    // Middle arcs
    _drawArc(canvas, cx, cy, w * 0.22, -120, 220, paint);
    _drawArc(canvas, cx, cy, w * 0.28, -130, 230, paint);

    // Outer arcs — partial, creating the fingerprint whorl
    _drawArc(canvas, cx + w * 0.02, cy - h * 0.02, w * 0.34, -140, 200, paint);
    _drawArc(canvas, cx - w * 0.01, cy + h * 0.01, w * 0.34, 40, 140, paint);

    // Outermost partial arcs
    _drawArc(canvas, cx + w * 0.03, cy - h * 0.03, w * 0.40, -150, 170, paint);
    _drawArc(canvas, cx - w * 0.02, cy + h * 0.02, w * 0.40, 30, 120, paint);

    // Top cap arcs
    _drawArc(canvas, cx, cy - h * 0.05, w * 0.44, -160, 130, paint);

    // ── Glow pulse animation ──
    final glowOpacity = (math.sin(progress * math.pi * 2) * 0.3 + 0.3).clamp(
      0.0,
      0.6,
    );
    final glowPaint = Paint()
      ..color = color.withValues(alpha: glowOpacity)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.15);
    canvas.drawCircle(Offset(cx, cy), w * 0.2, glowPaint);
  }

  void _drawArc(
    Canvas canvas,
    double cx,
    double cy,
    double radius,
    double startDeg,
    double sweepDeg,
    Paint paint,
  ) {
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      startDeg * math.pi / 180,
      sweepDeg * math.pi / 180,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_FingerprintPainter old) =>
      old.progress != progress || old.color != color;
}
