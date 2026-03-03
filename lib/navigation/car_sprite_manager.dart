import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Pre-renders 36 car sprites (one per 10°) at startup using Canvas.
/// Design: Uber-Black-style premium top-down car in jet black.
/// Call [CarSpriteManager.init()] once before using [iconForBearing].
class CarSpriteManager {
  CarSpriteManager._();

  static const int _frames = 36;
  static const int _tileW = 48;
  static const int _tileH = 72;

  static final List<BitmapDescriptor> _icons = [];
  static bool _ready = false;

  static bool get isReady => _ready;

  /// Must be called once before any GPS updates (e.g., in initState).
  static Future<void> init() async {
    if (_ready) return;
    _icons.clear();
    for (int i = 0; i < _frames; i++) {
      final bearing = i * (360.0 / _frames);
      final icon = await _renderFrame(bearing);
      _icons.add(icon);
    }
    _ready = true;
  }

  /// Returns the sprite closest to [bearingDeg] (snapped to nearest 10°).
  static BitmapDescriptor iconForBearing(double bearingDeg) {
    if (!_ready || _icons.isEmpty) return BitmapDescriptor.defaultMarker;
    final idx = ((bearingDeg % 360) / (360.0 / _frames)).round() % _frames;
    return _icons[idx];
  }

  static Future<BitmapDescriptor> _renderFrame(double bearing) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(
      recorder,
      Rect.fromLTWH(0, 0, _tileW.toDouble(), _tileH.toDouble()),
    );
    _drawCar(canvas, bearing);
    final picture = recorder.endRecording();
    final img = await picture.toImage(_tileW, _tileH);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final list = Uint8List.view(bytes!.buffer);
    return BitmapDescriptor.bytes(list, width: _tileW.toDouble());
  }

  static void _drawCar(ui.Canvas canvas, double bearing) {
    const double cx = _tileW / 2.0;
    const double cy = _tileH / 2.0;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(bearing * math.pi / 180);
    canvas.translate(-cx, -cy);

    // ── Drop shadow ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 13, cy - 21, 26, 44),
        const Radius.circular(7),
      ),
      Paint()
        ..color = const Color(0x66000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // ── Body – jet black ──
    final bodyPaint = Paint()..color = const Color(0xFF111111);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 11, cy - 21, 22, 42),
        const Radius.circular(6),
      ),
      bodyPaint,
    );

    // ── Subtle body highlight (left edge gradient) ──
    canvas.drawRect(
      Rect.fromLTWH(cx - 11, cy - 18, 2, 34),
      Paint()..color = const Color(0x22FFFFFF),
    );

    // ── Roof / cabin – dark charcoal ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 7.5, cy - 14, 15, 22),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFF1E1E1E),
    );

    // ── Front windshield ──
    final frontPath = Path()
      ..moveTo(cx - 6.5, cy - 14)
      ..lineTo(cx + 6.5, cy - 14)
      ..lineTo(cx + 5.5, cy - 21)
      ..lineTo(cx - 5.5, cy - 21)
      ..close();
    canvas.drawPath(frontPath, Paint()..color = const Color(0xCC9ECFEF));
    // Windshield glare streak
    canvas.drawPath(
      (Path()
        ..moveTo(cx - 3.5, cy - 20.5)
        ..lineTo(cx - 1.5, cy - 20.5)
        ..lineTo(cx - 3, cy - 14.5)
        ..lineTo(cx - 4.5, cy - 14.5)
        ..close()),
      Paint()..color = const Color(0x55FFFFFF),
    );

    // ── Rear windshield ──
    final rearPath = Path()
      ..moveTo(cx - 6.5, cy + 8)
      ..lineTo(cx + 6.5, cy + 8)
      ..lineTo(cx + 5.5, cy + 14)
      ..lineTo(cx - 5.5, cy + 14)
      ..close();
    canvas.drawPath(rearPath, Paint()..color = const Color(0x886699BB));

    // ── Chrome / gold accent stripe along beltline ──
    canvas.drawRect(
      Rect.fromLTWH(cx - 11, cy - 1, 22, 1.5),
      Paint()..color = const Color(0xFFB8964A),
    );

    // ── Headlights – bright white ──
    final hlPaint = Paint()..color = const Color(0xFFF0F8FF);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(cx - 6.5, cy - 20), width: 5, height: 3),
        topLeft: const Radius.circular(2),
        bottomLeft: const Radius.circular(2),
      ),
      hlPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(cx + 6.5, cy - 20), width: 5, height: 3),
        topRight: const Radius.circular(2),
        bottomRight: const Radius.circular(2),
      ),
      hlPaint,
    );
    // DRL glow
    canvas.drawRect(
      Rect.fromLTWH(cx - 11, cy - 21.5, 22, 1.5),
      Paint()
        ..color = const Color(0xAAE8F4FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // ── Tail lights – vivid red ──
    final tlPaint = Paint()..color = const Color(0xFFFF1A1A);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(cx - 6.5, cy + 20), width: 5, height: 3),
        bottomLeft: const Radius.circular(2),
        topLeft: const Radius.circular(2),
      ),
      tlPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(center: Offset(cx + 6.5, cy + 20), width: 5, height: 3),
        bottomRight: const Radius.circular(2),
        topRight: const Radius.circular(2),
      ),
      tlPaint,
    );
    // Tail glow
    canvas.drawRect(
      Rect.fromLTWH(cx - 11, cy + 20, 22, 1.5),
      Paint()
        ..color = const Color(0x88FF1A1A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // ── Wheels – black with silver rim ──
    for (final pt in [
      Offset(cx - 12, cy - 11),
      Offset(cx + 12, cy - 11),
      Offset(cx - 12, cy + 9),
      Offset(cx + 12, cy + 9),
    ]) {
      // Tire (black)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: pt, width: 6, height: 10),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFF0A0A0A),
      );
      // Rim (silver)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: pt, width: 3.5, height: 7),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFF8A8A8A),
      );
    }

    canvas.restore();
  }
}
