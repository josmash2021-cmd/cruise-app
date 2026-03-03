### patch_vehicle_icons.ps1 ###
# Replaces _buildArrowIcon (lines 263-1020) + _loadVehicleIcons (1022-1042)
# with a clean _buildVehicleIcons() + _paintCarSprite() that generates
# both dark SUV and white sedan icons at runtime using Canvas.

$file = 'c:\Users\josma\cruise-app\lib\screens\driver\driver_online_screen.dart'
$lines = [System.IO.File]::ReadAllLines($file)

# Find exact start: "  // -- 3D isometric car icon"
$startIdx = -1
for ($i = 0; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^\s*// -- 3D isometric car icon') {
        $startIdx = $i
        break
    }
}
if ($startIdx -lt 0) { Write-Error "Could not find _buildArrowIcon start marker"; exit 1 }

# Find end of _loadVehicleIcons: line starting with "  /// Get the correct vehicle icon"
$endIdx = -1
for ($i = $startIdx; $i -lt $lines.Length; $i++) {
    if ($lines[$i] -match '^\s*/// Get the correct vehicle icon') {
        $endIdx = $i
        break
    }
}
if ($endIdx -lt 0) { Write-Error "Could not find _vehicleIcon comment marker"; exit 1 }

Write-Host "Replacing lines $($startIdx+1) to $endIdx (0-indexed) ..."

$newCode = @'
  // ── Build Uber-style 3D car marker sprites at runtime ──────────────
  Future<void> _buildVehicleIcons() async {
    // Black SUV (Suburban) – bigger, taller, boxy
    _suvIcon = await _paintCarSprite(
      bodyColor: const Color(0xFF1E1E1E),
      bodyHighlight: const Color(0xFF3A3A3A),
      windowColor: const Color(0xFF0D0D0D),
      windowShine: const Color(0xFF444444),
      trimColor: const Color(0xFF555555),
      wheelColor: const Color(0xFF111111),
      shadowColor: const Color(0x66000000),
      headlightColor: const Color(0xFFFFE082),
      taillightColor: const Color(0xFFEF5350),
      widthRatio: 1.0,
      heightRatio: 1.0,
      roofHeightRatio: 0.38,
    );
    // White Sedan (Fusion / Camry) – sleeker, lower
    _sedanIcon = await _paintCarSprite(
      bodyColor: const Color(0xFFF0F0F0),
      bodyHighlight: const Color(0xFFFFFFFF),
      windowColor: const Color(0xFF2C2C2C),
      windowShine: const Color(0xFF666666),
      trimColor: const Color(0xFFBBBBBB),
      wheelColor: const Color(0xFF222222),
      shadowColor: const Color(0x55000000),
      headlightColor: const Color(0xFFFFE082),
      taillightColor: const Color(0xFFEF5350),
      widthRatio: 0.88,
      heightRatio: 0.92,
      roofHeightRatio: 0.30,
    );
    // Keep _arrowIcon as null – _vehicleIcon always returns suvIcon or sedanIcon
    _arrowIcon = _suvIcon;
    if (mounted) setState(() {});
  }

  /// Renders a single car marker sprite using Canvas.
  ///  - Car points UP (north) so `rotation = bearing` works correctly.
  ///  - Isometric 3/4 top-down view with 3D depth.
  ///  - Transparent background + soft shadow.
  Future<BitmapDescriptor> _paintCarSprite({
    required Color bodyColor,
    required Color bodyHighlight,
    required Color windowColor,
    required Color windowShine,
    required Color trimColor,
    required Color wheelColor,
    required Color shadowColor,
    required Color headlightColor,
    required Color taillightColor,
    required double widthRatio,
    required double heightRatio,
    required double roofHeightRatio,
  }) async {
    // Canvas size (will be displayed at ~55x90 on screen)
    const double cW = 220.0;
    const double cH = 360.0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, cW, cH));

    // Derived sizes
    final double bW = 96 * widthRatio;   // body half-width
    final double bH = 150 * heightRatio; // body half-height (front-to-back)
    final double cx = cW / 2;
    final double cy = cH / 2 + 10;      // shift down slightly for shadow room
    final double dX = 5.0;              // 3D depth lateral offset
    final double dY = 18.0 * heightRatio; // 3D depth vertical (body height)

    // ─── 1. GROUND SHADOW ──────────────────────────────────────────
    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 3, cy + 8), width: bW * 1.7, height: bH * 1.2),
      shadowPaint,
    );

    // ─── 2. BODY SIDES (3D depth walls) ────────────────────────────
    final sidePaint = Paint()..color = Color.lerp(bodyColor, const Color(0xFF000000), 0.35)!;

    // Right side wall
    final rightSide = Path()
      ..moveTo(cx + bW, cy - bH * 0.75)
      ..lineTo(cx + bW + dX, cy - bH * 0.75 + dY)
      ..lineTo(cx + bW + dX, cy + bH * 0.75 + dY)
      ..lineTo(cx + bW, cy + bH * 0.75)
      ..close();
    canvas.drawPath(rightSide, sidePaint);

    // Bottom (front facing down = car's front) side wall
    final frontSide = Path()
      ..moveTo(cx - bW, cy + bH * 0.75)
      ..lineTo(cx - bW + dX, cy + bH * 0.75 + dY)
      ..lineTo(cx + bW + dX, cy + bH * 0.75 + dY)
      ..lineTo(cx + bW, cy + bH * 0.75)
      ..close();
    canvas.drawPath(frontSide, Paint()..color = Color.lerp(bodyColor, const Color(0xFF000000), 0.25)!);

    // ─── 3. TOP BODY (roof-level panel) ────────────────────────────
    // Main body rectangle with rounded corners
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromCenter(center: Offset(cx, cy), width: bW * 2, height: bH * 1.5),
      topLeft: Radius.circular(bW * 0.55),
      topRight: Radius.circular(bW * 0.55),
      bottomLeft: Radius.circular(bW * 0.35),
      bottomRight: Radius.circular(bW * 0.35),
    );
    // Body gradient (top = highlight, bottom = base)
    final bodyGrad = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bodyHighlight, bodyColor, Color.lerp(bodyColor, const Color(0xFF000000), 0.1)!],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCenter(center: Offset(cx, cy), width: bW * 2, height: bH * 1.5));
    canvas.drawRRect(bodyRect, bodyGrad);

    // Subtle body outline
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = trimColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // ─── 4. HOOD (front area between windshield and bumper) ────────
    final hoodRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - bW * 0.72, cy + bH * 0.20, bW * 1.44, bH * 0.42),
      Radius.circular(bW * 0.15),
    );
    canvas.drawRRect(
      hoodRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bodyColor, bodyHighlight],
        ).createShader(hoodRect.outerRect),
    );

    // Hood center crease line
    canvas.drawLine(
      Offset(cx, cy + bH * 0.22),
      Offset(cx, cy + bH * 0.58),
      Paint()
        ..color = trimColor.withOpacity(0.2)
        ..strokeWidth = 1.0,
    );

    // ─── 5. WINDSHIELD (front window) ──────────────────────────────
    final wsW = bW * 0.70;
    final wsPath = Path()
      ..moveTo(cx - wsW, cy + bH * 0.05)
      ..lineTo(cx + wsW, cy + bH * 0.05)
      ..lineTo(cx + wsW * 0.85, cy + bH * 0.22)
      ..lineTo(cx - wsW * 0.85, cy + bH * 0.22)
      ..close();
    canvas.drawPath(wsPath, Paint()..color = windowColor);
    // Shine stripe across windshield
    canvas.drawPath(
      Path()
        ..moveTo(cx - wsW * 0.6, cy + bH * 0.08)
        ..lineTo(cx + wsW * 0.9, cy + bH * 0.08)
        ..lineTo(cx + wsW * 0.85, cy + bH * 0.13)
        ..lineTo(cx - wsW * 0.55, cy + bH * 0.13)
        ..close(),
      Paint()..color = windowShine.withOpacity(0.4),
    );

    // ─── 6. ROOF ───────────────────────────────────────────────────
    final roofH = bH * roofHeightRatio;
    final roofRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - bW * 0.62, cy - roofH, bW * 1.24, roofH * 0.95),
      Radius.circular(bW * 0.2),
    );
    canvas.drawRRect(
      roofRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bodyHighlight, bodyColor],
        ).createShader(roofRect.outerRect),
    );
    // Roof edge highlight
    canvas.drawRRect(
      roofRect,
      Paint()
        ..color = bodyHighlight.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ─── 7. REAR WINDOW ───────────────────────────────────────────
    final rwW = bW * 0.58;
    final rwPath = Path()
      ..moveTo(cx - rwW * 0.85, cy - roofH * 0.95)
      ..lineTo(cx + rwW * 0.85, cy - roofH * 0.95)
      ..lineTo(cx + rwW, cy - roofH - bH * 0.12)
      ..lineTo(cx - rwW, cy - roofH - bH * 0.12)
      ..close();
    canvas.drawPath(rwPath, Paint()..color = windowColor);

    // ─── 8. SIDE WINDOWS ──────────────────────────────────────────
    // Left side windows
    final lwPath = Path()
      ..moveTo(cx - bW * 0.82, cy - roofH * 0.1)
      ..lineTo(cx - bW * 0.65, cy - roofH * 0.1)
      ..lineTo(cx - bW * 0.65, cy + bH * 0.02)
      ..lineTo(cx - bW * 0.82, cy + bH * 0.02)
      ..close();
    canvas.drawPath(lwPath, Paint()..color = windowColor.withOpacity(0.7));
    // Right side windows
    final rwSidePath = Path()
      ..moveTo(cx + bW * 0.82, cy - roofH * 0.1)
      ..lineTo(cx + bW * 0.65, cy - roofH * 0.1)
      ..lineTo(cx + bW * 0.65, cy + bH * 0.02)
      ..lineTo(cx + bW * 0.82, cy + bH * 0.02)
      ..close();
    canvas.drawPath(rwSidePath, Paint()..color = windowColor.withOpacity(0.7));

    // ─── 9. HEADLIGHTS ────────────────────────────────────────────
    final hlY = cy + bH * 0.68;
    // Left headlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - bW * 0.55, hlY), width: bW * 0.35, height: 8),
        const Radius.circular(4),
      ),
      Paint()..color = headlightColor,
    );
    // Right headlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + bW * 0.55, hlY), width: bW * 0.35, height: 8),
        const Radius.circular(4),
      ),
      Paint()..color = headlightColor,
    );
    // Headlight glow
    canvas.drawCircle(
      Offset(cx - bW * 0.55, hlY), 6,
      Paint()..color = headlightColor.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(cx + bW * 0.55, hlY), 6,
      Paint()..color = headlightColor.withOpacity(0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // ─── 10. TAILLIGHTS ───────────────────────────────────────────
    final tlY = cy - bH * 0.72;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - bW * 0.60, tlY), width: bW * 0.28, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = taillightColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + bW * 0.60, tlY), width: bW * 0.28, height: 6),
        const Radius.circular(3),
      ),
      Paint()..color = taillightColor,
    );

    // ─── 11. WHEELS ──────────────────────────────────────────────
    final wheelPaint = Paint()..color = wheelColor;
    final wheelRimPaint = Paint()..color = trimColor.withOpacity(0.5);
    // Wheel positions: front-left, front-right, rear-left, rear-right
    final wheelPositions = [
      Offset(cx - bW * 0.85, cy + bH * 0.45),
      Offset(cx + bW * 0.85, cy + bH * 0.45),
      Offset(cx - bW * 0.85, cy - bH * 0.40),
      Offset(cx + bW * 0.85, cy - bH * 0.40),
    ];
    for (final wp in wheelPositions) {
      // Tire
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: 22 * widthRatio, height: 32 * heightRatio),
        wheelPaint,
      );
      // Rim highlight
      canvas.drawOval(
        Rect.fromCenter(center: wp, width: 12 * widthRatio, height: 18 * heightRatio),
        wheelRimPaint,
      );
    }

    // ─── 12. FRONT BUMPER ACCENT ──────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + bH * 0.73), width: bW * 0.8, height: 4),
        const Radius.circular(2),
      ),
      Paint()..color = trimColor.withOpacity(0.4),
    );

    // ─── 13. ENCODE TO PNG BYTES ─────────────────────────────────
    final picture = recorder.endRecording();
    final image = await picture.toImage(cW.toInt(), cH.toInt());
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) return BitmapDescriptor.defaultMarker;
    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      width: 55,
      height: 90,
    );
  }

'@

# Build new file content
$before = $lines[0..($startIdx - 1)]
$after = $lines[$endIdx..($lines.Length - 1)]

$newLines = @()
$newLines += $before
$newLines += $newCode.Split("`n")
$newLines += $after

$text = $newLines -join "`n"
# Ensure LF-only line endings
$text = $text.Replace("`r`n", "`n")
[System.IO.File]::WriteAllText($file, $text, [System.Text.UTF8Encoding]::new($false))

Write-Host "Replaced _buildArrowIcon + _loadVehicleIcons with _buildVehicleIcons + _paintCarSprite"
Write-Host "Old: lines $($startIdx+1) to $endIdx"
Write-Host "New code: $($newCode.Split("`n").Length) lines"
