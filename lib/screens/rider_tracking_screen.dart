import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/app_theme.dart';
import '../config/map_styles.dart';
import '../navigation/car_icon_loader.dart';
import '../services/directions_service.dart';
import '../config/api_keys.dart';
import 'chat_screen.dart';

class RiderTrackingScreen extends StatefulWidget {
  const RiderTrackingScreen({
    super.key,
    required this.pickupLatLng,
    required this.dropoffLatLng,
    this.routePoints,
    this.driverName = 'Yuniel',
    this.driverRating = 4.9,
    this.vehicleMake = 'Toyota',
    this.vehicleModel = 'Camry',
    this.vehicleColor = 'Gray',
    this.vehiclePlate = 'ABC-1234',
    this.vehicleYear = '2022',
    this.rideName = 'Fusion',
    this.price = 0,
    this.pickupLabel = '',
    this.dropoffLabel = '',
    this.onTripComplete,
  });

  final LatLng pickupLatLng;
  final LatLng dropoffLatLng;
  final List<LatLng>? routePoints;
  final String driverName;
  final double driverRating;
  final String vehicleMake;
  final String vehicleModel;
  final String vehicleColor;
  final String vehiclePlate;
  final String vehicleYear;
  final String rideName;
  final double price;
  final String pickupLabel;
  final String dropoffLabel;
  final VoidCallback? onTripComplete;

  @override
  State<RiderTrackingScreen> createState() => _RiderTrackingScreenState();
}

enum _TrackPhase { arriving, arrived, onTrip, completed }

class _RiderTrackingScreenState extends State<RiderTrackingScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _map;
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _carIconCar;
  BitmapDescriptor? _navArrowIcon;
  BitmapDescriptor? _goldPinIcon;
  BitmapDescriptor? _pickupPersonPin;
  BitmapDescriptor? _dropoffHousePin;
  Marker? _cachedCarMarker;
  Marker? _cachedMilesBadge;
  BitmapDescriptor? _milesBadgeIcon;
  String _lastMilesText = '';
  DateTime? _lastMarkerRebuild;

  _TrackPhase _phase = _TrackPhase.arriving;
  LatLng _driverPos = const LatLng(0, 0);
  LatLng _animPos = const LatLng(0, 0);
  double _driverBearing = 0;
  double _animBearing = 0;
  int _etaMinutes = 2;
  double _distanceMiles = 0;
  List<LatLng> _routePts = [];
  bool _showDetails = false;
  int _ratingStars = 5;
  double _tipAmount = 0;
  bool _customTip = false;
  bool _saveDriver = false;

  Timer? _simTimer;
  int _simStep = 0;
  int _pickupIdx = 0;

  Timer? _interpTimer;
  LatLng _tgtPos = const LatLng(0, 0);
  double _tgtBrg = 0;
  Timer? _camTimer;
  bool _userMovedMap = false;
  bool _programmaticCam = false;
  bool _followingDriver = false;

  // ── Smooth camera bounds (60fps lerp) ──
  double _camSWLat = 0, _camSWLng = 0, _camNELat = 0, _camNELng = 0;
  double _tgtSWLat = 0, _tgtSWLng = 0, _tgtNELat = 0, _tgtNELng = 0;
  bool _camInitialized = false;

  late AnimationController _etaPulse;

  String get _vehicleAsset {
    final m = widget.vehicleModel.toLowerCase();
    if (m.contains('suburban')) return 'assets/images/suburban.png';
    if (m.contains('fusion')) return 'assets/images/fusion.png';
    return 'assets/images/camry.png';
  }

  @override
  void initState() {
    super.initState();
    _etaPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadCarIcon();
    _loadPinIcon();
    _initRoute();
    _interpTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      _interpolate,
    );
  }

  @override
  void dispose() {
    _simTimer?.cancel();
    _interpTimer?.cancel();
    _camTimer?.cancel();
    _etaPulse.dispose();
    super.dispose();
  }

  Future<void> _loadCarIcon() async {
    final car = await CarIconLoader.loadForRide(widget.rideName);
    final arrow = await _buildNavArrow();
    if (mounted) {
      setState(() {
        _carIconCar = car;
        _navArrowIcon = arrow;
        _carIcon = car;
      });
    }
  }

  /// Blue navigation arrow for GPS follow mode.
  Future<BitmapDescriptor> _buildNavArrow() async {
    const double size = 100;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));
    final cx = size / 2, cy = size / 2;

    // Outer glow
    canvas.drawCircle(Offset(cx, cy), size * 0.42,
      Paint()..color = const Color(0x304A9EFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    // Blue circle background
    canvas.drawCircle(Offset(cx, cy), size * 0.32,
      Paint()..color = const Color(0xFF4A9EFF));
    // Highlight
    canvas.drawCircle(Offset(cx - size * 0.06, cy - size * 0.06), size * 0.18,
      Paint()..color = Colors.white.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    // White arrow pointing up
    final arrow = Path()
      ..moveTo(cx, cy - size * 0.18)
      ..lineTo(cx + size * 0.12, cy + size * 0.12)
      ..lineTo(cx, cy + size * 0.05)
      ..lineTo(cx - size * 0.12, cy + size * 0.12)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white..isAntiAlias = true);

    final pic = recorder.endRecording();
    final img = await pic.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return BitmapDescriptor.defaultMarker;
    // ignore: deprecated_member_use
    return BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
  }

  static const _gold = Color(0xFFE8C547);

  Future<void> _loadPinIcon() async {
    _goldPinIcon = await _buildPin(isPickup: true);
    _pickupPersonPin = await _buildPin(icon: 'person', isPickup: true);
    // Detect dropoff type from address — square shape
    _dropoffHousePin = await _buildPin(icon: _detectDropoffIcon(widget.dropoffLabel), isPickup: false);
    if (mounted) setState(() {});
  }

  /// Detect what icon to show on the dropoff pin based on address text.
  static String _detectDropoffIcon(String address) {
    final lower = address.toLowerCase();
    if (lower.contains('airport') ||
        lower.contains('aeropuerto') ||
        lower.contains('intl') ||
        lower.contains('terminal') ||
        lower.contains('aviation') ||
        RegExp(r'\b(mia|jfk|lax|ord|atl|sfo|dfw)\b').hasMatch(lower)) {
      return 'airplane';
    }
    if (lower.contains('mall') ||
        lower.contains('plaza') ||
        lower.contains('store') ||
        lower.contains('shop') ||
        lower.contains('market') ||
        lower.contains('restaurant') ||
        lower.contains('hotel') ||
        lower.contains('hospital') ||
        lower.contains('clinic') ||
        lower.contains('center') ||
        lower.contains('centre') ||
        lower.contains('office') ||
        lower.contains('building') ||
        lower.contains('tower') ||
        lower.contains('suite') ||
        lower.contains('walmart') ||
        lower.contains('target') ||
        lower.contains('costco') ||
        lower.contains('starbucks') ||
        lower.contains('gym') ||
        lower.contains('fitness') ||
        lower.contains('church') ||
        lower.contains('school') ||
        lower.contains('university') ||
        lower.contains('college') ||
        lower.contains('stadium') ||
        lower.contains('arena') ||
        lower.contains('museum') ||
        lower.contains('cinema') ||
        lower.contains('theater') ||
        lower.contains('theatre') ||
        lower.contains('bank') ||
        lower.contains('station')) {
      return 'store';
    }
    return 'house';
  }

  /// Pickup = gold circle with icon; Dropoff = gold rounded square with icon.
  Future<BitmapDescriptor> _buildPin({String icon = '', bool isPickup = false}) async {
    const double size = 90;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    const cx = size / 2;
    const cy = size / 2;
    const r = size * 0.38; // radius / half-side

    // Shadow
    canvas.drawCircle(
      const Offset(cx, cy + 2), r + 2,
      Paint()..color = Colors.black.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));

    if (isPickup) {
      // ── Circle shape for pickup ──
      canvas.drawCircle(const Offset(cx, cy), r, Paint()..color = _gold);
      // Inner highlight
      canvas.drawCircle(
        Offset(cx - r * 0.2, cy - r * 0.2), r * 0.5,
        Paint()..color = Colors.white.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      // Border
      canvas.drawCircle(const Offset(cx, cy), r,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.25));
    } else {
      // ── Rounded square shape for dropoff ──
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: const Offset(cx, cy), width: r * 2, height: r * 2),
        Radius.circular(r * 0.28),
      );
      canvas.drawRRect(rect, Paint()..color = _gold);
      // Inner highlight
      canvas.drawCircle(
        Offset(cx - r * 0.2, cy - r * 0.2), r * 0.5,
        Paint()..color = Colors.white.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      // Border
      canvas.drawRRect(rect,
        Paint()..style = PaintingStyle.stroke..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.25));
    }

    // Draw icon — modern filled style
    const iconColor = Colors.white;
    final iconPaint = Paint()..color = iconColor..isAntiAlias = true;

    if (icon == 'person') {
      final s = size * 0.12;
      canvas.drawCircle(Offset(cx, cy - s * 0.65), s * 0.55, iconPaint);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - s * 0.9, cy + s * 0.1, cx + s * 0.9, cy + s * 1.0),
          topLeft: Radius.circular(s * 0.9),
          topRight: Radius.circular(s * 0.9),
          bottomLeft: Radius.circular(s * 0.2),
          bottomRight: Radius.circular(s * 0.2),
        ),
        iconPaint,
      );
    } else if (icon == 'house') {
      final s = size * 0.12;
      final roof = Path()
        ..moveTo(cx, cy - s * 1.25)
        ..lineTo(cx - s * 1.15, cy - s * 0.1)
        ..lineTo(cx + s * 1.15, cy - s * 0.1)
        ..close();
      canvas.drawPath(roof, iconPaint);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - s * 0.8, cy - s * 0.1, cx + s * 0.8, cy + s * 0.9),
          Radius.circular(s * 0.08),
        ),
        iconPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - s * 0.22, cy + s * 0.3, cx + s * 0.22, cy + s * 0.9),
          Radius.circular(s * 0.15),
        ),
        Paint()..color = _gold,
      );
    } else if (icon == 'store') {
      final s = size * 0.12;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - s * 1.0, cy - s * 0.3, cx + s * 1.0, cy + s * 1.0),
          Radius.circular(s * 0.1),
        ),
        iconPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - s * 1.1, cy - s * 1.0, cx + s * 1.1, cy - s * 0.3),
          topLeft: Radius.circular(s * 0.2),
          topRight: Radius.circular(s * 0.2),
        ),
        iconPaint,
      );
      for (double dx = -0.7; dx <= 0.71; dx += 0.7) {
        canvas.drawCircle(Offset(cx + s * dx, cy - s * 0.3), s * 0.24, Paint()..color = _gold);
      }
    } else if (icon == 'airplane') {
      final s = size * 0.12;
      canvas.drawOval(Rect.fromCenter(center: const Offset(cx, cy), width: s * 0.55, height: s * 2.0), iconPaint);
      final wings = Path()
        ..moveTo(cx, cy - s * 0.05)..lineTo(cx - s * 1.2, cy + s * 0.35)..lineTo(cx - s * 1.2, cy + s * 0.5)
        ..lineTo(cx, cy + s * 0.18)..lineTo(cx + s * 1.2, cy + s * 0.5)..lineTo(cx + s * 1.2, cy + s * 0.35)..close();
      canvas.drawPath(wings, iconPaint);
      final tail = Path()
        ..moveTo(cx, cy + s * 0.65)..lineTo(cx - s * 0.5, cy + s * 1.0)..lineTo(cx - s * 0.5, cy + s * 1.1)
        ..lineTo(cx, cy + s * 0.85)..lineTo(cx + s * 0.5, cy + s * 1.1)..lineTo(cx + s * 0.5, cy + s * 1.0)..close();
      canvas.drawPath(tail, iconPaint);
    } else {
      // Default: small dot
      canvas.drawCircle(const Offset(cx, cy), size * 0.08, iconPaint);
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    // ignore: deprecated_member_use
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _initRoute() async {
    // 1) Get the trip route (pickup → dropoff)
    List<LatLng> tripRoute = [];
    if (widget.routePoints != null && widget.routePoints!.isNotEmpty) {
      tripRoute = List.from(widget.routePoints!);
    } else {
      final ds = DirectionsService(ApiKeys.webServices);
      final r = await ds.getRoute(
        origin: widget.pickupLatLng,
        destination: widget.dropoffLatLng,
      );
      if (r != null && mounted) tripRoute = r.points;
    }
    if (tripRoute.isEmpty) {
      tripRoute = [widget.pickupLatLng, widget.dropoffLatLng];
    }

    // 2) Create a simulated driver start ~1.6 km away from pickup
    //    Pick a random bearing and offset the position
    final rng = math.Random();
    final bearing = rng.nextDouble() * 360;
    const distKm = 1.6;
    final lat0 = widget.pickupLatLng.latitude;
    final lng0 = widget.pickupLatLng.longitude;
    final dLat = (distKm / 111.32) * math.cos(bearing * math.pi / 180);
    final dLng =
        (distKm / (111.32 * math.cos(lat0 * math.pi / 180))) *
        math.sin(bearing * math.pi / 180);
    final driverStart = LatLng(lat0 + dLat, lng0 + dLng);

    // 3) Fetch approach route (driverStart → pickup) via Directions API
    List<LatLng> approachRoute = [];
    try {
      final ds = DirectionsService(ApiKeys.webServices);
      final ar = await ds.getRoute(
        origin: driverStart,
        destination: widget.pickupLatLng,
      );
      if (ar != null) approachRoute = ar.points;
    } catch (_) {}
    if (approachRoute.isEmpty) {
      // Fallback: straight-line interpolation
      approachRoute = List.generate(30, (i) {
        final t = i / 29;
        return LatLng(
          driverStart.latitude +
              (widget.pickupLatLng.latitude - driverStart.latitude) * t,
          driverStart.longitude +
              (widget.pickupLatLng.longitude - driverStart.longitude) * t,
        );
      });
    }

    // 4) Combine: approach route + trip route
    //    The pickupIdx is where approach ends and trip starts
    _pickupIdx = approachRoute.length - 1;
    _routePts = [...approachRoute, ...tripRoute.skip(1)];

    // 5) Driver starts at position 0 of the combined route
    _driverPos = _routePts[0];
    _animPos = _driverPos;
    _tgtPos = _driverPos;
    _simStep = 0;

    // 6) Calculate initial distance from driver to pickup (miles)
    double acc = 0;
    for (int i = 0; i < _pickupIdx && i + 1 < _routePts.length; i++) {
      acc += _hav(_routePts[i], _routePts[i + 1]);
    }
    _distanceMiles = acc;
    _etaMinutes = (acc / 0.5).ceil().clamp(1, 99);

    _startSim();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 600), _fitAllPoints);
  }

  void _startSim() {
    _simTimer?.cancel();
    const tickMs = 150;          // optimized for low-end devices
    const mPerTick = 0.87;       // adjusted for new tick rate

    _simTimer = Timer.periodic(const Duration(milliseconds: tickMs), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_phase == _TrackPhase.completed) {
        t.cancel();
        return;
      }

      double moved = 0;
      while (moved < mPerTick && _simStep + 1 < _routePts.length) {
        final seg =
            _hav(_routePts[_simStep], _routePts[_simStep + 1]) * 1609.34;
        if (seg < 0.01) {
          _simStep++;
          continue;
        }
        moved += seg;
        _simStep++;
      }

      if (_phase == _TrackPhase.arriving && _simStep >= _pickupIdx) {
        setState(() => _phase = _TrackPhase.arrived);
        Timer(const Duration(seconds: 3), () {
          if (mounted) setState(() => _phase = _TrackPhase.onTrip);
        });
      }

      if (_simStep >= _routePts.length - 1) {
        t.cancel();
        setState(() => _phase = _TrackPhase.completed);
        // Show rating overlay — user dismisses it
        return;
      }

      final idx = _simStep.clamp(0, _routePts.length - 1);
      final pos = _routePts[idx];
      double brg = _driverBearing;
      if (idx + 4 < _routePts.length) {
        brg = _bearing(pos, _routePts[idx + 4]);
      } else if (idx + 1 < _routePts.length) {
        brg = _bearing(pos, _routePts[idx + 1]);
      }

      double rd = 0;
      final ti = _phase == _TrackPhase.arriving
          ? _pickupIdx
          : _routePts.length - 1;
      for (int i = idx; i < ti && i + 1 < _routePts.length; i++) {
        rd += _hav(_routePts[i], _routePts[i + 1]);
      }
      final eta = (rd / 0.5).ceil().clamp(1, 99);

      _tgtPos = pos;
      _tgtBrg = brg;

      // Update state without full rebuild — interpolation timer handles visuals
      _driverPos = pos;
      _driverBearing = brg;
      _etaMinutes = eta;
      _distanceMiles = rd;
      _throttleCam();
    });
  }

  int _interpFrameCount = 0;

  void _interpolate(Timer t) {
    if (!mounted) return;

    // ── Constant-speed smooth interpolation ──
    const posLerp = 0.18;
    const brgLerp = 0.16;

    final lat =
        _animPos.latitude + (_tgtPos.latitude - _animPos.latitude) * posLerp;
    final lng =
        _animPos.longitude + (_tgtPos.longitude - _animPos.longitude) * posLerp;

    // Smooth shortest-path bearing interpolation
    double db = _tgtBrg - _animBearing;
    if (db > 180) db -= 360;
    if (db < -180) db += 360;
    final nb = (_animBearing + db * brgLerp) % 360;

    _animPos = LatLng(lat, lng);
    _animBearing = nb;

    // Rebuild marker data (lightweight — just creates Marker objects)
    _rebuildCarMarker();

    // Only trigger widget rebuild every 2nd frame (~15fps) for smoother visuals
    _interpFrameCount++;
    if (_interpFrameCount % 2 == 0) {
      setState(() {});
    }

    // ── Camera control ──
    if (_map != null && !_userMovedMap && _camInitialized) {
      if (_followingDriver && _interpFrameCount % 5 == 0) {
        // GPS navigation mode: follow driver with 3D tilt + bearing — throttled for performance
        _programmaticCam = true;
        _map!.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _animPos,
              zoom: 18.0, // Closer zoom for GPS navigation view
              bearing: _animBearing, // Follow driver's direction
              tilt: 60, // Enhanced 3D tilt for GPS-style navigation
            ),
          ),
        );
      } else {
        // Default: smooth bounds interpolation
        const lerpSpeed = 0.06;
        _camSWLat += (_tgtSWLat - _camSWLat) * lerpSpeed;
        _camSWLng += (_tgtSWLng - _camSWLng) * lerpSpeed;
        _camNELat += (_tgtNELat - _camNELat) * lerpSpeed;
        _camNELng += (_tgtNELng - _camNELng) * lerpSpeed;
        _programmaticCam = true;
        _map!.moveCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(_camSWLat, _camSWLng),
              northeast: LatLng(_camNELat, _camNELng),
            ),
            50,
          ),
        );
      }
    }
  }

  // ── Update camera target bounds (called from sim tick) ──
  void _throttleCam() {
    _updateCamTarget();
  }

  // ── Compute ideal bounds and set as smooth target ──
  void _updateCamTarget() {
    if (_map == null || _userMovedMap) return;
    final pts = <LatLng>[_animPos];
    if (_phase == _TrackPhase.arriving || _phase == _TrackPhase.arrived) {
      pts.add(widget.pickupLatLng);
    }
    if (_phase == _TrackPhase.onTrip) {
      pts.add(widget.dropoffLatLng);
    }
    if (pts.length < 2) {
      pts.add(widget.pickupLatLng);
    }
    double mnLat = pts[0].latitude, mxLat = pts[0].latitude;
    double mnLng = pts[0].longitude, mxLng = pts[0].longitude;
    for (final p in pts) {
      mnLat = math.min(mnLat, p.latitude);
      mxLat = math.max(mxLat, p.latitude);
      mnLng = math.min(mnLng, p.longitude);
      mxLng = math.max(mxLng, p.longitude);
    }
    // Smooth padding proportional to span
    final latSpan = mxLat - mnLat;
    final lngSpan = mxLng - mnLng;
    final span = math.max(latSpan, lngSpan);
    final padFrac = span > 0.01 ? 0.10 : 0.18;
    final pad = span * padFrac;
    const minPad = 0.0003;
    final lp = math.max(pad, minPad);

    _tgtSWLat = mnLat - lp;
    _tgtSWLng = mnLng - lp;
    _tgtNELat = mxLat + lp;
    _tgtNELng = mxLng + lp;

    // First call → snap immediately (no lerp delay)
    if (!_camInitialized) {
      _camSWLat = _tgtSWLat;
      _camSWLng = _tgtSWLng;
      _camNELat = _tgtNELat;
      _camNELng = _tgtNELng;
      _camInitialized = true;
      _programmaticCam = true;
      _map!.moveCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(_camSWLat, _camSWLng),
            northeast: LatLng(_camNELat, _camNELng),
          ),
          50,
        ),
      );
    }
  }

  void _fitAllPoints() {
    _updateCamTarget();
  }

  void _recenter() {
    setState(() {
      _userMovedMap = false;
    });
    _programmaticCam = true;
    if (_followingDriver) {
      _followDriverCamera();
    } else {
      _fitAllPoints();
    }
  }

  void _toggleFollowDriver() {
    final follow = !_followingDriver;
    setState(() {
      _followingDriver = follow;
      _userMovedMap = false;
      // Switch to 3D icon in GPS follow mode, normal otherwise
      _carIcon = follow
          ? (_navArrowIcon ?? _carIcon)
          : (_carIconCar ?? _carIcon);
    });
    _rebuildCarMarker();
    if (follow) {
      _followDriverCamera();
    } else {
      _fitAllPoints();
    }
  }

  void _followDriverCamera() {
    if (!_followingDriver || _map == null) return;
    _programmaticCam = true;
    // GPS navigation view: higher zoom, 3D tilt, following bearing
    _map!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _animPos,
          zoom: 18.0, // Closer zoom for better navigation view
          bearing: _animBearing, // Follow driver's direction
          tilt: 60, // More tilt for 3D GPS-style view
        ),
      ),
    );
  }

  double _hav(LatLng a, LatLng b) {
    const R = 3958.8;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final la = a.latitude * math.pi / 180;
    final lb = b.latitude * math.pi / 180;
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la) * math.cos(lb) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * R * math.asin(math.sqrt(h));
  }

  double _bearing(LatLng f, LatLng t) {
    final dL = (t.longitude - f.longitude) * math.pi / 180;
    final la = f.latitude * math.pi / 180;
    final lb = t.latitude * math.pi / 180;
    final y = math.sin(dL) * math.cos(lb);
    final x =
        math.cos(la) * math.sin(lb) -
        math.sin(la) * math.cos(lb) * math.cos(dL);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final topPad = MediaQuery.of(context).padding.top;
    final botPad = MediaQuery.of(context).viewPadding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: Stack(
          children: [
            RepaintBoundary(
              child: GoogleMap(
                style: MapStyles.dark,
                initialCameraPosition: CameraPosition(
                  target: widget.pickupLatLng,
                  zoom: 14,
                ),
                onMapCreated: (ctrl) {
                  _map = ctrl;
                },
                onCameraMoveStarted: () {
                  if (!_programmaticCam) setState(() => _userMovedMap = true);
                },
                onCameraIdle: () => _programmaticCam = false,
                markers: _markers(),
                polylines: _polylines(),
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                zoomGesturesEnabled: true,
                scrollGesturesEnabled: true,
                rotateGesturesEnabled: true,
                compassEnabled: false,
                mapToolbarEnabled: false,
                tiltGesturesEnabled: true,
                buildingsEnabled: false,
                trafficEnabled: false,
                indoorViewEnabled: false,
                liteModeEnabled: false,
                padding: EdgeInsets.only(
                  bottom: 260 + botPad,
                  top: topPad + 56,
                ),
              ),
            ),
            // ── Back arrow for iOS / all platforms ──
            Positioned(
              top: topPad + 10,
              left: 14,
              child: _phase != _TrackPhase.completed
                  ? GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            // ── Bottom card + control buttons ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _phase == _TrackPhase.completed
                  ? _ratingOverlay(botPad)
                  : _bottomSection(c, botPad),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool highlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: highlight ? _gold : const Color(0xFF2A2A2A),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 20, color: highlight ? Colors.black : Colors.white),
      ),
    );
  }

  Widget _addressBar({
    required String label,
    required bool isPickup,
    int? etaMinutes,
  }) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ETA badge for dropoff
          if (!isPickup && etaMinutes != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$etaMinutes',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                    ),
                  ),
                  const Text(
                    'MIN',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w700,
                      color: Colors.white54,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ] else
            const SizedBox(width: 10),
          // Gold dot
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFFE8C547),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.3),
            size: 16,
          ),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  Widget _tripAddressRow({required Color iconColor, required String label}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  void _rebuildCarMarker() {
    if (_carIcon == null) {
      _cachedCarMarker = null;
      return;
    }
    _cachedCarMarker = Marker(
      markerId: const MarkerId('car'),
      position: _animPos,
      icon: _carIcon!,
      rotation: _animBearing,
      anchor: const Offset(0.5, 0.5),
      flat: true,
      zIndexInt: 10,
    );
    // Miles badge — update bitmap when text changes, always reposition
    if (_phase != _TrackPhase.completed && _distanceMiles > 0.01) {
      final miText = _distanceMiles >= 0.1
          ? '${_distanceMiles.toStringAsFixed(1)} mi'
          : '${(_distanceMiles * 5280).round()} ft';
      if (miText != _lastMilesText) {
        _lastMilesText = miText;
        _buildMilesBadge(miText); // async — sets _milesBadgeIcon when done
      }
      // Always reposition badge at car pos (even if icon not yet ready)
      if (_milesBadgeIcon != null) {
        _cachedMilesBadge = Marker(
          markerId: const MarkerId('miles_badge'),
          position: _animPos,
          icon: _milesBadgeIcon!,
          anchor: const Offset(-0.3, 0.5),
          flat: false,
          zIndexInt: 11,
        );
      }
    } else {
      _cachedMilesBadge = null;
    }
  }

  Future<void> _buildMilesBadge(String text) async {
    const double scale = 4.0;
    final recorder = ui.PictureRecorder();
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 10 * scale,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.2 * scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final padH = 7.0 * scale;
    final padV = 3.5 * scale;
    final w = tp.width + padH * 2;
    final h = tp.height + padV * 2;
    final r = h / 2;
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    // Background
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(r)),
      Paint()..color = const Color(0xDD1E1E1E),
    );
    // Border
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, w, h), Radius.circular(r)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7 * scale
        ..color = Colors.white.withValues(alpha: 0.15),
    );
    tp.paint(canvas, Offset(padH, padV));
    final pic = recorder.endRecording();
    final img = await pic.toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null || !mounted) return;
    // ignore: deprecated_member_use
    _milesBadgeIcon = BitmapDescriptor.fromBytes(bytes.buffer.asUint8List());
    // Immediately build the cached marker now that icon is ready
    if (mounted && _phase != _TrackPhase.completed) {
      _cachedMilesBadge = Marker(
        markerId: const MarkerId('miles_badge'),
        position: _animPos,
        icon: _milesBadgeIcon!,
        anchor: const Offset(-0.3, 0.5),
        flat: false,
        zIndexInt: 11,
      );
      setState(() {});
    }
  }

  Set<Marker> _markers() {
    final m = <Marker>{};
    if (_cachedCarMarker != null) {
      m.add(_cachedCarMarker!);
    }
    if (_cachedMilesBadge != null) {
      m.add(_cachedMilesBadge!);
    }
    // Pickup pin: visible during arriving/arrived, hidden during onTrip/completed
    if (_phase == _TrackPhase.arriving || _phase == _TrackPhase.arrived) {
      m.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: widget.pickupLatLng,
          icon: _pickupPersonPin ?? _goldPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(45.0),
          zIndexInt: 5,
          infoWindow: const InfoWindow(title: 'Pickup spot'),
        ),
      );
    }
    // Always show dropoff marker so rider sees full route
    m.add(
      Marker(
        markerId: const MarkerId('drop'),
        position: widget.dropoffLatLng,
        icon: _dropoffHousePin ?? _goldPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(45.0),
        zIndexInt: 5,
      ),
    );
    return m;
  }

  Set<Polyline> _polylines() {
    if (_routePts.isEmpty) return {};
    final s = <Polyline>{};
    // Full route outline (dim) so rider always sees the complete path
    if (_routePts.length >= 2) {
      s.add(
        Polyline(
          polylineId: const PolylineId('full'),
          points: _routePts,
          color: const Color(0xFF3A3A3A),
          width: 3,
          geodesic: true,
          zIndex: 1,
        ),
      );
    }
    // Remaining route (blue) from driver position
    final idx = _simStep.clamp(0, _routePts.length - 1);
    final remaining = _routePts.sublist(idx);
    if (remaining.length >= 2) {
      s.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: remaining,
          color: const Color(0xFF4285F4),
          width: 3,
          geodesic: true,
          zIndex: 2,
        ),
      );
    }
    return s;
  }

  Widget _bottomSection(AppColors c, double botPad) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Buttons row flush at top of card — right-aligned
        Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _circleBtn(
                _followingDriver
                    ? Icons.gps_fixed_rounded
                    : Icons.gps_not_fixed_rounded,
                _toggleFollowDriver,
                highlight: _followingDriver,
              ),
              if (_userMovedMap) ...[
                const SizedBox(width: 10),
                _circleBtn(Icons.fullscreen_rounded, _recenter),
              ],
            ],
          ),
        ),
        _bottomCard(c, botPad),
      ],
    );
  }

  Widget _bottomCard(AppColors c, double botPad) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _banner(c),
              if (_phase == _TrackPhase.arriving ||
                  _phase == _TrackPhase.arrived) ...[
                if (_showDetails) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Driver will arrive on the same side of the street as your pickup spot',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── Trip address info ──
                  _tripAddressRow(
                    iconColor: const Color(0xFFE8C547),
                    label: widget.pickupLabel.isNotEmpty
                        ? widget.pickupLabel
                        : 'Pickup location',
                  ),
                  const SizedBox(height: 6),
                  _tripAddressRow(
                    iconColor: const Color(0xFFE8C547),
                    label: widget.dropoffLabel.isNotEmpty
                        ? widget.dropoffLabel
                        : 'Destination',
                  ),
                ],
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _showDetails = !_showDetails),
                  child: Row(
                    children: [
                      Text(
                        _showDetails ? 'Show less' : 'Show more',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _showDetails
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 14),
              _driverRow(c),
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          recipientName: widget.driverName,
                          recipientPhone: '555-0100',
                          avatarInitial: widget.driverName.isNotEmpty
                              ? widget.driverName[0].toUpperCase()
                              : 'D',
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.message_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Message ${widget.driverName.split(' ').first}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 10),
              // Contact Support
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ChatScreen(
                        recipientName: 'Cruise Support',
                        isSupport: true,
                      ),
                    ),
                  );
                },
                child: const Text(
                  'Contact Support',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE53935),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(AppColors c) {
    switch (_phase) {
      case _TrackPhase.arriving:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                  ),
                  text: 'Meet driver at pickup spot on',
                ),
              ),
            ),
            const SizedBox(width: 14),
            AnimatedBuilder(
              animation: _etaPulse,
              builder: (_, _) {
                return Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$_etaMinutes',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'min',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      case _TrackPhase.arrived:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3A1B),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.place_rounded, color: Colors.green.shade400, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your driver has arrived!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade300,
                  ),
                ),
              ),
            ],
          ),
        );
      case _TrackPhase.onTrip:
        return Row(
          children: [
            const Expanded(
              child: Text(
                'On trip to destination',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_etaMinutes min',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      case _TrackPhase.completed:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1B3A1B),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade400,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You have arrived!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade300,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  // ── Rating / Tip / Save overlay (shown when trip completes) ──
  Widget _ratingOverlay(double botPad) {
    final first = widget.driverName.split(' ').first;
    const gold = Color(0xFFE8C547);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title + avatar row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.driverName.isNotEmpty
                            ? widget.driverName[0].toUpperCase()
                            : 'D',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'How was your trip?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rate your ride with $first',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Stars
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setState(() => _ratingStars = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < _ratingStars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 36,
                        color: i < _ratingStars
                            ? gold
                            : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),
              // Tip section
              Text(
                'Add a tip for $first',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...[1.0, 2.0, 5.0, 10.0].map((amt) {
                    final sel = _tipAmount == amt && !_customTip;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _customTip = false;
                        _tipAmount = sel ? 0 : amt;
                      }),
                      child: Container(
                        width: 56,
                        height: 38,
                        decoration: BoxDecoration(
                          color: sel
                              ? gold
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel
                                ? gold
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '\$${amt.toInt()}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: sel
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () => setState(() {
                      _customTip = !_customTip;
                      if (!_customTip) _tipAmount = 0;
                    }),
                    child: Container(
                      width: 72,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _customTip
                            ? gold
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _customTip
                              ? gold
                              : Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Custom',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _customTip
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_customTip) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 140,
                  height: 48,
                  child: TextField(
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      prefixStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.08),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: gold),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: gold),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: gold, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) {
                      final parsed = double.tryParse(v);
                      setState(() => _tipAmount = parsed ?? 0);
                    },
                  ),
                ),
              ],
              const SizedBox(height: 14),
              // Save driver
              GestureDetector(
                onTap: () => setState(() => _saveDriver = !_saveDriver),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _saveDriver
                          ? gold
                          : Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _saveDriver
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 22,
                        color: _saveDriver
                            ? gold
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Save $first as favorite driver',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      if (_saveDriver)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 22,
                          color: gold,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    widget.onTripComplete?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _tipAmount > 0
                        ? 'Submit with \$${_tipAmount.toInt()} tip'
                        : 'Submit',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _driverRow(AppColors c) {
    final first = widget.driverName.split(' ').first;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar with rating badge
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  widget.driverName.isNotEmpty
                      ? widget.driverName[0].toUpperCase()
                      : 'D',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            // Rating badge
            Positioned(
              bottom: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, size: 10, color: Color(0xFFE8C547)),
                      const SizedBox(width: 2),
                      Text(
                        widget.driverRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 10),
        // Car image
        SizedBox(
          width: 72,
          height: 44,
          child: Image.asset(
            _vehicleAsset,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            isAntiAlias: true,
            cacheWidth: 320,
            errorBuilder: (_, _, _) => Icon(
              Icons.directions_car_rounded,
              size: 32,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Vehicle + driver info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.vehicleColor} ${widget.vehicleMake} ${widget.vehicleModel}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 14, color: Color(0xFF4CAF50)),
                  const SizedBox(width: 4),
                  Text(
                    first,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '  ·  ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  const Flexible(
                    child: Text(
                      'Top-rated driver',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
