import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Loads and caches the black 3D isometric car [BitmapDescriptor].
///
/// The icon is rendered once at a fixed pixel size via Canvas and cached
/// for the lifetime of the app — it never regenerates on zoom changes.
///
/// Usage:
/// ```dart
/// final icon = await CarIconLoader.load();
/// Marker(icon: icon, flat: false, anchor: Offset(0.5, 0.7));
/// ```
class CarIconLoader {
  CarIconLoader._();

  static BitmapDescriptor? _cached;

  /// Return the cached icon, or paint + cache it on first call.
  static Future<BitmapDescriptor> load() async {
    if (_cached != null) return _cached!;
    _cached = await _paint();
    return _cached!;
  }

  /// Invalidate the cache (e.g. for hot-restart during dev).
  static void invalidate() => _cached = null;

  // ───────────────────────────────────────────────────────────
  //  Canvas painter – Uber-style clean white top-down car
  // ───────────────────────────────────────────────────────────
  static Future<BitmapDescriptor> _paint() async {
    const double cW = 200, cH = 300;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, cW, cH));

    const cx = cW / 2;
    const cy = cH / 2;
    const bW = 76.0; // body half-width
    const bH = 108.0; // body half-height

    // 1. Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(cx + 2, cy + 6),
        width: (bW + 18) * 2,
        height: (bH + 12) * 2,
      ),
      Paint()
        ..color = const Color(0x44000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // 2. Wheels (dark rubber + gray hub)
    const wW = 32.0, wH = 40.0;
    final wheelPositions = [
      const Offset(cx - bW * 0.90, cy - bH * 0.62),
      const Offset(cx + bW * 0.90, cy - bH * 0.62),
      const Offset(cx - bW * 0.90, cy + bH * 0.60),
      const Offset(cx + bW * 0.90, cy + bH * 0.60),
    ];
    for (final wp in wheelPositions) {
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: wW, height: wH),
        Paint()..color = const Color(0xFF1A1A1A),
      );
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: wW * 0.46, height: wH * 0.46),
        Paint()..color = const Color(0xFF8A8A8A),
      );
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: wW * 0.18, height: wH * 0.18),
        Paint()..color = const Color(0xFF444444),
      );
    }

    // 3. White car body
    final bodyRect = Rect.fromCenter(
      center: const Offset(cx, cy),
      width: bW * 2,
      height: bH * 2,
    );
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: const Radius.circular(bW * 0.70),
      topRight: const Radius.circular(bW * 0.70),
      bottomLeft: const Radius.circular(bW * 0.38),
      bottomRight: const Radius.circular(bW * 0.38),
    );
    // Base white fill
    canvas.drawRRect(bodyRRect, Paint()..color = const Color(0xFFF5F5F5));
    // Subtle directional gradient (left slightly darker)
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x22000000), Color(0x00000000), Color(0x14000000)],
          stops: [0.0, 0.5, 1.0],
        ).createShader(bodyRect),
    );
    // Top-down light (hood is brighter)
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x28FFFFFF), Color(0x00000000), Color(0x18000000)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(bodyRect),
    );
    // Thin dark outline
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = const Color(0xCC444444)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // 4. Dark cabin / roof
    const cabinH = bH * 1.02;
    const cabinCy = cy - bH * 0.04;
    final cabinRect = Rect.fromCenter(
      center: const Offset(cx, cabinCy),
      width: bW * 1.26,
      height: cabinH,
    );
    final cabinRRect = RRect.fromRectAndCorners(
      cabinRect,
      topLeft: const Radius.circular(bW * 0.46),
      topRight: const Radius.circular(bW * 0.46),
      bottomLeft: const Radius.circular(bW * 0.20),
      bottomRight: const Radius.circular(bW * 0.20),
    );
    canvas.drawRRect(cabinRRect, Paint()..color = const Color(0xFF2C2C2C));
    // Glass sheen on left window area
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cx - bW * 0.55,
          cabinCy - cabinH / 2 + 8,
          bW * 0.20,
          cabinH * 0.46,
        ),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0x1EFFFFFF),
    );
    // Windshield highlight streak
    canvas.drawLine(
      Offset(cx - bW * 0.20, cabinCy - cabinH * 0.36),
      Offset(cx + bW * 0.08, cabinCy - cabinH * 0.26),
      Paint()
        ..color = const Color(0x2AFFFFFF)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );

    // 5. White LED headlights
    const hlY = cy - bH * 0.87;
    for (final s in [-1.0, 1.0]) {
      // Outer housing (white)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + s * bW * 0.44, hlY),
            width: bW * 0.40,
            height: 9,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFF8F8F8),
      );
      // Bright center dot
      canvas.drawCircle(
        Offset(cx + s * bW * 0.44, hlY),
        3.0,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
    // DRL connecting strip
    canvas.drawLine(
      Offset(cx - bW * 0.24, hlY + 1),
      Offset(cx + bW * 0.24, hlY + 1),
      Paint()
        ..color = const Color(0xAADDDDDD)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // 6. Red taillights
    const tlY = cy + bH * 0.87;
    for (final s in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + s * bW * 0.43, tlY),
            width: bW * 0.38,
            height: 7,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFFEF3030),
      );
    }
    // Tail connecting line
    canvas.drawLine(
      Offset(cx - bW * 0.24, tlY - 1),
      Offset(cx + bW * 0.24, tlY - 1),
      Paint()
        ..color = const Color(0x88EF3030)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // 7. Small side mirrors
    for (final s in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * (bW + 9), cy - bH * 0.38),
          width: 10,
          height: 7,
        ),
        Paint()..color = const Color(0xFFCCCCCC),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * (bW + 9), cy - bH * 0.38 - 1),
          width: 5,
          height: 3,
        ),
        Paint()..color = const Color(0x40FFFFFF),
      );
    }

    // Encode
    final picture = recorder.endRecording();
    final image = await picture.toImage(cW.toInt(), cH.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      width: 40,
      height: 60,
    );
  }
}
