import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// High-fidelity car renderer that produces Uber-style 3D car markers.
///
/// Features:
///  • Isometric ¾ top-down view with 3D depth panels
///  • Shadow, headlights, taillights, side mirrors, rims
///  • Multiple vehicle presets (sedan, SUV, luxury)
///  • Cache-friendly: renders once, reuses BitmapDescriptor
///
/// The sprite is painted pointing UP (north). For the driver's tilted
/// camera (60–70°), use `flat: false` (billboard). For rider's top-down
/// camera, use `flat: true, rotation: bearing`.
class CarRenderer {
  CarRenderer._();

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Clear the cache (for hot-reload during dev).
  static void invalidate() => _cache.clear();

  /// Load a car sprite with the given preset.
  /// Returns cached descriptor if already rendered.
  static Future<BitmapDescriptor> load({
    CarPreset preset = CarPreset.whiteSedan,
    double displayWidth = 44,
    double displayHeight = 66,
  }) async {
    final key = '${preset.name}_${displayWidth}_$displayHeight';
    if (_cache.containsKey(key)) return _cache[key]!;

    final desc = await _render(preset, displayWidth, displayHeight);
    _cache[key] = desc;
    return desc;
  }

  static Future<BitmapDescriptor> _render(
    CarPreset preset,
    double displayWidth,
    double displayHeight,
  ) async {
    final p = preset.params;
    const double cW = 220.0;
    const double cH = 340.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, cW, cH));

    final double cx = cW / 2;
    final double cy = cH / 2;

    // Body half-extents
    final double bW = 82.0 * p.widthRatio;
    final double bH = 118.0 * p.heightRatio;

    // ── 1. DROP SHADOW ──
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + 3, cy + 6),
        width: (bW + 24) * 2,
        height: (bH + 18) * 2,
      ),
      Paint()
        ..color = p.shadowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // ── 2. WHEELS ──
    final double wW = 36.0 * p.widthRatio;
    final double wH = 46.0 * p.heightRatio;
    final wheelPositions = <Offset>[
      Offset(cx - bW * 0.90, cy - bH * 0.60),
      Offset(cx + bW * 0.90, cy - bH * 0.60),
      Offset(cx - bW * 0.90, cy + bH * 0.58),
      Offset(cx + bW * 0.90, cy + bH * 0.58),
    ];
    for (final wp in wheelPositions) {
      // Tyre
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: wW, height: wH),
        Paint()..color = p.wheelColor,
      );
      // Tyre border
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: wW, height: wH),
        Paint()
          ..color = const Color(0xFF333333)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Rim
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: wW * 0.48, height: wH * 0.48),
        Paint()..color = p.rimColor,
      );
      // Rim shine
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: wW * 0.22, height: wH * 0.22),
        Paint()..color = p.rimColor.withValues(alpha: 0.6),
      );
    }

    // ── 3. MAIN BODY ──
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: bW * 2,
      height: bH * 2,
    );
    final bodyRRect = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: Radius.circular(bW * 0.74),
      topRight: Radius.circular(bW * 0.74),
      bottomLeft: Radius.circular(bW * 0.42),
      bottomRight: Radius.circular(bW * 0.42),
    );

    // Base color
    canvas.drawRRect(bodyRRect, Paint()..color = p.bodyColor);

    // Highlight gradient (top-left light source)
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.5),
          radius: 0.9,
          colors: [p.bodyHighlight, p.bodyColor],
        ).createShader(bodyRect),
    );

    // Subtle body outline
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..color = p.bodyOutline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // ── 4. 3D DEPTH PANELS (side strips + bumper) ──
    // Left side depth
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - bW - 14, cy - bH * 0.70, 14, bH * 1.56),
        bottomLeft: Radius.circular(bW * 0.38),
      ),
      Paint()..color = const Color(0x50000000),
    );
    // Right side depth
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx + bW, cy - bH * 0.70, 14, bH * 1.56),
        bottomRight: Radius.circular(bW * 0.38),
      ),
      Paint()..color = const Color(0x3A000000),
    );
    // Rear bumper depth
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - bW + 6, cy + bH + 1, bW * 2 - 12, 18),
        bottomLeft: Radius.circular(bW * 0.36),
        bottomRight: Radius.circular(bW * 0.36),
      ),
      Paint()..color = const Color(0x5A000000),
    );

    // ── 5. CABIN / GREENHOUSE ──
    final double cabinH = bH * 1.06;
    final double cabinCy = cy - bH * 0.04;
    final cabinRRect = RRect.fromRectAndCorners(
      Rect.fromCenter(
        center: Offset(cx, cabinCy),
        width: bW * 1.30,
        height: cabinH,
      ),
      topLeft: Radius.circular(bW * 0.50),
      topRight: Radius.circular(bW * 0.50),
      bottomLeft: Radius.circular(bW * 0.24),
      bottomRight: Radius.circular(bW * 0.24),
    );
    canvas.drawRRect(cabinRRect, Paint()..color = p.windowColor);

    // Gloss sheen streak (left side, simulates reflection)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cx - bW * 0.54,
          cabinCy - cabinH / 2 + 8,
          bW * 0.20,
          cabinH * 0.45,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = p.windowShine.withValues(alpha: 0.20),
    );

    // Center divider line (front/rear window split)
    canvas.drawLine(
      Offset(cx - bW * 0.5, cabinCy + 2),
      Offset(cx + bW * 0.5, cabinCy + 2),
      Paint()
        ..color = p.bodyColor.withValues(alpha: 0.4)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // ── 6. HEADLIGHTS ──
    final double hlY = cy - bH * 0.90;
    for (final sign in [-1.0, 1.0]) {
      // Main headlight
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + sign * bW * 0.48, hlY),
            width: bW * 0.40,
            height: 10,
          ),
          const Radius.circular(5),
        ),
        Paint()..color = p.headlightColor,
      );
      // LED glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + sign * bW * 0.48, hlY),
            width: bW * 0.50,
            height: 16,
          ),
          const Radius.circular(8),
        ),
        Paint()
          ..color = p.headlightColor.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    // ── 7. TAILLIGHTS ──
    final double tlY = cy + bH * 0.90;
    for (final sign in [-1.0, 1.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + sign * bW * 0.46, tlY),
            width: bW * 0.38,
            height: 8,
          ),
          const Radius.circular(4),
        ),
        Paint()..color = p.taillightColor,
      );
      // Taillight glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + sign * bW * 0.46, tlY),
            width: bW * 0.48,
            height: 14,
          ),
          const Radius.circular(7),
        ),
        Paint()
          ..color = p.taillightColor.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // ── 8. SIDE MIRRORS ──
    for (final s in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * (bW + 10), cy - bH * 0.36),
          width: 11,
          height: 8,
        ),
        Paint()..color = p.bodyColor,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx + s * (bW + 10), cy - bH * 0.36 - 1),
          width: 6,
          height: 3.5,
        ),
        Paint()..color = p.windowShine.withValues(alpha: 0.3),
      );
    }

    // ── 9. FRONT GRILLE ──
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - bH * 0.82),
          width: bW * 0.50,
          height: 5,
        ),
        const Radius.circular(2.5),
      ),
      Paint()..color = p.trimColor,
    );

    // ── ENCODE ──
    final picture = recorder.endRecording();
    final image = await picture.toImage(cW.toInt(), cH.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      width: displayWidth,
      height: displayHeight,
    );
  }
}

/// Vehicle style presets.
enum CarPreset { whiteSedan, blackSUV, silverLuxury, darkSedan }

extension CarPresetParams on CarPreset {
  _CarParams get params {
    switch (this) {
      case CarPreset.whiteSedan:
        return const _CarParams(
          bodyColor: Color(0xFFF5F5F5),
          bodyHighlight: Color(0xFFFFFFFF),
          bodyOutline: Color(0xFFCCCCCC),
          windowColor: Color(0xFF2C2C2C),
          windowShine: Color(0xFF666666),
          trimColor: Color(0xFFBBBBBB),
          wheelColor: Color(0xFF1A1A1A),
          rimColor: Color(0xFF888888),
          shadowColor: Color(0x55000000),
          headlightColor: Color(0xFFFFE082),
          taillightColor: Color(0xFFEF5350),
          widthRatio: 0.90,
          heightRatio: 0.94,
        );
      case CarPreset.blackSUV:
        return const _CarParams(
          bodyColor: Color(0xFF1E1E1E),
          bodyHighlight: Color(0xFF3A3A3A),
          bodyOutline: Color(0xFF444444),
          windowColor: Color(0xFF0D0D0D),
          windowShine: Color(0xFF444444),
          trimColor: Color(0xFF555555),
          wheelColor: Color(0xFF111111),
          rimColor: Color(0xFF666666),
          shadowColor: Color(0x66000000),
          headlightColor: Color(0xFFFFE082),
          taillightColor: Color(0xFFEF5350),
          widthRatio: 1.0,
          heightRatio: 1.0,
        );
      case CarPreset.silverLuxury:
        return const _CarParams(
          bodyColor: Color(0xFFB0B0B0),
          bodyHighlight: Color(0xFFD5D5D5),
          bodyOutline: Color(0xFF999999),
          windowColor: Color(0xFF1A1A1A),
          windowShine: Color(0xFF555555),
          trimColor: Color(0xFFC0C0C0),
          wheelColor: Color(0xFF181818),
          rimColor: Color(0xFFAAAAAA),
          shadowColor: Color(0x55000000),
          headlightColor: Color(0xFFE0E0FF),
          taillightColor: Color(0xFFE53935),
          widthRatio: 0.95,
          heightRatio: 0.96,
        );
      case CarPreset.darkSedan:
        return const _CarParams(
          bodyColor: Color(0xFF2D2D2D),
          bodyHighlight: Color(0xFF484848),
          bodyOutline: Color(0xFF3A3A3A),
          windowColor: Color(0xFF0A0A0A),
          windowShine: Color(0xFF3A3A3A),
          trimColor: Color(0xFF505050),
          wheelColor: Color(0xFF0F0F0F),
          rimColor: Color(0xFF666666),
          shadowColor: Color(0x66000000),
          headlightColor: Color(0xFFFFE082),
          taillightColor: Color(0xFFEF5350),
          widthRatio: 0.88,
          heightRatio: 0.92,
        );
    }
  }
}

class _CarParams {
  final Color bodyColor;
  final Color bodyHighlight;
  final Color bodyOutline;
  final Color windowColor;
  final Color windowShine;
  final Color trimColor;
  final Color wheelColor;
  final Color rimColor;
  final Color shadowColor;
  final Color headlightColor;
  final Color taillightColor;
  final double widthRatio;
  final double heightRatio;

  const _CarParams({
    required this.bodyColor,
    required this.bodyHighlight,
    required this.bodyOutline,
    required this.windowColor,
    required this.windowShine,
    required this.trimColor,
    required this.wheelColor,
    required this.rimColor,
    required this.shadowColor,
    required this.headlightColor,
    required this.taillightColor,
    required this.widthRatio,
    required this.heightRatio,
  });
}
